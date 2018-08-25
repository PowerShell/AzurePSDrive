using namespace Microsoft.PowerShell.SHiPS

$script:AzureRM_Compute = if($IsCoreCLR){'Az.Compute'}else{'AzureRM.Compute'}

if($IsCoreCLR)
{
    Enable-AzureRmAlias
}

[SHiPSProvider(UseCache=$true)]
class VirtualMachines : SHiPSDirectory
{
    VirtualMachines() : base ($this.GetType())
    {
    }

    VirtualMachines([string]$name): base($name)
    {
    }

    [object[]] GetChildItem()
    {
        return @(Get-AzureRmVM -Status | %{ $_.psobject.typenames.Insert(0, "AzurePSDriveVM"); $_ })
    }
 }

