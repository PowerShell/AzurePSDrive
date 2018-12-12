### Build Status
| Master       |  Development   |
|-----------------------------------------|--------------------------|
|  [![av-image-master][]][av-site-master] |[![av-image-dev][]][av-site-dev]
 

[av-image-dev]: https://ci.appveyor.com/api/projects/status/3cq2g6vq3j1gyp8h/branch/development?svg=true
[av-site-dev]: https://ci.appveyor.com/project/PowerShell/azurepsdrive/branch/development

[av-image-master]:https://ci.appveyor.com/api/projects/status/3cq2g6vq3j1gyp8h?svg=true
[av-site-master]: https://ci.appveyor.com/project/PowerShell/azurepsdrive/branch/master


### Introduction:
AzurePSDrive provider is a [SHiPS](https://github.com/PowerShell/SHiPS) based PowerShell provider to simplify navigation and discovery of [Azure Resource Manager](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview) items. This is based on [Az cmdlets](https://msdn.microsoft.com/en-us/library/mt125356.aspx).
The provider allows to browse Azure resources such as Subscriptions, ResourceGroups, deployments in providers such as Compute, Network, Storage. Deployments such as VirtualMachines, StorageContainers, NetworkInterfaces, SecurityGroups, VNets, WebApps can be seamlessly discovered including useful data about these.

### Usage:
Using this provider is self explanatory. You are encouraged to traverse various resources such as Compute, Network, Storage, WebApps and so on. AzurePSDrive provider shows only Az providers that have deployments such as Virtual machines, Storage Containers.
This version supports only retrieving Resource Manager items.

```
# Authenticate to your Azure account
# Login-AzAccount

# Create a drive for Az
$driveName = 'Az'
Import-Module AzurePSDrive
New-PSDrive -Name $driveName -PSProvider SHiPS -Root AzurePSDrive#Azure

cd $driveName":"
```


```
# Discover all subscriptions associated with the account
PS Az:\> dir

Mode SubscriptionName    SubscriptionId                         TenantId                                 State
---- ----------------    --------------                         -----                                    -----
+    AutomationGroup     xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx     Enabled
+    CloudOps            xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx     Disabled
+    DevOps              xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx     Enabled

# Navigate to a subscription
PS Az:\> cd .\AutomationGroup\

```

``` PowerShell
# Discover the first level directory under a subscription
PS Az:\AutomationGroup> dir
Mode  Name
----  ----
+     AllResources
+     ResourceGroups
+     VirtualMachines
+     StorageAccounts
+     WebApps

# Display all Azure resources under the current subscription
PS Az:\AutomationGroup>cd .\AllResources\
PS Az:\AutomationGroup\AllResources> dir

# Search Azure resources by keyword
PS az:\AutomationGroup\AllResources> dir *foobar*

Name        ResourceType                          ResourceGroupName    Location
----        ------------                          -----------------    --------
foobar1     Microsoft.Compute/virtualMachines     foobarrg             westus
foobar2     Microsoft.Compute/virtualMachines     foobarrg             westu

# Search for all VMs
PS az:\AutomationGroup> cd .\VirtualMachines\
PS az:\AutomationGroup\VirtualMachines>dir

# Search for my VMs starting a letter j*
PS az:\AutomationGroup\VirtualMachines> dir j*
ResourceGroupName   Name    Location    VmSize           OsType    NIC      ProvisioningState  PowerState
-----------------   ----    --------    ------           ------    ---      -----------------  ----------
JRG                 jvm1    eastus      Standard_DS1_v2  Windows   jnic-1   Succeeded          deallocated
JRG                 jvm2    westus      Standard_F1s     Linux      nic-2   Succeeded          running

# Start or Stop a VM
dir jvm2 | Stop-AzVM
PS az:\AutomationGroup\VirtualMachines> dir .\jvm2 | Stop-AzVM

# Search all storage accounts under my subscription
PS az:\AutomationGroup\StorageAccounts> dir
Mode  Name
----  ----
+     myacc
+     myacc2
+     myacc3

# Navigate to a particular storage account
PS az:\AutomationGroup\StorageAccounts> cd .\myacc\
PS az:\AutomationGroup\StorageAccounts\myacc> dir

Mode  Name
----  ----
+     Blobs
+     Files
+     Tables
+     Queues

# Navigate to Azure storage file share
PS az:\AutomationGroup\StorageAccounts\myacc> cd .\Files\
PS az:\AutomationGroup\StorageAccounts\myacc\Files> dir

Name     ConnectionString
----     ----------------
share1   \\myacc.file.core.windows.net\share1;AccountName=myacc
         AccountKey=<key omitted here>
share2   \\myacc2.file.core.windows.net\share2;AccountName=myacc2
         AccountKey=<key omitted here>

# Mount to Azure file share so that you can add/delete/modify files and directories
net use z: \\myacc.file.core.windows.net\share1  /u:AZURE\myacc <AccountKey>

# Navigate to a directory
PS az:\AutomationGroup\StorageAccounts\myacc\Files> cd .\share1\
PS az:\AutomationGroup\StorageAccounts\myacc\Files\share1> dir

Mode  Name
----  ----
+     .cloudconsole
.     .hello.ps1
```

```
# Discover ResourceGroups in the Subscription
PS az:\AutomationGroup> cd .\ResourceGroups\
PS az:\AutomationGroup\ResourceGroups> dir

Mode ResourceGroupName                     Location       ProvisioningState Tags
---- -----------------                     --------       ----------------- ----
+    azexpress                             southcentralus Succeeded
+    azexpress-posh2                       southcentralus Succeeded
+    ops-WestUS                            westus         Succeeded

PS Az:\AutomationGroup\ResourceGroups> cd .\azexpress\

# Discover Providers that have deployments
PS Az:\AutomationGroup\ResourceGroups\azexpress> dir

Mode ProviderName
---- ------------
+    Microsoft.ClassicStorage
+    Microsoft.Compute
+    Microsoft.Network
+    Microsoft.Storage
+    Microsoft.Web

```

```
# Navigate to your own VMs
PS Az:\AutomationGroup\ResourceGroups\azexpress\Microsoft.Compute\virtualMachines> dir

VMName         Location ProvisioningState VMSize          OS            SKU                             OSVersion AdminUserName NetworkInterfaceName
------         -------- ----------------- ------          --            ---                             --------- ------------- --------------------
azexpress-ctr-host westus   Succeeded         Standard_DS2_v2 WindowsServer 2016-Datacenter-with-Containers latest    localadmin    azexpress-ctr

# Discover NetworkInterfaces
PS Az:\AutomationGroup\ResourceGroups\azexpress\Microsoft.Network\networkInterfaces> dir

NetworkInterfaceName Location ProvisioningState VirtualMachineName PublicIpAddressName   NetworkSecurityGroupName IsPrimary
-------------------- -------- ----------------- ------------------ -------------------   ------------------------ ---------
azexpress-ctr        westus   Succeeded         azexpress-ctr-host azexpress-ctr-host-ip azexpress-ctr-host-nsg       True

```

```
# Get WebApps information
PS Az:\AutomationGroup\ResourceGroups\azexpress\Microsoft.Web\sites> dir


SiteName                       Location   State      OutboundIpAddresses  EnabledHostInfo                                                 WebSpace
--------                       --------   -----      -------------------  ---------------                                                 --------
azexpressSite                   West US    Stopped    42.139.137.127       azexpressSite.azurewebsites.net* SSl=Disabled                  2015-WestUSwebspace
                                                      40.11.139.85         azexpressSite.scm.azurewebsites.net SSl=Disabled

azexpressSite-powershell        West US    Running    42.112.85.127        azexpressSite-powershell.azurewebsites.net* SSl=Disabled       2015-WestUSwebspace
                                                      42.139.139.85        azexpressSite-powershell.scm.azurewebsites.net SSl=Disabled




```


```
# Get ServerFarms info
PS Az:\AutomationGroup\ResourceGroups\azexpress\Microsoft.Web\serverFarms> dir

ServerFarmName  Location ProvisioningState NumberOfWorkers NumberOfSites WebSpace
--------------  -------- ----------------- --------------- ------------- --------
2015Plan        West US  Succeeded         1               5             2015-WestUSwebspace



```

### Dependencies:
[Az.Accounts, Az.Resources, Az.Compute, Az.Storage, Az.Websites](https://www.powershellgallery.com/packages/Az) and [SHiPS](https://github.com/PowerShell/SHiPS) PowerShell modules are required.

### Caching:
Top level objects such as Subscriptions, Resource Groups, Resource Providers are cached to improve performance.
Use ```dir -Force``` to refresh from Azure service. However, leaf level objects such as Virtual Machines, Network Interfaces, WebSites are not cached, since these items can have a smaller life cycle.

### Server side filtering using Az ODataQuery
Supports performing server side filtering using ```$filter``` ODataQuery semantics. Simply use ```dir -Filter``` option when retrieving items.

### Supported Az Provider Types in format.ps1xml:

| ProviderType | Name  | FullType |
| -----------  | --------------| --------------|
| Microsoft.Compute  | virtualMachines  | Microsoft.Compute.virtualMachines  |
| Microsoft.Compute  | virtualMachines/extensions  | Microsoft.Compute.virtualMachines.extensions  |
| Microsoft.Compute  | availabilitySets  | Microsoft.Compute.availabilitySets  |
| Microsoft.Network  | networkInterfaces | Microsoft.Network.networkInterfaces  |
| Microsoft.Network  | publicIPAddresses | Microsoft.Network.publicIPAddresses  |
| Microsoft.Network  | virtualNetworks | Microsoft.Network.virtualNetworks  |
| Microsoft.Network  | networkSecurityGroups | Microsoft.Network.networkSecurityGroups  |
| Microsoft.Network  | routeTables | Microsoft.Network.routeTables  |
| Microsoft.Storage | storageAccounts | Microsoft.Storage.storageAccounts  |
| Microsoft.ClassicStorage | storageAccounts | Microsoft.ClassicStorage.storageAccounts  |
| Microsoft.Web | sites | Microsoft.Web.sites  |
| Microsoft.Web | serverfarms | Microsoft.Web.serverfarms  |
