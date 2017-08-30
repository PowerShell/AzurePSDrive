using namespace Microsoft.PowerShell.SHiPS

$script:AzureRM_Resources = if($IsCoreCLR){'AzureRM.Resources.Netcore'}else{'AzureRM.Resources'}


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
        return @(& "$script:AzureRM_Resources\Get-AzureRmResource" | %{ $_.psobject.typenames.Insert(0, "SHiPS.AzureRMResourceType"); $_ })
    }
 }