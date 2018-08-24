using namespace Microsoft.PowerShell.SHiPS

# Get-AzWebApp cmdlet has nested write-progress. We can fix the tab completion issue in PSReadline and PSCore for not nested
# progress. See discussion https://github.com/PowerShell/PowerShell/pull/7023 and issue https://github.com/PowerShell/PowerShell/issues/7022.
# By suppressing the progress for Get-AzWebApp below will close the line gap but it does not affect the command line ProgressPreference setting. 
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
        # Issue:"New-Alias : The alias is not allowed, because an alias with the name 'Swap-AzWebAppSlot' already exists..."
        if(Get-Variable -Name IsCoreCLR -ErrorAction Ignore)
        {
            Import-Module Az.Websites
        }

        return @(Az.Websites\Get-AzWebApp | %{ $_.psobject.typenames.Insert(0, "AzurePSDriveWebApp"); $_ })

    }
 }
