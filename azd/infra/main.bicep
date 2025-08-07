@description('리소스 이름 패턴에 들어갈 식별자')
param vmName string
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string
@secure()
@description('Bastion VM admin password - if empty and no SSH key provided, will prompt during deployment')
param bastionPassword string = ''
param vmCount int = 6
@description('SSH public key for VM authentication')
param sshPublicKey string = ''

// var resourceGroupName = 'rg-${name}-krc-01' // Not used, for reference only
var vnetName = empty(vmName) ? 'vnet-krc-01' : 'vnet-${vmName}-krc-01'

var subnetName = 'default'
var nsgName = empty(vmName) ? 'nsg-krc-01' : 'nsg-${vmName}-krc-01'
var bastionNsgName = empty(vmName) ? 'nsg-bastion-krc-01' : 'nsg-bastion-${vmName}-krc-01'
var vmNames = [for i in range(0, vmCount): '${vmName}${i+1}']
var bastionVmName = '${vmName}-bastion'

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      // 인바운드 SSH(22)만 VNet 내부에서만 허용
      {
        name: 'Allow-SSH-Internal'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '10.0.0.0/16'
          destinationAddressPrefix: '*'
        }
      }
      // 모든 아웃바운드 허용
      {
        name: 'Allow-All-Outbound'
        properties: {
          priority: 1000
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: bastionNsgName
  location: location
  properties: {
    securityRules: [
      // 인바운드 SSH(22) 외부에서 허용 (bastion용)
      {
        name: 'Allow-SSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      // 모든 아웃바운드 허용
      {
        name: 'Allow-All-Outbound'
        properties: {
          priority: 1000
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.0.0.0/16' ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'bastion-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: bastionNsg.id
          }
        }
      }
    ]
  }
}
resource bastionPublicIP 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: '${bastionVmName}-pip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${bastionVmName}-${uniqueString(resourceGroup().id)}'
    }
  }
  sku: {
    name: 'Standard'
  }
}

resource nics 'Microsoft.Network/networkInterfaces@2022-07-01' = [for (name, i) in vmNames: {
  name: '${name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}]

resource bastionNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${bastionVmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[1].id
          }
          publicIPAddress: {
            id: bastionPublicIP.id
          }
        }
      }
    ]
  }
}

resource vms 'Microsoft.Compute/virtualMachines@2022-08-01' = [for (name, i) in vmNames: {
  name: name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: name
      adminUsername: adminUsername
      adminPassword: empty(sshPublicKey) ? adminPassword : null
      linuxConfiguration: !empty(sshPublicKey) ? {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      } : null
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
        }
      ]
    }
  }
}]

resource bastionVm 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: bastionVmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: bastionVmName
      adminUsername: adminUsername
      adminPassword: empty(sshPublicKey) ? (empty(bastionPassword) ? adminPassword : bastionPassword) : null
      linuxConfiguration: !empty(sshPublicKey) ? {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      } : null
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: bastionNic.id
        }
      ]
    }
  }
}

// Role assignment for bastion VM to run commands on worker VMs
resource bastionVmContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, bastionVm.id, 'Virtual Machine Contributor', vmName, bastionVmName)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9980e02c-c2be-4d73-94e8-173b1dc7cf3c') // Virtual Machine Contributor
    principalId: bastionVm.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// 사용자 정의 스크립트 확장으로 SSH 설정과 alias 구성
resource bastionVmExtension 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: bastionVm
  name: 'CustomScriptForLinux'
  location: location
  dependsOn: [
    bastionVmContributorRole
    vms // Ensure worker VMs are created first
  ]
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      script: base64('''#!/bin/bash
set -e

# SSH config 설정
mkdir -p /home/azureuser/.ssh
chown azureuser:azureuser /home/azureuser/.ssh
chmod 700 /home/azureuser/.ssh

# Generate SSH key pair for bastion-to-worker communication
echo "Generating SSH key pair for bastion-to-worker communication..."
sudo -u azureuser ssh-keygen -t rsa -b 4096 -f /home/azureuser/.ssh/bastion_key -N "" -C "bastion-to-worker"

# Set proper permissions
chown azureuser:azureuser /home/azureuser/.ssh/bastion_key*
chmod 600 /home/azureuser/.ssh/bastion_key
chmod 644 /home/azureuser/.ssh/bastion_key.pub

# SSH aliases 설정
cat > /home/azureuser/.ssh/config << 'EOF'
Host vm1
    HostName 10.0.0.4
    User azureuser
    IdentityFile ~/.ssh/bastion_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host vm2
    HostName 10.0.0.5
    User azureuser
    IdentityFile ~/.ssh/bastion_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host vm3
    HostName 10.0.0.6
    User azureuser
    IdentityFile ~/.ssh/bastion_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host vm4
    HostName 10.0.0.7
    User azureuser
    IdentityFile ~/.ssh/bastion_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host vm5
    HostName 10.0.0.8
    User azureuser
    IdentityFile ~/.ssh/bastion_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host vm6
    HostName 10.0.0.9
    User azureuser
    IdentityFile ~/.ssh/bastion_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

chown azureuser:azureuser /home/azureuser/.ssh/config
chmod 600 /home/azureuser/.ssh/config

# Bash aliases 추가
cat >> /home/azureuser/.bashrc << 'EOF'

# VM SSH aliases
alias vm1='ssh vm1'
alias vm2='ssh vm2'
alias vm3='ssh vm3'
alias vm4='ssh vm4'
alias vm5='ssh vm5'
alias vm6='ssh vm6'
EOF

# Copy public key to worker VMs via Azure CLI
echo "Copying public key to worker VMs..."
PUBLIC_KEY=$(cat /home/azureuser/.ssh/bastion_key.pub)

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Wait a bit for role assignment to propagate
sleep 30

# Authenticate using managed identity (VM should have system-assigned identity)
az login --identity

# Get resource group name from metadata
RESOURCE_GROUP=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=2021-01-01&format=text")

# Get VM name prefix from metadata
VM_NAME_PREFIX=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance/compute/name?api-version=2021-01-01&format=text" | sed 's/-bastion$//')

# Copy public key to all worker VMs using run command
for i in {1..6}; do
    VM_NAME="${VM_NAME_PREFIX}${i}"
    echo "Adding public key to $VM_NAME..."
    az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --command-id RunShellScript \
        --scripts "echo '$PUBLIC_KEY' >> /home/azureuser/.ssh/authorized_keys && chmod 600 /home/azureuser/.ssh/authorized_keys && chown azureuser:azureuser /home/azureuser/.ssh/authorized_keys" \
        --no-wait || echo "Failed to add key to $VM_NAME, continuing..."
done

echo "SSH key setup completed"
''')
    }
  }
}

// 출력값들
output bastionPublicIp string = bastionPublicIP.properties.ipAddress
output bastionFqdn string = bastionPublicIP.properties.dnsSettings.fqdn
output vmNames array = vmNames
output bastionVmName string = bastionVmName
