using namespace Microsoft.PowerShell.SHiPS


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
        return @(AzureRM.Compute\Get-AzureRmVM -Status | %{ $_.psobject.typenames.Insert(0, "SHiPS.AzureRmVM"); $_ })
    }
 }

