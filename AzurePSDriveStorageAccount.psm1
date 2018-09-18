﻿using namespace Microsoft.PowerShell.SHiPS


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
        @(Az.Storage\Get-AzStorageAccount).Foreach{
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
                $result=Az.Storage\Get-AzStorageContainer -Context $this.data.Context -ErrorAction SilentlyContinue -ErrorVariable ev
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
                $result=Az.Storage\Get-AzStorageShare -Context $this.data.Context -ErrorAction SilentlyContinue -ErrorVariable ev
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
                $result=Az.Storage\Get-AzStorageTable -Context $this.data.Context  -ErrorAction SilentlyContinue -ErrorVariable ev
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
                $result=Az.Storage\Get-AzStorageQueue -Context $this.data.Context -ErrorAction SilentlyContinue -ErrorVariable ev
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

        Az.Storage\Get-AzStorageFile -Context $this.context -ShareName $this.shareName | ForEach-Object {
            if($_.GetType().Name -eq "CloudFileDirectory") {
                $obj+=[FileFolder]::new($_.Name, $this.shareName, $_.Name, $this.context, $_)
            } else {
                $obj+=[FileShareLeaf]::new($_.Name, $this.shareName, $null, $this.context)
            }
        }

        return $obj
    }

    [object] SetContent([string]$content, [string]$path)
    {
        $leafName = SetContentUtility -Content $content -Path $path -ShareName $this.shareName -FolderName $null -Context $this.context
        if($leafName)
        {
            # Returning the currently object so that the SHiPS can cache it
            return [FileShareLeaf]::new($leafName, $this.shareName, $null, $this.context)
        }
        return $null
    }
}

class FileShareLeaf : SHiPSLeaf
{
    Hidden [string]$fileName = $null
    Hidden [string]$shareName = $null
    Hidden [object]$context = $null
    Hidden [string]$folderName = $null
    Hidden [string]$filePath = $null

    FileShareLeaf([string]$name, [string]$shareName, [string]$folderName, [object]$context): base($name)
    {
        $this.context = $context
        $this.fileName = $name
        $this.shareName = $shareName
        $this.folderName = $folderName
        if($this.folderName)
        {
            $this.filePath = join-path $this.folderName $this.fileName
        }
        else
        {
            $this.filePath = $this.fileName
        }
    }

    [object] GetContent()
    {
        $tmpfile = $null
        try {
            $tmpfile = [System.IO.Path]::GetTempFileName()

            Write-Verbose "Calling Get-AzStorageFilecontent -Path $($this.filePath) -ShareName $($this.shareName) -Destination $tmpfile ..." -Verbose

            $ev = $null
            Az.Storage\Get-AzStorageFilecontent -Path $this.filePath -Context $this.context -ShareName $this.shareName -Destination $tmpfile -Force -ErrorVariable ev

            if(-not $ev)
            {
                $bp = $this.ProviderContext.BoundParameters

                if($bp.ContainsKey('Path'))
                {
                    $null = $bp.Remove('Path')
                }

                return Microsoft.PowerShell.Management\Get-Content -Path $tmpfile @bp
            }
            return $null
        }
        finally {
            if(Test-Path $tmpfile) {
                Microsoft.PowerShell.Management\Remove-Item -Path $tmpfile -Force -ErrorAction SilentlyContinue
            }
        }
    }

    [object] SetContent([string]$content, [string]$path)
    {
        $leafName = SetContentUtility -Content $content -Path $path -ShareName $this.shareName -FolderName $this.folderName  -Context $this.context

        if($leafName)
        {
            # Returning the currently object so that the SHiPS can cache it
            return $this
        }

        return $null
    }
}

[SHiPSProvider(UseCache=$true)]
class FileFolder : SHiPSDirectory
{
    Hidden [string]$folderName = $null
    Hidden [object]$cloudFileDirectory = $null

    Hidden [object]$context = $null
    Hidden [string]$shareName = $null

    FileFolder ([string]$name, [string]$shareName, [string]$dir, [object]$context, [object]$cloudFileDirectory) : base ($name)
    {
        $this.folderName = $dir
        $this.cloudFileDirectory = $cloudFileDirectory
        $this.context = $context
        $this.shareName = $shareName
    }

    [object[]] GetChildItem()
    { 
        $obj =  @()

        Az.Storage\Get-AzStorageFile -Directory $this.cloudFileDirectory | ForEach-Object {
            if($_.GetType().Name -eq "CloudFileDirectory") {
                if($this.folderName)
                {
                    $dir = Microsoft.PowerShell.Management\Join-path -Path $this.folderName -ChildPath $_.Name
                }
                else {
                    $dir=$_.Name
                }
                $obj+=[FileFolder]::new($_.Name, $this.shareName, $dir, $this.context, $_)

            } else {
                $obj+=[FileShareLeaf]::new($_.Name, $this.shareName, $this.folderName, $this.context )
            }
        }
        return $obj
    }

    [object] SetContent([string]$content, [string]$path)
    {
        $leafName = SetContentUtility -Content $content -Path $path -ShareName $this.shareName -FolderName $this.folderName -Context $this.context
        # Returning the currently object so that the SHiPS can cache it
        if($leafName)
        {
            return [FileShareLeaf]::new($leafName, $this.shareName, $this.folderName, $this.context)
        }

        return $null
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
        return @(Az.Storage\Get-AzStorageBlob -Context $this.data.Context -Container $this.data.Name | Sort-Object Name)
    }
}


Function SetContentUtility()
{
    param(
        [string]$Content,
        [string]$Path,
        [string]$ShareName,
        [string]$FolderName,
        [object]$Context
    )

    # Save the text content to a local temp file because the Set-AzureStorageFileContent cmdlet takes file only
    $tmpfile = [System.IO.Path]::GetTempFileName()

    try {

        Microsoft.PowerShell.Management\Set-Content -Path $tmpfile -Value $Content

        # $content is the 'Value' passed in from Set-Content
        # $path is the full path. e.g., Azure:\AutomationTeam\StorageAccounts\myaccount\Files\HelloWorld\hello.ps1".
        # Get the file leaf node name
        $newPath = Microsoft.PowerShell.Management\Split-Path $Path -Leaf

        # Get the file share target path
        $destionation=[System.IO.Path]::Combine($FolderName, $newPath)

        Write-Verbose "Calling Set-AzStorageFileContent -ShareName $ShareName -Source $tmpfile -Path $destionation" -Verbose
        $ev = $null
        Az.Storage\Set-AzStorageFileContent -Context $Context -ShareName $ShareName -Source $tmpfile -Path $destionation -Force -ErrorVariable ev

        if($ev) { return $null }
        return $newPath
    }
    finally {
        if($tmpfile) {
            Microsoft.PowerShell.Management\Remove-Item $tmpfile -Force -ErrorAction SilentlyContinue
        }
    }
}
