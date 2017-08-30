using namespace Microsoft.PowerShell.SHiPS

$script:AzureRM_Compute = if($IsCoreCLR){'AzureRM.Compute.Netcore'}else{'AzureRM.Compute'}

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
        return @(& "$script:AzureRM_Compute\Get-AzureRmVM" -Status | %{ $_.psobject.typenames.Insert(0, "SHiPS.AzureRmVM"); $_ })
    }
 }

