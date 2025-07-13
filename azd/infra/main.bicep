@description('리소스 이름 패턴에 들어갈 식별자')
param vmName string
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string
@secure()
param bastionPassword string
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
      vmSize: 'Standard_B1s'
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
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: bastionVmName
      adminUsername: adminUsername
      adminPassword: empty(sshPublicKey) ? bastionPassword : null
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

// 사용자 정의 스크립트 확장으로 SSH 설정과 alias 구성
resource bastionVmExtension 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: bastionVm
  name: 'CustomScriptForLinux'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      script: base64('''#!/bin/bash
# SSH config 설정
mkdir -p /home/azureuser/.ssh
chown azureuser:azureuser /home/azureuser/.ssh
chmod 700 /home/azureuser/.ssh

# SSH aliases 설정
cat > /home/azureuser/.ssh/config << 'EOF'
Host vm1
    HostName 10.0.0.4
    User azureuser
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host vm2
    HostName 10.0.0.5
    User azureuser
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host vm3
    HostName 10.0.0.6
    User azureuser
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host vm4
    HostName 10.0.0.7
    User azureuser
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host vm5
    HostName 10.0.0.8
    User azureuser
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host vm6
    HostName 10.0.0.9
    User azureuser
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
''')
    }
  }
}

// 출력값들
output bastionPublicIp string = bastionPublicIP.properties.ipAddress
output bastionFqdn string = bastionPublicIP.properties.dnsSettings.fqdn
output vmNames array = vmNames
output bastionVmName string = bastionVmName
