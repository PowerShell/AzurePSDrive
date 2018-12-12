# Pester tests for AzurePSDrive PowerShell Provider
# 'Describe' sections are organized by the flow of the provider
# Ex: Drive:\Subscription\ResourceGroup\ResourceProvider\ResourceType
# Note: There is a one time initialization of all Compute/Network/Storage resouces in Azure which is used by the Test Suite

param (
    [string]$subscriptionName = 'AutomationTeam'
)

$script:Az_Profile = 'Az.Accounts'
$script:Az_Resources = 'Az.Resources'
$script:Az_Compute = 'Az.Compute'
$script:Az_Network = 'Az.Network'
$script:Az_Storage = 'Az.Storage'

function New-PartialGuidForName { ([guid]::NewGuid().ToString() -replace '-','')[0..9] -join '' }

#region Script variables
$resourceGroupName = "rgapsdt$(New-PartialGuidForName)"
$location = 'WestUS'
$storageAccountName = "saapsdt$(New-PartialGuidForName)"
$skuName = 'Standard_LRS'
$interfaceName = 'TestInterface'
$subnetName = 'TestSubnet1'
$vnetName = 'TestVNet1'
$vnetAddressPrefix = '10.0.0.0/16'
$vnetSubnetAddressPrefix = '10.0.0.0/24'
$vmName = 'TestVM'
$computerName = 'TestServer'
$adminUserName = 'localadmin'
$vmSize = 'Standard_A2'
$osDiskName = $VMName + "OSDisk"
#endregion

#region Utility
# Verify that dependent modules required by the test are available in current session
function Test-Dependency
{
    if ((-not (Get-Module -Name $script:Az_Profile)) `
    -or (-not (Get-Module -Name $script:Az_Resources)) `
    -or (-not (Get-Module -Name $script:Az_Compute)) `
    -or (-not (Get-Module -Name $script:Az_Network)) `
    -or (-not (Get-Module -Name $script:Az_Storage)) `
    -or (-not (Get-Module -Name SHiPS)) `
    -or (-not (Get-Module -Name AzurePSDrive)))
    {
        throw "Ensure $script:Az_Profile, $script:Az_Resources, $script:Az_Compute, $script:Az_Network, $script:Az_Storage, SHiPS, AzurePSDrive modules are installed"
    }
}

# Create AzurePSDrive PowerShell Drive
function New-AzureDrive
{   
    $driveName = 'Azure'
    Remove-PSDrive $driveName -ErrorAction SilentlyContinue    
    New-PSDrive -Name $driveName -PSProvider SHiPS -Root AzurePSDrive#Azure -Scope Global -ErrorAction Stop
}

# Initialize ResourceGroup and other Azure deployments
# One time setup in Azure
function Initialize-AzureTestResource
{    
    Write-Verbose "Creating the resources used by the tests..."
    # ResourceGroup
    $rg = & $script:Az_Resources\Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if ($rg -eq $null)
    {
        $rg = & $script:Az_Resources\New-AzResourceGroup -Name $resourceGroupName -Location $location -Force -Verbose
    }

    #Storage
    $storage = & $script:Az_Storage\Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    if ($storage -eq $null)
    {
        $storage = & $script:Az_Storage\New-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -Location $location -SkuName $skuName -Verbose
    }

    #Network
    $interface = & $script:Az_Network\Get-AzNetworkInterface -Name $interfaceName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    if ($interface -eq $null)
    {
        $pubIp = & $script:Az_Network\New-AzPublicIpAddress -Name $interfaceName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic -Force -Verbose
        $subnetConfig = & $script:Az_Network\New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $vnetSubnetAddressPrefix -Verbose
        $vnet = & $script:Az_Network\New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig -Force -Verbose
        $interface = & $script:Az_Network\New-AzNetworkInterface -Name $interfaceName -ResourceGroupName $resourceGroupName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pubIp.Id -Force -Verbose
    }
        
    #Compute - VM
    $virtualMachine = & $script:Az_Compute\Get-AzVM -Name $vmName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    if ($virtualMachine -eq $null)
    {
        $password = "TestAsdf1234!!!" | ConvertTo-SecureString -asPlainText -Force
        $credential = $credential = New-Object System.Management.Automation.PSCredential($adminUserName,$password)
        $virtualMachine = & $script:Az_Compute\New-AzVMConfig -VMName $vmName -VMSize $vmSize
        $virtualMachine = & $script:Az_Compute\Set-AzVMOperatingSystem -VM $virtualMachine -Windows -ComputerName $computerName -Credential $credential -ProvisionVMAgent -EnableAutoUpdate
        $virtualMachine = & $script:Az_Compute\Set-AzVMSourceImage -VM $virtualMachine -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version "latest"
        $virtualMachine = & $script:Az_Compute\Add-AzVMNetworkInterface -VM $virtualMachine -Id $interface.Id
        $osDiskUri = $storage.PrimaryEndpoints.Blob.ToString() + "vhds/" + $osDiskName + ".vhd"
        $virtualMachine = & $script:Az_Compute\Set-AzVMOSDisk -VM $virtualMachine -Name $osDiskName -VhdUri $osDiskUri -CreateOption FromImage    

        #Create the VM in Azure
        & $script:Az_Compute\New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $virtualMachine
    }
    Write-Verbose "Resources created."
}
#endregion

# Remove ResourceGroup and other Azure deployments
# One time teardown in Azure
function Remove-AzureTestResource
{
    Write-Verbose "Deleting the resources used by the tests..."
    # ResourceGroup
    $rg = & $script:Az_Resources\Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if ($rg -ne $null)
    {
        $rg | & $script:Az_Resources\Remove-AzResourceGroup -Force
    }
    Write-Verbose "Resources deleted."
}
#endregion

#region Test Suite Initialization
cd $PSScriptRoot
Test-Dependency
Initialize-AzureTestResource
New-AzureDrive
#endregion

#region Get-Subscription Tests
Describe Get-Subscription {
    BeforeAll {
        cd Azure:
    }

    It "Retrieving a valid Azure Subscription using the provider" {
        $sub = dir

        # Only one subscription corresponding to the service principal and tenant must be returned        
        $sub.Count | Should Be 1
        $sub.Name | Should Be $subscriptionName
        $sub.SubscriptionName | Should Be $subscriptionName

        # Indicates that this is a DirectoryType object
        $sub.SSItemMode | Should Be '+'
        $sub.PSDrive | Should Be 'Azure'
        $sub.SubscriptionId | Should not BeNullOrEmpty
        $sub.TenantId | Should not BeNullOrEmpty
        $sub.State | Should Be 'Enabled'
    }


    It "Retrieving an invalid subscription" {        

        try
        {
            dir invalidSubscription -ErrorAction Stop
        }
        catch
        {            
            $_.Exception.GetType().Name | Should Be 'ItemNotFoundException'
        }
    }

    It "Using Filter parameter with Force in Subscription" {
        $subNameWild = "$($subscriptionName[0])*$($subscriptionName.Substring($subscriptionName.Length - 1))"
        $sub = dir -Force -Filter $subNameWild

        # Only one subscription corresponding to specified Filter must be returned      
        $sub.Count | Should Be 1
        $sub.Name | Should Be $subscriptionName
        
    }

    It "Using non-existant Filter with Force in Subscription" {
        $sub = dir -Force -Filter Invalid*

        # None must be returned since supplied filter is non-existant     
        $sub | Should BeNullOrEmpty
        
    }
    
    AfterAll {
        Set-Location $PSScriptRoot
    }
}
#endregion

#region Get-ResourceGroup Tests
Describe Get-ResourceGroup {
    BeforeAll {
        cd "Azure:\$subscriptionName\ResourceGroups"
    }

    It "Retrieving a ResourceGroup in the subscription using Force switch and wild card" {        
        $rgNameWild = "$($resourceGroupName[0])*$($resourceGroupName.Substring(2, $resourceGroupName.Length - 4))*$($resourceGroupName.Substring($resourceGroupName.Length - 1))"
        $rg = dir $rgNameWild -Force       
        $rg.Count | Should Be 1
        
        # Indicates that this is a DirectoryType object        
        $rg.SubscriptionId | Should not BeNullOrEmpty
        $rg.ResourceGroupName | Should Be $resourceGroupName
        $rg.Name | Should Be $resourceGroupName
        $rg.Location | Should Be 'westus'
        $rg.ProvisioningState | Should Be 'Succeeded'
    }

    It "Retrieving a ResourceGroup in the subscription using wildcard in name" {
        $rgNameWild = "$($resourceGroupName[0])*$($resourceGroupName.Substring(2, $resourceGroupName.Length - 4))*$($resourceGroupName.Substring($resourceGroupName.Length - 1))"
        $rg = dir $rgNameWild
        $rg.Count | Should Be 1
        
        # Indicates that this is a DirectoryType object
        $rg.SSItemMode | Should Be '+'
        $rg.PSDrive | Should Be 'Azure'
        $rg.SubscriptionId | Should not BeNullOrEmpty
        $rg.ResourceGroupName | Should Be $resourceGroupName
        $rg.Name | Should Be $resourceGroupName
        $rg.Location | Should Be 'westus'
        $rg.ProvisioningState | Should Be 'Succeeded'
    }


    It "Retrieving an invalid ResourceGroup" {        

        try
        {
            dir InvalidRG -ErrorAction Stop
        }
        catch
        {            
            $_.Exception.GetType().Name | Should Be 'ItemNotFoundException'
        }
    }

    It "Using server supported ODataQuery Filter parameter in ResourceGroup" {
        # BUG: Using -Force in when retrieving OData filtered ResourceGroups results in an error
        # Using -Filter results in using ODataQuery based server-side filterring
        $rgNameWild = "$($resourceGroupName.Substring(0, $resourceGroupName.Length - 5))*"
        $rg = dir -Filter $rgNameWild

        # Only one ResourceGroup corresponding to specified Filter must be returned      
        $rg.Count | Should Be 1
        $rg.Name | Should Be $resourceGroupName
        
    }

    It "Using non-existant Filter in ResourceGroup" {
        $rgNameWild = "$($resourceGroupName[0])$($resourceGroupName[2])$($resourceGroupName[3])$($resourceGroupName[5])*"
        $rg = dir -Filter $rgNameWild

        # None must be returned since supplied filter is non-existant     
        $rg | Should BeNullOrEmpty
        
    }
    
    AfterAll {
        Set-Location $PSScriptRoot
    }
}
#endregion

<# Failing Test - Commenting to investigate
#region ResourceGroup with PSDefaultParameterValues Tests
Describe ResourceGroupPSDefaultParameterValues {
    BeforeAll {
        cd "Azure:\$subscriptionName\ResourceGroups"
    }

    It "Retrieving VM in a specific resourceGroup with PSDefaultParameterValues" {        
        $vmInAllResourceGroup = & $script:Az_Compute\Get-AzVM
        
        # Navigate to a specific ResourceGroup
        cd "$resourceGroupName"
        $vmInSpecificResourceGroup = & $script:Az_Compute\Get-AzVM

        # Since PSDefaultParameterValues are passed to Get-AzVM when in a particular ResourceGroup
        # results are filtered to the specific ResourceGroup
        ($vmInSpecificResourceGroup.Count -lt $vmInAllResourceGroup.Count) | Should Be $true        
    }   
    
    AfterAll {
        Set-Location $PSScriptRoot
    }
}
#endregion
#>

#region Get-ResourceProvider Tests
Describe Get-ResourceProvider {
    BeforeAll {
        cd "Azure:\$subscriptionName\ResourceGroups\$resourceGroupName"
    }

    It "Retrieving ResourceProviders in the ResourceGroup" {
        $providers = dir

        # AzurePSDrive provider does post-processing on the retrieved providers from Azure to eliminate duplicates
        # Hence count must be 3 - show only unique providers that have deployments
        $providers.Count | Should Be 3

        # Only following providers must be returned, since we initialized only these in 'Initialize-AzureTestResource'
        $expected = @('Microsoft.Compute', 'Microsoft.Network', 'Microsoft.Storage')
        $actual = @()
        foreach ($provider in $providers)
        {
            $actual += $provider.Name
        }
        $diff = Compare-Object -ReferenceObject $expected -DifferenceObject $actual -PassThru
        $diff | Should BeNullOrEmpty       
        
    }


    It "Retrieving an invalid Azure ResourceProvider" {        

        try
        {
            dir InvalidProvider -ErrorAction Stop
        }
        catch
        {            
            $_.Exception.GetType().Name | Should Be 'ItemNotFoundException'
        }
    }

    It "Using Filter parameter in ResourceProvider with Force switch" {        
        $provider = dir -Filter *Compute* -Force

        # Only one ResourceGroup corresponding to specified Filter must be returned      
        $provider.Count | Should Be 1
        $provider.Name | Should Be 'Microsoft.Compute'
        
    }

    It "Using non-existant Filter in ResourceProvider with Force switch" {
        $provider = dir -Filter DoesNotExist*

        # None must be returned since supplied filter is non-existant     
        $provider | Should BeNullOrEmpty
        
    }
    
    AfterAll {
        Set-Location $PSScriptRoot
    }
}
#endregion

#region Get-ResourceType Tests
Describe Get-ResourceType {
    BeforeAll {        
    }

    It "Retrieving ResourceTypes in the ResourceType with and without Force switch" {

        # Verify Compute Type
        cd "Azure:\$subscriptionName\ResourceGroups\$resourceGroupName\Microsoft.Compute"
        $resourceTypes = dir               
        $resourceTypes.Count | Should Be 2

        # Only following resourceTypes must be returned, since we initialized only these in 'Initialize-AzureTestResource'
        $expected = @('virtualMachines', 'virtualMachines-extensions')
        $actual = @()
        foreach ($resourceType in $resourceTypes)
        {
            $actual += $resourceType.Name
        }
        $diff = Compare-Object -ReferenceObject $expected -DifferenceObject $actual -PassThru
        $diff | Should BeNullOrEmpty        
        
        # Verify Network Type
        cd "Azure:\$subscriptionName\ResourceGroups\$resourceGroupName\Microsoft.Network"
        $resourceTypes = dir -Force              
        
        # In certain Subscriptions, depending on the settings, networksecuritygroups is also returned as a ResourceGroup
        $resourceTypes.Count | Should BeGreaterThan 2
        $resourceTypes.Count | Should BeLessThan 5

        # Only following resourceTypes must be returned, since we initialized only these in 'Initialize-AzureTestResource'
        $expected = @('networkInterfaces', 'publicIPAddresses', 'virtualNetworks')
        $actual = @()
        foreach ($resourceType in $resourceTypes)
        {
            $actual += $resourceType.Name
        }
        $diff = Compare-Object -ReferenceObject $expected -DifferenceObject $actual -PassThru
        
        # In certain Subscriptions, depending on the settings, networksecuritygroups is also returned as a ResourceGroup
        # So the diff can be null/empty OR can contain 'networkSecurityGroups'
        (($null -eq $diff ) -or (1 -eq $diff.Count)) | Should Be $true
        
    }


    It "Retrieving an invalid Azure ResourceType" {        

        try
        {
            dir InvalidResourceType -ErrorAction Stop
        }
        catch
        {            
            $_.Exception.GetType().Name | Should Be 'ItemNotFoundException'
        }
    }

    It "Using Filter parameter in ResourceType with Force switch" {
            
        # Verify Storage Type
        cd "Azure:\$subscriptionName\ResourceGroups\$resourceGroupName\Microsoft.Storage"
        $resourceType = dir -Filter *Storage* -Force

        # Only one ResourceType corresponding to specified Filter must be returned      
        $resourceType.Count | Should Be 1
        $resourceType.Name | Should Be 'storageAccounts'
        $resourceType.resourceType | Should Be 'Microsoft.Storage/storageAccounts'
        $resourceType.resourceGroupName | Should Be $resourceGroupName
        $resourceType.providerNamespace | Should Be 'Microsoft.Storage'
        
    }

    It "Using non-existant Filter in ResourceType with Force switch" {
        $resourceType = dir -Filter DoesNotExist* -Force

        # None must be returned since supplied filter is non-existant     
        $resourceType | Should BeNullOrEmpty
        
    }
    
    AfterAll {
        Set-Location $PSScriptRoot
    }
}
#endregion

#region Get-SpecificRMResourceType Tests
Describe Get-SpecificRMResourceType {
    BeforeAll {        

    }

    It "Retrieving VM type using the Provider" {

        cd "Azure:\$subscriptionName\ResourceGroups\$resourceGroupName\Microsoft.Compute\virtualMachines"

        $vm = dir

        # Validate all properties - Ensure they match the ones used during resource creation        
        $vm.ResourceName | Should Be $VMName
        $vm.Name | Should Be $VMName
        $vm.ResourceType | Should Be 'Microsoft.Compute/virtualMachines'
        $vm.Location | Should Be $location
        $vm.Properties.hardwareProfile.vmSize | Should Be $vmSize
        $vm.Properties.osProfile.computerName | Should Be $computerName
        $vm.Properties.osProfile.adminUsername | Should Be $adminUserName
        $vm.Properties.networkProfile.networkInterfaces.Count | Should Be 1
        $vm.Properties.provisioningState | Should Be 'Succeeded'
        
    }

    It "Retrieving Network type using the Provider" {

        cd "Azure:\$subscriptionName\ResourceGroups\$resourceGroupName\Microsoft.Network\networkInterfaces"

        $network = dir

        # Validate all properties - Ensure they match the ones used during resource creation        
        $network.ResourceName | Should Be $interfaceName
        $network.Name | Should Be $interfaceName
        $network.ResourceType | Should Be 'Microsoft.Network/networkInterfaces'
        $network.Location | Should Be $location
          
        $subnet = $network.Properties.ipConfigurations[0].properties.subnet.id
        $subnet.Contains($subnetName) | Should Be $true
        $subnet.Contains($vnetName) | Should Be $true        
        
        $publicIPAddress = $network.Properties.ipConfigurations[0].properties.publicIPAddress.id
        $publicIPAddress.Contains($interfaceName) | Should Be $true

        $network.Properties.provisioningState | Should Be 'Succeeded'
        $network.Properties.primary | Should Be 'True'
        
    }

      It "Retrieving Storage type using the Provider" {

        cd "Azure:\$subscriptionName\ResourceGroups\$resourceGroupName\Microsoft.Storage\storageAccounts"
        $storage = dir

        # Validate all properties - Ensure they match the ones used during resource creation        
        $storage.ResourceName | Should Be $storageAccountName
        $storage.Name | Should Be $storageAccountName
        $storage.ResourceType | Should Be 'Microsoft.Storage/storageAccounts'
        $storage.Location | Should Be $location
          
        $blob = $storage.Properties.primaryEndpoints.blob
        $blob.Contains($storageAccountName) | Should Be $true

        $file = $storage.Properties.primaryEndpoints.file
        $file.Contains($storageAccountName) | Should Be $true

        $queue = $storage.Properties.primaryEndpoints.queue
        $queue.Contains($storageAccountName) | Should Be $true
                
        $storage.Properties.provisioningState | Should Be 'Succeeded'        
        
    }
    
    AfterAll {
        Set-Location $PSScriptRoot
    }
}
#endregion

#region Get-AllResources with Recurse functionality Tests
Describe Get-AllResourcesWithRecurse {
    BeforeAll {     
       cd "Azure:\$subscriptionName\ResourceGroups\$resourceGroupName"
    }

    It "Retrieving all resources with Recurse switch from ResourceGroup top level" {

        $allResources = dir -Recurse -Force
        # There are resources deployed in Azure as part of 'Initialize-AzureTestResource'
        # This includes Storage, Network, Compute resources
        # Depending on the subscription this number varies, but min is 5 since we are deploying atleast one of each
        $allResources.Count | Should BeGreaterThan 5
        
    }    
    
    AfterAll {
        Set-Location $PSScriptRoot
    }
}
#endregion

#region AllResources, VMs, StorageAccounts, and Webapps tests
Describe "Get AllResource, VMs, StorageAccounts and Webapps" {
    BeforeAll {     
        & $script:Az_Profile\Disable-AzDataCollection
        cd "Azure:\$subscriptionName\"
    }

    It "Testing childitems under a subscription" {
        cd "Azure:\$subscriptionName\"
        $a = dir

        $a | ?{ $_.name -eq "AllResources" } | should not BeNullOrEmpty  
        $a | ?{ $_.name -eq "ResourceGroups" } | should not BeNullOrEmpty  
        $a | ?{ $_.name -eq "VirtualMachines" } | should not BeNullOrEmpty  
        $a | ?{ $_.name -eq "StorageAccounts" } | should not BeNullOrEmpty  
        $a | ?{ $_.name -eq "WebApps" } | should not BeNullOrEmpty  
        
    }    
    
    It "Retrieving all resources" {
        cd "Azure:\$subscriptionName\AllResources"
        $a = dir

        # Ensure it is not 0
        $a.Count | Should Not Be 0
    }
    
    It "Retrieving all VirtualMachines" {
        cd "Azure:\$subscriptionName\VirtualMachines"
        
        $a = dir

        # Ensure it is not 0
        $a.Count | Should Not Be 0
    }    
    
    It "Retrieving all StorageAccounts" {
        cd "Azure:\$subscriptionName\StorageAccounts"
        
        # shipsAztest is azurepsdriveteststorage, AzurePSDrive.Test is resourcegroup
        $a = dir

        # Ensure it is not 0
        $a.Count | Should Not Be 0
        
        cd .\$storageAccountName\
        
        $b=dir
        $b | ?{ $_.name -eq "Blobs" } | should not BeNullOrEmpty  
        $b | ?{ $_.name -eq "Files" } | should not BeNullOrEmpty  
        $b | ?{ $_.name -eq "Tables" } | should not BeNullOrEmpty  
        $b | ?{ $_.name -eq "Queues" } | should not BeNullOrEmpty  

        cd .\Blobs\
        $c=dir
        $c | ?{ $_.name -eq "vhds" } | should not BeNullOrEmpty  

        cd vhds
        $d=dir
        $d | Should Not BeNullOrEmpty

        cd "Azure:\$subscriptionName\StorageAccounts\$storageAccountName\Files"
        $e=dir
        $e | Should BeNullOrEmpty

        cd "Azure:\$subscriptionName\StorageAccounts\$storageAccountName\Tables"
        $g=dir
        $g | Should BeNullOrEmpty

        cd "Azure:\$subscriptionName\StorageAccounts\$storageAccountName\Queues"
        $h=dir
        $h | Should BeNullOrEmpty
    } 
     
    AfterAll {
        Set-Location $PSScriptRoot
    }
}
#endregion

Remove-AzureTestResource