using namespace Microsoft.PowerShell.SHiPS

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
        return @(AzureRM.Websites\Get-AzureRmWebApp | %{ $_.psobject.typenames.Insert(0, "SHiPS.AzureRMWebApp"); $_ })
    }
 }
