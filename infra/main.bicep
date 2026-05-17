// ============================================================================
// main.bicep
// DMCShop demo'su için tek-VM Azure ortamı.
//
// Kaynaklar (tek RG altında):
//   - Virtual Network + Subnet
//   - Network Security Group (22, 80, 443 yalnızca SSH whitelist + HTTP/S)
//   - Public IP (Static, Basic SKU)
//   - Network Interface
//   - Virtual Machine (Ubuntu 24.04 LTS, varsayılan B2ms — 8 GB RAM)
//
// cloud-init script'i resource olarak değil deploy.sh tarafından parametre
// olarak verilir; böylece script repo'da version'lanır, Bicep'te string yok.
//
// Çalıştırma: ../infra/deploy.sh
// ============================================================================

@description('Kaynaklar için kısa prefix; isim çakışmasını azaltır.')
param namePrefix string = 'dmcshop'

@description('Azure region; default: Germany West Central (Türkiye yakın).')
param location string = resourceGroup().location

@description('VM SKU — workshop için B2ms (2 vCPU / 8 GB) önerilir. B2s (4 GB) sınırda kalır.')
param vmSize string = 'Standard_B2ms'

@description('Linux admin kullanıcı adı.')
param adminUsername string = 'dmcshop'

@description('SSH public key — deploy.sh ~/.ssh/dmcshop_ed25519.pub değerini geçirir.')
@secure()
param adminSshPublicKey string

@description('Erişime izin verilen client IP/CIDR — varsayılan: dünyaya açık. Production icin kendi IP/32 araligina daralt.')
param allowedClientCidr string = '*'

@description('cloud-init base64 — deploy.sh script tarafindan base64 olarak verilir.')
@secure()
param cloudInitBase64 string

@description('Demo etiketi — fatura / temizlik için.')
param tags object = {
  project: 'dmcshop-sql2025'
  purpose: 'workshop-demo'
  environment: 'demo'
}

var vmName       = '${namePrefix}-vm'
var nicName      = '${namePrefix}-nic'
var nsgName      = '${namePrefix}-nsg'
var vnetName     = '${namePrefix}-vnet'
var subnetName   = 'app'
var pipName      = '${namePrefix}-pip'
var dnsLabel     = toLower('${namePrefix}-${uniqueString(resourceGroup().id)}')

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1001
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedClientCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          priority: 1010
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedClientCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 1020
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedClientCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [ '10.20.0.0/16' ] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.20.1.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: pipName
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: { domainNameLabel: dnsLabel }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: '${vnet.id}/subnets/${subnetName}' }
          publicIPAddress: { id: pip.id }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
      }
      customData: cloudInitBase64
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: 64
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: nic.id } ]
    }
  }
}

output vmId          string = vm.id
output publicIp      string = pip.properties.ipAddress
output fqdn          string = pip.properties.dnsSettings.fqdn
output adminUsername string = adminUsername
output sshCommand    string = 'ssh ${adminUsername}@${pip.properties.dnsSettings.fqdn}'
output appUrl        string = 'http://${pip.properties.dnsSettings.fqdn}'
