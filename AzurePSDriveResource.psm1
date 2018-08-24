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
        return @(Az.Resources\Get-AzResource | %{ $_.psobject.typenames.Insert(0, "AzurePSDriveResourceType"); $_ })
    }
 }