# Preferences
$WarningPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'  # Changed to "Stop" for more controlled error handling

# Variables
$rg = "rg-nsg-workload-$(Get-Date -Format 'yyyyMMdd')"
$region = "eastus"
$username = "kodekloud" # Username for the VM
$plainPassword = "VMP@55w0rd" # Your VM password

# Creating VM credential
$password = ConvertTo-SecureString $plainPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $password)

# Create Resource Group
Write-Host "Adding resource group : $rg" -ForegroundColor "Yellow" -BackgroundColor "Black"
try {
    New-AzResourceGroup -Name $rg -Location $region | Out-Null
    Write-Host "Resource group created successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to create resource group: $_"
    return
}

# Subnet Configuration
Write-Host "Configuring subnets for vnet-workloads" -ForegroundColor "Yellow" -BackgroundColor "Black"

$workloadA = New-AzVirtualNetworkSubnetConfig `
    -Name 'snet-workload-a' `
    -AddressPrefix 192.168.1.0/24

$workloadB = New-AzVirtualNetworkSubnetConfig `
    -Name 'snet-workload-b' `
    -AddressPrefix 192.168.2.0/24

# Create Virtual Network
try {
    New-AzVirtualNetwork `
        -ResourceGroupName $rg `
        -Location $region `
        -Name "vnet-workloads" `
        -AddressPrefix 192.168.0.0/16 `
        -Subnet $workloadA, $workloadB | Out-Null
    Write-Host "Virtual network created successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to create virtual network: $_"
    return
}

# Helper Function to Deploy VMs
function Deploy-VM {
    param (
        [string]$vmName,
        [string]$subnetName
    )

    Write-Host "Creating $vmName" -ForegroundColor "Yellow" -BackgroundColor "Black"
    try {
        $vm = New-AzVM -Name $vmName `
            -ResourceGroupName $rg `
            -Location $region `
            -Size 'Standard_B1s' `
            -Image "Ubuntu2204" `
            -VirtualNetworkName "vnet-workloads" `
            -SubnetName $subnetName `
            -Credential $credential `
            -PublicIpAddressName "$vmName-pip" `
            -PublicIpSku Standard

        $fqdn = $vm.FullyQualifiedDomainName
        Write-Host "$vmName FQDN: $fqdn" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create $vmName: $_"
    }
}

# Deploy VMs
for ($i = 1; $i -le 2; $i++) {
    Deploy-VM -vmName "workload-a-vm-$i" -subnetName 'snet-workload-a'
    Deploy-VM -vmName "workload-b-vm-$i" -subnetName 'snet-workload-b'
}
