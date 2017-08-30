using namespace Microsoft.PowerShell.SHiPS

$script:AzureRM_WebApp = if($IsCoreCLR){'AzureRM.Websites.Netcore'}else{'AzureRM.Websites'}

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

        return @(& "$script:AzureRM_WebApp\Get-AzureRmWebApp" | %{ $_.psobject.typenames.Insert(0, "SHiPS.AzureRMWebApp"); $_ })

    }
 }
