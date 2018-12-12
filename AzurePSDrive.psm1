using namespace Microsoft.PowerShell.SHiPS
using module .\AzurePSDriveResource.psm1
using module .\AzurePSDriveStorageAccount.psm1
using module .\AzurePSDriveVM.psm1
using module .\AzurePSDriveWebApp.psm1

$script:pathPattern = [System.IO.Path]::Combine('Azure:', '*', 'ResourceGroups', '*')
$script:pathSeparator = if([System.IO.Path]::DirectorySeparatorChar -eq '\'){'\\'}else{'/'}

# Automatically pick resource group when inside resourcegroups of Azure drive
$Global:PSDefaultParameterValues['*-Az*:ResourceGroupName'] = {if($pwd -like $script:pathPattern){($pwd -split $script:pathSeparator)[3]}}

[SHiPSProvider(UseCache=$true)]
class Azure : SHiPSDirectory
{
    Azure([string]$name): base($name)
    {        
        # Ensure Session is logged-on to access Azure resources
        # This is done in the constructor so that it is a runtime check and not done during module import.
        $context = Az.Accounts\Get-AzContext
        if ([string]::IsNullOrEmpty($($context.Account)))
        {
            throw "Ensure that session has access to Azure resources - use Az.Accounts\Connect-AzAccount or Az.Accounts\Login-AzAccount"
        }
    } 

    [object[]] GetChildItem()
    {
        $obj =  @()  
        
        $defaultTenantId = $null      
        
        # Cloud Shell provides us with a default directory for Azure -> that maps to a tenant
        # This is provided in the form of tenantId in env variable ACC_TID
        if (-not $env:ACC_TID)
        {
            # Default tenantId not provided (perhaps provider is being run standalone => not in Cloud Shell)
            $tenant = Az.Accounts\Get-AzTenant

            if (($tenant -eq $null) -or ($tenant.Count -eq 0))
            {
                throw ('Unable to obtain tenant for the account. Check your subscription to ensure there is at least one tenant')
            }

            # Use the first tenant, since this maps to the default directory chosen by the user via Portal
            $defaultTenantId = $tenant[0].Id
            Write-Verbose "Using TenantId '$($tenant[0].TenantId)'"                
            Write-Verbose "To change default tenant: Use Az.Accounts\Get-AzTenant to retrieve your tenants corresponding to directories and set environment variable 'ACC_TID' to desired tenant"
            Write-Verbose "Reload AzurePSDrive provider OR use 'dir -Force' when navigating the subscription"
        }
        else
        {
            Write-Verbose "Using TenantId '$($env:ACC_TID)' from 'ACC_TID' environment variable..."
            $defaultTenantId = $env:ACC_TID
        }
        
        $subscriptions = $((Az.Accounts\Get-AzSubscription -TenantId $defaultTenantId) | Sort-Object -Property Name)
        $subGroup = $subscriptions | Group-Object -Property Name

        foreach ($subscription in $subscriptions)
        {         
            
            $obj += [Subscription]::new($subscription.Name, $subscription.Name, $subscription.Id, $subscription.TenantId, $subscription.State)
            
        }

        return $obj;
    }
}

[SHiPSProvider(UseCache=$true)]
class Subscription : SHiPSDirectory
{
    [string]$SubscriptionName = $null
    [string]$SubscriptionId = $null
    [string]$TenantId = $null
    [string]$State = $null
            
    Subscription ([string]$subNameWithTenantId, [string]$subName, [string]$subId, [string]$tenantId, [string]$state) : base ($subNameWithTenantId)
    {
        $this.SubscriptionName = $subName
        $this.SubscriptionId = $subId
        $this.TenantId = $tenantId
        $this.State = $state
    }    

    [object[]] GetChildItem()
    {        
        Az.Accounts\Select-AzSubscription -SubscriptionName $this.SubscriptionName -TenantId $this.TenantId
        $obj =  @()

        $obj+=[AllResources]::new();
        $obj+=[ResourceGroups]::new("ResourceGroups", $this.SubscriptionName, $this.SubscriptionId, $this.TenantId, $this.State)
        $obj+=[StorageAccounts]::new();
        $obj+=[VirtualMachines]::new();
        $obj+=[WebApps]::new();

        return $obj;
    }
 }
[SHiPSProvider(UseCache=$true)]
class ResourceGroups : SHiPSDirectory
{
    [string]$SubscriptionName = $null
    [string]$SubscriptionId = $null
    [string]$TenantId = $null
    [string]$State = $null
    [object[]]$rgs

    ResourceGroups ([string]$name, [string]$subName, [string]$subId, [string]$tenantId, [string]$state) : base ($name)
    {
        $this.SubscriptionName = $subName
        $this.SubscriptionId = $subId
        $this.TenantId = $tenantId
        $this.State = $state
    }


    [object[]] GetChildItem()
    {
        #Az.Accounts\Select-AzSubscription -SubscriptionName $this.SubscriptionName -TenantId $this.TenantId
        $obj =  @()
        $subId = $this.SubscriptionId

        @(Az.Resources\Get-AzResourceGroup).Foreach{
             
            $obj +=  [ResourceGroup]::new($subId, $_.ResourceGroupName, $_.Location, $_.ProvisioningState);                  
        }

        return $obj;
    }
 }

[SHiPSProvider(UseCache=$true)]
class ResourceGroup : SHiPSDirectory
{
    [string]$SubscriptionId = $null
    [string]$ResourceGroupName = $null
    [string]$Location = $null
    [string]$ProvisioningState = $null
        
    ResourceGroup ([string]$subscriptionId, [string]$name, [string]$location, [string]$provisioningState) : base ($name) 
    {
        $this.SubscriptionId = $subscriptionId
        $this.ResourceGroupName = $name
        $this.Location = $location
        $this.ProvisioningState = $provisioningState
    }

    [object[]] GetChildItem()
    {        
        $obj =  @()

        $resourceTypes = @(Az.Resources\Get-AzResource | Where-Object {$_.ResourceGroupName -eq $this.ResourceGroupName}  | select-Object -Property ResourceType -Unique).ForEach{$_.ResourceType.Split('/')[0]} | Select-Object -Unique
        foreach ($resourceType in $resourceTypes)
        {            
            $tempObj = [ResourceProvider]::new($resourceType, $this.ResourceGroupName);            
            
            $obj +=  $tempObj
        }
        
        return $obj; 
    }
 }

[SHiPSProvider(UseCache=$true)]
class ResourceProvider : SHiPSDirectory
{
    [string]$providerNamespace = $null
    [string]$resourceGroupName = $null

    ResourceProvider([string]$name): base($name)
    {
    }

    ResourceProvider ([string]$name, [string]$resourceGroupName) : base ($name) 
    {
        $this.providerNamespace = $name
        $this.resourceGroupName = $resourceGroupName
    }

    [object[]] GetChildItem()
    {        
        $obj =  @()

        $resourceTypeTokens = @()
        @(Az.Resources\Get-AzResource | Where-Object {$_.ResourceGroupName -eq $this.resourceGroupName} | Select-Object -Property ResourceType -Unique).ForEach{

            $providerNS = $_.ResourceType.Split('/')[0]
            $resourceType = $_.ResourceType.Substring($_.ResourceType.IndexOf('/')+1)
            $resourceType = $resourceType.Replace('/','-')
            if ($this.providerNamespace -eq $providerNS)
            {
                    $resourceTypeTokens += $resourceType
            }
        }

        foreach ($resourceTypeToken in ($resourceTypeTokens | Select-Object -Unique))
        {   
            $tempObj =  [ResourceType]::new($resourceTypeToken, $this.providerNamespace, $this.resourceGroupName);             

            $obj += $tempObj
        }        

        return $obj; 
    }
 }

[SHiPSProvider(UseCache=$true)]
class ResourceType : SHiPSDirectory
{
    [string]$resourceTypeName = $null
    [string]$resourceType = $null
    [string]$resourceGroupName = $null
    [string]$providerNamespace = $null
    [object]$Properties = $null

    ResourceType([string]$name): base($name)
    {
    }

    ResourceType ([string]$name, [string]$providerNamespace, [string]$resourceGroupName) : base ($name) 
    {   
        $this.resourceTypeName = $name
        $this.resourceGroupName = $resourceGroupName 
        $this.providerNamespace = $providerNamespace 
        $this.resourceType = $providerNamespace + '/' + $this.resourceTypeName.Replace('-', '/')
    }

    [object[]] GetChildItem()
    {        
        $obj =  @()

        $AzResourceParams = @{'ResourceGroupName'="$($this.resourceGroupName)"}
        $AzResourceParams += @{'ResourceType'="$($this.resourceType)"}
        $AzResourceParams += @{'ExpandProperties'=$true}

        if ($this.ProviderContext.Filter)
        {
            $AzResourceParams += @{'ODataQuery'=(Get-ODataQueryFilter -filter $this.ProviderContext.Filter)}
        }
        
        @(Az.Resources\Get-AzResource @AzResourceParams).Foreach{
                    
            if ($_.PSTypeNames.Contains('Microsoft.Network.networkSecurityGroups'))
            {   
                $typeName = $_.PSTypeNames[$_.PSTypeNames.IndexOf('Microsoft.Network.networkSecurityGroups')]

                foreach ($securityRule in $_.Properties.securityRules)
                {
                    $tempObj = $securityRule

                    1..2 | ForEach-Object {$tempObj.PSTypeNames.RemoveAt(0)}
                    $tempObj.PSTypeNames.Insert(0, $typeName + '.Rules')
                    
                    $obj += $tempObj
                }

                foreach ($defaultSecurityRule in $_.Properties.defaultSecurityRules)
                {
                    $tempObj = $defaultSecurityRule
                    
                    1..2 | ForEach-Object {$tempObj.PSTypeNames.RemoveAt(0)}            
                    $tempObj.PSTypeNames.Insert(0, $typeName + '.Rules')
                                        
                    $obj += $tempObj
                }
            }
            elseif ($_.PSTypeNames.Contains('Microsoft.Network.routeTables'))
            {                
                $typeName = $_.PSTypeNames[$_.PSTypeNames.IndexOf('Microsoft.Network.routeTables')]

                foreach ($route in $_.Properties.routes)
                {
                    $tempObj = $route

                    1..2 | ForEach-Object {$tempObj.PSTypeNames.RemoveAt(0)}
                    $tempObj.PSTypeNames.Insert(0, $typeName + '.routes')      

                    $obj += $tempObj
                }                

            }
            else

            {     
                $tempObj = $_
                1..2 | ForEach-Object {$tempObj.PSTypeNames.RemoveAt(0)}                                           
                $obj += $tempObj            
            }
        }
        
        return $obj; 

    }
 }

 #region Utilities

 # Given the filter string, return corresponding OData query filter in the format '$filter=<Name> <operator> <Value>'
 # Else, return null for invalid cases
 function Get-ODataQueryFilter
 {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $filter
    )
    

    if ('*' -eq $filter)
    {
        return $null
    }

    if ($filter.Contains('*'))
    {
        if ($filter.StartsWith('*') -and $filter.EndsWith('*'))
        {
            return "`$filter=substringof(Name, $filter.Replace('*', '')) eq true"
        }
        elseif ($dynamicParameters.Filter.StartsWith('*') -and (-not $dynamicParameters.Filter.EndsWith('*')))
        {            
            return "`$filter=EndsWith(Name, $filter.Replace('*', ''))"
        }
        elseif ($dynamicParameters.Filter.EndsWith('*') -and (-not $dynamicParameters.Filter.StartsWith('*')))
        {            
            return "`$filter=StartsWith(Name, $filter.Replace('*', ''))"
        }
        else
        {
            $filterTokens = $filter.Split('*')
            return "`$filter=StartsWith(Name, $filterTokens[0])"
        }
    }

    return $null
 }

 #endregion
