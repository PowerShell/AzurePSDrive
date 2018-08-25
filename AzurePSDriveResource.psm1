using namespace Microsoft.PowerShell.SHiPS

$script:AzureRM_Resources = if($IsCoreCLR){'Az.Resources'}else{'AzureRM.Resources'}

if($IsCoreCLR)
{
    Enable-AzureRmAlias
}

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
        return @(Get-AzureRmResource | %{ $_.psobject.typenames.Insert(0, "AzurePSDriveResourceType"); $_ })
    }
 }