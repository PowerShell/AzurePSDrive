using namespace Microsoft.PowerShell.SHiPS


[SHiPSProvider(UseCache=$true)]
class AllResources : SHiPSDirectory
{
    AllResources() : base($this.GetType())
    {
    }

    AllResources([string]$name): base($name)
    {
    }

    [object[]] GetChildItem()
    {
        return @(AzureRM.Resources\Get-AzureRmResource | %{ $_.psobject.typenames.Insert(0, "SHiPS.AzureRMResourceType"); $_ })
    }
 }