using namespace Microsoft.PowerShell.SHiPS

$script:Az_Compute = 'Az.Compute'

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
        return @(& "$script:Az_Compute\Get-AzVM" -Status | %{ $_.psobject.typenames.Insert(0, "AzurePSDriveVM"); $_ })
    }
 }

