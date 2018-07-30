param (
    
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$subscriptionName,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$azureADAppId,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$azurePassword,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$azureTenantId

)

$script:AzureRM_Profile = if($IsCoreCLR){'AzureRM.Profile.NetCore'}else{'AzureRM.Profile'}
$script:AzureRM_Resources = if($IsCoreCLR){'AzureRM.Resources.Netcore'}else{'AzureRM.Resources'}
$script:AzureRM_Compute = if($IsCoreCLR){'AzureRM.Compute.NetCore'}else{'AzureRM.Compute'}
$script:AzureRM_Network = if($IsCoreCLR){'AzureRM.Network.NetCore'}else{'AzureRM.Network'}
$script:AzureRM_Storage = if($IsCoreCLR){'AzureRM.Storage.NetCore'}else{'AzureRM.Storage'}

# Note: Administrator PowerShell required to run this script.
try {
    $env:azureADAppId = $azureADAppId
    $env:azurePassword = $azurePassword
    $env:azureTenantId = $azureTenantId

    if (-not ($env:azureADAppId -and $env:azurePassword-and $env:azureTenantId))
    {
        Write-Output "Ensure environment contains Azure Application Id - $env:azureADAppId, Password - $env:azurePassword and Tenant Id - $env:azureTenantId for creating a Service Princpal Credential"
        Write-Output "Ensure the Service Principal has required access to create Compute/Network/Storage resource provider instances"
    }

    ## Install your version of AzureRM modules
    Write-Output "Ensure $script:AzureRM_Profile, $script:AzureRM_Resources, $script:AzureRM_Compute, $script:AzureRM_Network, $script:AzureRM_Storage modules are installed"

    # Write-Output "Update PowerShellGet"
    # Update PowerShellGet otherwise you will get an error 
    # "Cannot process argument transformation on parameter 'InstalledModuleInfo'. Cannot convert the "System.Object[]" 
    # value of type "System.Object[]" to type System.Management.Automation.PSModuleInfo"
    # PowerShell -command 'Install-PackageProvider NuGet -Force -ForceBootstrap; Install-Module -Name PowerShellGet -Force -AllowClobber -Repository PSGallery'
    
    Write-Output "Import required modules to current session"
    Import-Module $script:AzureRM_Profile -Force -ErrorAction Stop
    Import-Module $script:AzureRM_Resources -Force -ErrorAction Stop
    Import-Module $script:AzureRM_Compute -Force -ErrorAction Stop
    Import-Module $script:AzureRM_Network -Force -ErrorAction Stop
    Import-Module $script:AzureRM_Storage -Force -ErrorAction Stop
    & $script:AzureRM_Profile\Disable-AzureRmDataCollection

    $azurePSDrivePath = "$PSScriptRoot\.."

    Write-Host "Import the test wrapper for AzurePSDrive"
    Import-Module (Join-Path $azurePSDrivePath 'tests\test.psm1') -Force

    Write-Output "Login to Azure Service"
    Login-AzureRM    

    Write-Output "Invoke AzurePSDrive Tests"
    Invoke-AzurePSDriveTests $subscriptionName

} catch {
    if($PSItem.Exception.Message -like '*tests failed') {
        Write-Output $PSItem.Exception.Message
    } else {
        Write-Host "Something went wrong: $PSItem" -ForegroundColor Red
        ($PSItem.ScriptStackTrace).Split([Environment]::NewLine) | Where-Object {$_.Length -gt 0} | ForEach-Object { Write-Verbose "`t$_" }
    }
    exit 1
}

exit 0