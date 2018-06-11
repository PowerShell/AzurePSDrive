using namespace Microsoft.PowerShell.SHiPS

$script:Azure_Storage = if($IsCoreCLR){'Azure.Storage.NetCore'}else{'Azure.Storage'}
$script:AzureRM_Storage = if($IsCoreCLR){'AzureRM.Storage.NetCore'}else{'AzureRM.Storage'}


[SHiPSProvider(UseCache=$true)]
class StorageAccounts : SHiPSDirectory
{
    StorageAccounts() : base ($this.GetType())
    {
    }

    StorageAccounts([string]$name): base($name)
    {
    }

    [object[]] GetChildItem()
    {
        $obj =  @()                     
        @(& "$script:AzureRM_Storage\Get-AzureRmStorageAccount").Foreach{
             $obj += [StorageAccount]::new($($_.StorageAccountName), $_) 
        }          
        return $obj 
    }
 }

[SHiPSProvider(UseCache=$true)]
class StorageAccount : SHiPSDirectory
{ 
    Hidden [object]$data = $null

    StorageAccount ([string]$name, [object]$data) : base ($name) 
    {
        $this.data = $data
    }

    [object[]] GetChildItem()
    {        
        $obj =  @()
        $ev = $null
        if ($this.data.PrimaryEndpoints.Blob -ne $null)
        {
            try
            {
                $result=& "$script:Azure_Storage\Get-AzureStorageContainer" -Context $this.data.Context -ErrorAction SilentlyContinue -ErrorVariable ev
                if($ev) {
                    Write-Verbose $ev.Exception
                }else{
                    $obj+=[Blobs]::new($this.data, $result);
                }
            }
            catch
            {
                Write-Verbose $_.Exception
            }
        }

        if ($this.data.PrimaryEndpoints.File -ne $null)
        {
            try
            {
                $result=& "$script:Azure_Storage\Get-AzureStorageShare" -Context $this.data.Context -ErrorAction SilentlyContinue -ErrorVariable ev
                if ($ev) {
                    Write-Verbose $ev.Exception
                } else {
                    $obj+=[Files]::new($this.data, $result)
                }
            }
            catch
            {
                Write-Verbose $_.Exception
            }
        }

        if ($this.data.PrimaryEndpoints.Table -ne $null)
        {
            try
            {
                $result=& "$script:Azure_Storage\Get-AzureStorageTable" -Context $this.data.Context  -ErrorAction SilentlyContinue -ErrorVariable ev
                if ($ev){
                    Write-Verbose $ev.Exception 
                } else {
                    $obj+=[Tables]::new($this.data, $result);
                }
            }
            catch
            {
                Write-Verbose $_.Exception
            }
        }

        if ($this.data.PrimaryEndpoints.Queue -ne $null)
        {
            try {
                $result=& "$script:Azure_Storage\Get-AzureStorageQueue" -Context $this.data.Context -ErrorAction SilentlyContinue -ErrorVariable ev
                if ($ev) {
                    Write-Verbose $ev.Exception
                } else {
                    $obj+=[Queues]::new($this.data, $result);
                }
            }
            catch
            {
                Write-Verbose $_.Exception
            }
        }

        return $obj;
    }
}

[SHiPSProvider(UseCache=$true)]
class Blobs : SHiPSDirectory
{
    Hidden [object]$data = $null
    Hidden [object]$result = $null

    Blobs ([object]$data, [object]$result) : base ($this.GetType()) 
    {
        $this.data = $data
        $this.result = $result
    }

    [object[]] GetChildItem()
    {     
        if(-not $this.result)
        {
            Write-Debug "AzurePSDrive: No Blobs."
            return $null
        }

        $obj =  @()
        $this.result | ForEach-Object{     
            $obj+= [Blob]::new($_.Name, $_);                  
        }         
        return $obj     
    }
}

[SHiPSProvider(UseCache=$true)]
class Files : SHiPSDirectory
{
    Hidden [object]$data = $null
    Hidden [object]$result = $null

    Files ([object]$data, [object]$result) : base ($this.GetType()) 
    {
        $this.data = $data
        $this.result = $result        
    }

    [object[]] GetChildItem()
    {      
        if(-not $this.result)
        {
            Write-Debug "AzurePSDrive: No Files found."
            return $null
        }

        <# ConnectionString from cmdlet returns something like below:
            BlobEndpoint=https://<accountname>.blob.core.windows.net/;QueueEndpoint=https://<accountname>.queue.core.windows.net/;
            TableEndpoint=https://<accountname>.table.core.windows.net/;FileEndpoint=https://<accountname>.file.core.windows.net/;AccountName=<accountname>;AccountKey=<token>
        #>
        # Parse the orginal connection string, extract FileEndpoint, and make it net use-able.
        $conectstring = $this.data.Context.ConnectionString -split ';'
        $accountInfo=$conectstring | Where-Object { $_ -match 'AccountName' -or $_ -match 'AccountKey'}
        $fileEndPoint = $conectstring  | Where-Object {$_ -match 'FileEndpoint'}
        $fileshare = $fileEndPoint

        if($fileEndPoint) {
            $index = $fileEndPoint.IndexOf('//')
            if ($index -gt 0) {
                $temp = $fileEndPoint.Substring($index)
                if($temp) {
                    $fileshare = $temp.Replace('/', '\') 
                }   
            }
        }

        return  $this.result | ForEach-Object {           
             [FileShare]::new($_.Name, $this.data.Context, "$fileshare$($_.Name);$($accountInfo)");
            }
    }
}

[SHiPSProvider(UseCache=$true)]
class Tables : SHiPSDirectory
{
    Hidden [object]$data = $null
    Hidden [object]$result = $null

    Tables ([object]$data, [object]$result) : base ($this.GetType()) 
    {
        $this.data = $data
        $this.result = $result        
    }

    [object[]] GetChildItem()
    {     
        return @($this.result | Sort-Object Name)    
    }
}

[SHiPSProvider(UseCache=$true)]
class Queues : SHiPSDirectory
{
    Hidden [object]$data = $null
    Hidden [object]$result = $null

    Queues ([object]$data, [object]$result) : base ($this.GetType()) 
    {
        $this.data = $data
        $this.result = $result                
    }

    [object[]] GetChildItem()
    {     
        return @($this.result | Sort-Object Name)  
    }
}

[SHiPSProvider(UseCache=$true)]
class FileShare : SHiPSDirectory
{ 
    Hidden [string]$shareName = $null
    [object]$Context = $null
    [string]$ConnectionString = $null

    FileShare ([string]$name, [object]$context, [string]$connectionString) : base ($name) 
    {
        $this.shareName = $name        
        $this.context = $context
        $this.ConnectionString = $connectionString
    }

    [object[]] GetChildItem()
    {
        $obj =  @()

        & "$script:Azure_Storage\Get-AzureStorageFile" -Context $this.context -ShareName $this.shareName | ForEach-Object {
            if($_.GetType().Name -eq "CloudFileDirectory") {
                $obj+=[FileFolder]::new($_.Name, $_)
            } else {
                $obj+=[FileShareLeaf]::new($_.Name)
            }
        }

        return $obj
    }
}

class FileShareLeaf : SHiPSLeaf
{
    FileShareLeaf([string]$name): base($name)
    {
    }
}

[SHiPSProvider(UseCache=$true)]
class FileFolder : SHiPSDirectory
{
    Hidden [string]$DirectoryName = $null
    Hidden [object]$CloudFileDirectory = $null

    FileFolder ([string]$name, [object]$cloudFileDirectory) : base ($name) 
    {
        $this.DirectoryName = $name
        $this.CloudFileDirectory = $cloudFileDirectory
    }


    [object[]] GetChildItem()
    { 
        $obj =  @()

        & "$script:Azure_Storage\Get-AzureStorageFile" -Directory $this.CloudFileDirectory | ForEach-Object {
            if($_.GetType().Name -eq "CloudFileDirectory") {
                $obj+=[FileFolder]::new($_.Name, $_)
            } else {
                $obj+=[FileShareLeaf]::new($_.Name)
            }
        }
        return $obj
    }
}

[SHiPSProvider(UseCache=$true)]
class Blob : SHiPSDirectory
{ 
    Hidden [object]$data = $null

    Blob ([string]$name, [object]$data) : base ($name) 
    {
        $this.data = $data
    }

    [object[]] GetChildItem()
    {      
        return @(& "$script:Azure_Storage\Get-AzureStorageBlob" -Context $this.data.Context -Container $this.data.Name | Sort-Object Name)
    }
}

