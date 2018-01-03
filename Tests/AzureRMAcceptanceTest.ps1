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

    ## Install your version of AzureRM modules - specifically AzureRM.Resources, AzureRM.Profile, AzureRM.Compute, AzureRM.Network, AzureRM.Storage
    Write-Output "Ensure AzureRM.Resources, AzureRM.Profile, AzureRM.Compute, AzureRM.Network, AzureRM.Storage modules are installed"

    Write-Output "Update PowerShellGet"
    # Update PowerShellGet otherwise you will get an error 
    # "Cannot process argument transformation on parameter 'InstalledModuleInfo'. Cannot convert the "System.Object[]" 
    # value of type "System.Object[]" to type System.Management.Automation.PSModuleInfo"
    PowerShell -command 'Install-PackageProvider NuGet -Force -ForceBootstrap; Install-Module -Name PowerShellGet -Force -AllowClobber -Repository PSGallery'

    # SHiPS is untrusted repository. Setting PSGallery's policy to Trusted allows this to install without a prompt.
    # https://blogs.technet.microsoft.com/poshchap/2015/08/07/getting-started-with-the-powershell-gallery/
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Write-Output "Install SHiPS module from PowerShellGallery - required dependency for AzurePSDrive"
    Install-Module -Name SHiPS -Verbose -Repository PSGallery

    Write-Output "Import required modules to current session"
    Import-Module AzureRM.Resources -Force -Verbose
    Import-Module AzureRM.Profile -Force -Verbose
    Import-Module AzureRM.Compute -Force -Verbose
    Import-Module AzureRM.Network -Force -Verbose
    Import-Module AzureRM.Storage -Force -Verbose
    Import-Module SHiPS -Force -Verbose
    AzureRM.Profile\Disable-AzureRmDataCollection

    $azurePSDrivePath = "$PSScriptRoot\.."

    Write-Host "Import the test wrapper for AzurePSDrive"
    Import-Module (Join-Path $azurePSDrivePath 'tests\test.psm1') -Force -Verbose

    Write-Output "Login to Azure Service"
    Login-AzureRM

    Write-Output "Import AzurePSDrive module to current session"
    Import-Module (Join-Path $azurePSDrivePath 'azurepsdrive.psd1') -Force -Verbose

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