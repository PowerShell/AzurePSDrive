using namespace Microsoft.PowerShell.SHiPS

$script:Az_Resources = 'Az.Resources'


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
        return @(& "$script:Az_Resources\Get-AzResource" | %{ $_.psobject.typenames.Insert(0, "AzurePSDriveResourceType"); $_ })
    }
 }