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

$script:Az_Profile = 'Az.Accounts'
$script:Az_Resources = 'Az.Resources'
$script:Az_Compute = 'Az.Compute'
$script:Az_Network = 'Az.Network'
$script:Az_Storage = 'Az.Storage'

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

    ## Install your version of Az modules
    Write-Output "Ensure $script:Az_Profile, $script:Az_Resources, $script:Az_Compute, $script:Az_Network, $script:Az_Storage modules are installed"

    Write-Output "Bootstrap Nuget"
    
    If ($IsCoreCLR)
    {
        pwsh -command 'Get-PackageProvider -Name Nuget -ForceBootstrap'
    }
    else
    {
        PowerShell -command 'Get-PackageProvider -Name Nuget -ForceBootstrap'
    }

    # Set PSGallery Repo to be Trusted to avoid prompt
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    
    Write-Output "Import required modules to current session if not already done"
    if (-not (Get-Module -Name $script:Az_Profile))
    {
        Import-Module $script:Az_Profile -Force -ErrorAction Stop
    }

    if (-not (Get-Module -Name $script:Az_Resources))
    {
        Import-Module $script:Az_Resources -Force -ErrorAction Stop
    }

    if (-not (Get-Module -Name $script:Az_Compute))
    {
        Import-Module $script:Az_Compute -Force -ErrorAction Stop
    }

    if (-not (Get-Module -Name $script:Az_Network))
    {
        Import-Module $script:Az_Network -Force -ErrorAction Stop
    }

    if (-not (Get-Module -Name $script:Az_Storage))
    {
        Import-Module $script:Az_Storage -Force -ErrorAction Stop
    }
    
    & $script:Az_Profile\Disable-AzDataCollection

    $testModuleRelativePath = Get-ChildItem -Name Test.psm1 -Path $PSScriptRoot -Recurse
    $testModuleFullPath = (Join-Path $PSScriptRoot $testModuleRelativePath)
    
    Write-Output "Import the test wrapper for AzurePSDrive from $testModuleFullPath"
    Import-Module $testModuleFullPath -Force

    Write-Output "Login to Azure Service"
    Login-Az
        
    $azurePSDriveFullPath = (Join-Path (Split-Path $PSScriptRoot) AzurePSDrive.psd1)
    
    Write-Output "Import AzurePSDrive from $azurePSDriveFullPath"
    Import-Module $azurePSDriveFullPath -Force

    Write-Output "Invoke AzurePSDrive Tests"
    Invoke-AzurePSDriveTests $subscriptionName

} catch {
    if($PSItem.Exception.Message -like '*tests failed') {
        Write-Output $PSItem.Exception.Message
    } else {
        Write-Output "Something went wrong: $PSItem" -ForegroundColor Red
        ($PSItem.ScriptStackTrace).Split([Environment]::NewLine) | Where-Object {$_.Length -gt 0} | ForEach-Object { Write-Verbose "`t$_" }
    }
    exit 1
}

exit 0