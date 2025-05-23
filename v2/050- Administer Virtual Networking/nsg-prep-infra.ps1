# Preferences
$WarningPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Break'

# Variables
$rg = "rg-nsg-workload-$(Get-Date -Format 'yyyyMMdd')"
$region = "centralindia"
$username = "kodekloud" # username for the VM
$plainPassword = "VMP@55w0rd" # your VM password

# Creating VM credential; use your own password and username by changing the variables if needed
$password = ConvertTo-SecureString $plainPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $password)

# Create RG
Write-Host "Adding resource group : $rg " -ForegroundColor "Yellow" -BackgroundColor "Black"
New-AzResourceGroup -Name $rg -Location $region | Out-Null

#########-----Create resources---------######

# Creating vnet and VMs in workload-a
Write-Host "Adding workload-a network configuration" -ForegroundColor "Yellow" -BackgroundColor "Black"

$workloadA = New-AzVirtualNetworkSubnetConfig -Name 'snet-workload-a' -AddressPrefix 192.168.1.0/24
$workloadB = New-AzVirtualNetworkSubnetConfig -Name 'snet-workload-b' -AddressPrefix 192.168.2.0/24

# Create Virtual Network
try {
    New-AzVirtualNetwork -ResourceGroupName $rg -Location $region -Name "vnet-workloads" -AddressPrefix "192.168.0.0/16" -Subnet $workloadA, $workloadB | Out-Null
    Write-Host "Virtual network created successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to create virtual network: $_" -ForegroundColor Red
    break
}

$region = "westus" # Change to a different region

$existingPublicIpA = "existing-public-ip-a"
$existingPublicIpB = "existing-public-ip-b"

$retryCount = 3
$retryInterval = 30 # seconds

for ($i = 1; $i -lt 3; $i++) {
    Write-Host "Creating workload-a-vm-$i" -ForegroundColor "Yellow" -BackgroundColor "Black"
    $spAvm = New-AzVM -Name "workload-a-vm-$i" `
        -ResourceGroupName $rg `
        -Location $region `
        -Size 'Standard_B1s' `
        -Image "Ubuntu2204" `
        -VirtualNetworkName "vnet-workloads" `
        -SubnetName 'snet-workload-a' `
        -Credential $credential `
        -PublicIpAddressName "workload-a-vm-$i-pip" `
        -PublicIpSku Standard
    $fqdn = $spAvm.FullyQualifiedDomainName
    Write-Host "workload-a-vm-$i FQDN : $fqdn " -ForegroundColor Green 

    Write-Host "Creating workload-b-vm-$i" -ForegroundColor "Yellow" -BackgroundColor "Black" 
    $attempt = 0
    while ($attempt -lt $retryCount) {
        try {
            $spBvm = New-AzVM -Name "workload-b-vm-$i" `
                -ResourceGroupName $rg `
                -Location $region `
                -Image "Ubuntu2204" `
                -Size 'Standard_B1s' `
                -VirtualNetworkName "vnet-workloads" `
                -SubnetName 'snet-workload-b' `
                -Credential $credential `
                -PublicIpAddressName "workload-b-vm-$i-pip" `
                -PublicIpSku Standard
            $fqdn = $spBvm.FullyQualifiedDomainName
            Write-Host "workload-b-vm-$i FQDN: $fqdn " -ForegroundColor Green 
            break
        } catch {
            Write-Host "Attempt $($attempt + 1) failed. Retrying in $retryInterval seconds..." -ForegroundColor Red
            Start-Sleep -Seconds $retryInterval
            $attempt++
        }
    }
    if ($attempt -eq $retryCount) {
        Write-Host "Failed to create workload-b-vm-$i after $retryCount attempts." -ForegroundColor Red
    }
}
