// demo deploy of snipe-it with bicep in LinuxAcademy Azure playground

param vmSku string = 'Standard_D2_v3' // from 'az vm list-skus -l centralus --output table'
param osDiskSize int = 10 // 10 gb
param osDiskType string = 'StandardSDD_LRS' // no need for premium
param appName string = 'demosnipeit'

var vmNameStr = '${appName}-vm'
var vmPortAllow = 'Allow'
var vmPortDeny = 'Deny'
var vNetNameVM = '${appName}-vnet'
var vNetAddressPrefixes = '10.1.0.0/16'
var subnetNameVM = '${appName}-subnet'
var subnetAddressPrefixes = '10.1.0.0/24'
var publicIpAddressNameVM = '${appName}-ip'
var nicNameVM = '${appName}-nic'
var nsgNameVM = '${appName}-nsg'
var subnetReferenceId = resourceId(resourceGroup().name, 'Microsoft.Network/virtualNetworks/subnets', vNetNameVM, subnetNameVM)

@secure()
param adminUser string
@secure()
param adminPassword string

resource publicIpAddressName 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: publicIpAddressNameVM
  location: resourceGroup().location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
  sku: {
    name: 'Basic'
  }
}

resource vNetName 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vNetNameVM
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressPrefixes
      ]
    }
    dhcpOptions: {
      dnsServers: []
    }
    subnets: [
      {
        name: subnetNameVM
        properties: {
          addressPrefix: subnetAddressPrefixes 
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }      
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource nsgName 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: nsgNameVM
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'HTTPS'
        properties: {
          priority: 320
          access: vmPortAllow
          direction: 'Inbound'
          destinationPortRange: '443'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DockerExposedPort'
        properties: {
          priority: 340
          access: vmPortAllow
          direction: 'Inbound'
          destinationPortRange: '8080'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'SSH'
        properties: {
          priority: 360
          access: vmPortAllow
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nicName 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: nicNameVM
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddressName.id
          }
          subnet: {
            id: subnetReferenceId
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgName.id
    }
  }
  dependsOn: [
    vNetName
  ]
}

resource vmName 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmNameStr
  location: resourceGroup().location
  properties: {
    hardwareProfile: {
      vmSize: vmSku
    }
    osProfile: {
      computerName: vmNameStr
      adminUsername: adminUser
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false    
      }
      secrets: []      
    }
    storageProfile: {
      imageReference: {
        offer: 'CentOS'
        sku: '7.5'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSize
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }      
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicName.id
        }
      ]
    }
  }
}
