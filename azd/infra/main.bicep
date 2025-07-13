@description('리소스 이름 패턴에 들어갈 식별자')
param vmName string
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string
param vmCount int = 6

// SSH 키 쌍 생성을 위한 파라미터
param sshPublicKey string
@secure()
param sshPrivateKey string

// var resourceGroupName = 'rg-${name}-krc-01' // Not used, for reference only
var vnetName = empty(vmName) ? 'vnet-krc-01' : 'vnet-${vmName}-krc-01'

var subnetName = 'default'
var nsgName = empty(vmName) ? 'nsg-krc-01' : 'nsg-${vmName}-krc-01'
var vmNames = [for i in range(0, vmCount): '${vmName}${i+1}']
var bastionVmName = empty(vmName) ? 'bastion-vm' : '${vmName}-bastion'

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      // 인바운드 SSH(22)만 허용
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
    ]
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
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
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

// 베스천 VM용 공용 IP
resource bastionPublicIP 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: '${bastionVmName}-pip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// 베스천 VM용 네트워크 인터페이스
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
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: bastionPublicIP.id
          }
        }
      }
    ]
  }
}

// 베스천 VM
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
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
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

// 베스천 VM에 SSH 키 설정을 위한 Custom Script Extension
resource bastionScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: bastionVm
  name: 'setupSSHKeys'
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'mkdir -p /home/${adminUsername}/.ssh && echo "${base64(sshPrivateKey)}" | base64 -d > /home/${adminUsername}/.ssh/id_rsa && chmod 600 /home/${adminUsername}/.ssh/id_rsa && chown ${adminUsername}:${adminUsername} /home/${adminUsername}/.ssh/id_rsa && echo "${sshPublicKey}" > /home/${adminUsername}/.ssh/id_rsa.pub && chmod 644 /home/${adminUsername}/.ssh/id_rsa.pub && chown ${adminUsername}:${adminUsername} /home/${adminUsername}/.ssh/id_rsa.pub'
    }
  }
}

// SSH 구성 파일 생성을 위한 추가 스크립트
resource bastionSSHConfigExtension 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: bastionVm
  name: 'createSSHConfig'
  dependsOn: [bastionScriptExtension]
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'echo "Host *" > /home/${adminUsername}/.ssh/config && echo "  StrictHostKeyChecking no" >> /home/${adminUsername}/.ssh/config && echo "  UserKnownHostsFile /dev/null" >> /home/${adminUsername}/.ssh/config && chown ${adminUsername}:${adminUsername} /home/${adminUsername}/.ssh/config && chmod 600 /home/${adminUsername}/.ssh/config'
    }
  }
}

// 출력 - 베스천 VM의 공용 IP 주소
output bastionPublicIP string = bastionPublicIP.properties.ipAddress

// 출력 - 각 VM의 이름과 사설 IP 주소
output vmInfo array = [for (name, i) in vmNames: {
  name: name
  privateIP: nics[i].properties.ipConfigurations[0].properties.privateIPAddress
}]

// 출력 - SSH 접속 가이드
output sshConnectionGuide string = 'SSH to bastion: ssh ${adminUsername}@${bastionPublicIP.properties.ipAddress} | SSH from bastion to VMs: ssh ${adminUsername}@<vm_private_ip>'
