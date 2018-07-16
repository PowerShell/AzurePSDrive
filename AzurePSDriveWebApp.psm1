using namespace Microsoft.PowerShell.SHiPS

$script:AzureRM_WebApp = if($IsCoreCLR){'AzureRM.Websites.Netcore'}else{'AzureRM.Websites'}
# Get-AzureRmWebApp cmdlet has nested write-progress. We can fix the tab completion issue in PSReadline and PSCore for not nested
# progress. See discussion https://github.com/PowerShell/PowerShell/pull/7023 and issue https://github.com/PowerShell/PowerShell/issues/7022.
# By suppressing the progress for Get-AzureRmWebApp below will close the line gap but it does not affect the command line ProgressPreference setting. 
$ProgressPreference = 'SilentlyContinue'
[SHiPSProvider(UseCache=$true)]
class WebApps : SHiPSDirectory
{
    WebApps() : base ($this.GetType())
    {
    }

    WebApps([string]$name): base($name)
    {
    }

    [object[]] GetChildItem()
    {
        # Will be removed when the Azure issue get fixed:
        # Issue:"New-Alias : The alias is not allowed, because an alias with the name 'Swap-AzureRmWebAppSlot' already exists..."
        if(Get-Variable -Name IsCoreCLR -ErrorAction Ignore)
        {
            Import-Module AzureRM.Websites.Netcore
        }

        return @(& "$script:AzureRM_WebApp\Get-AzureRmWebApp" | %{ $_.psobject.typenames.Insert(0, "AzurePSDriveWebApp"); $_ })

    }
 }
