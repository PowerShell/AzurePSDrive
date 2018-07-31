$PSScriptRoot = $MyInvocation.MyCommand.Path

$script:AzureRM_Profile = if($IsCoreCLR){'AzureRM.Profile.NetCore'}else{'AzureRM.Profile'}
$script:AzureRM_Resources = if($IsCoreCLR){'AzureRM.Resources.Netcore'}else{'AzureRM.Resources'}
$script:AzureRM_Compute = if($IsCoreCLR){'AzureRM.Compute.NetCore'}else{'AzureRM.Compute'}
$script:AzureRM_Network = if($IsCoreCLR){'AzureRM.Network.NetCore'}else{'AzureRM.Network'}
$script:AzureRM_Storage = if($IsCoreCLR){'AzureRM.Storage.NetCore'}else{'AzureRM.Storage'}

function Invoke-AzurePSDriveTests([string]$subscriptionName = 'AutomationTeam')
{
    $testResultsFile = Microsoft.PowerShell.Management\Join-Path -Path $PSScriptRoot -ChildPath 'AzurePSDrive.TestResults.xml'

    Write-Host -ForegroundColor Green "Invoking Pester tests"
    # https://www.sapien.com/blog/2016/06/17/how-to-pass-parameters-to-a-pester-test-script/
    Invoke-Pester -Script @{Path = $PSScriptRoot; Parameters = @{subscriptionName = $subscriptionName}} -OutputFormat NUnitXml -OutputFile $testResultsFile

    $testResults += [xml](Get-Content -Raw -Path $testResultsFile)
    $failedTestCount = 0
    $testResults | ForEach-Object { $failedTestCount += ([int]$_.'test-results'.failures); $total += ([int]$_.'test-results'.total) }
   
    if ($failedTestCount -or $total -eq 0)
    {
        throw "$failedTestCount tests failed"
    }
}

function Publish-AzurePSDriveTestResults
{
    param($appVeyorID)

    $testResultsFile = Microsoft.PowerShell.Management\Join-Path -Path $PSScriptRoot -ChildPath 'AzurePSDrive.TestResults.xml'
    Get-ChildItem -Path $testResultsFile | ForEach-Object {
            (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$appVeyorID", "$($_.FullName)")
    }
}

# Ensure all Test dependencies are installed on the machine
function Initialize-TestEnvironment
{
    if ($IsCoreCLR)
    {
        Initialize-TestEnvironmentPSCore
    }
    else
    {
        $dependencyInstalled = (Get-Module -ListAvailable $script:AzureRM_Resources | ForEach-Object Version) -ge [version]"4.2"
        if (-not $dependencyInstalled)
        {
            Save-Module -Name $script:AzureRM_Resources -MinimumVersion 4.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        $dependencyInstalled = (Get-Module -ListAvailable $script:AzureRM_Profile | ForEach-Object Version) -ge [version]"3.2"
        if (-not $dependencyInstalled)
        {
            Save-Module -Name $script:AzureRM_Profile -MinimumVersion 3.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        $dependencyInstalled = (Get-Module -ListAvailable $script:AzureRM_Compute | ForEach-Object Version) -ge [version]"3.2"
        if (-not $dependencyInstalled)
        {
            Save-Module -Name $script:AzureRM_Compute -MinimumVersion 3.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        $dependencyInstalled = (Get-Module -ListAvailable $script:AzureRM_Network | ForEach-Object Version) -ge [version]"4.2"
        if (-not $dependencyInstalled)
        {
            Save-Module -Name $script:AzureRM_Network -MinimumVersion 4.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        $dependencyInstalled = (Get-Module -ListAvailable $script:AzureRM_Storage | ForEach-Object Version) -ge [version]"3.2"
        if (-not $dependencyInstalled)
        {
            Save-Module -Name $script:AzureRM_Storage -MinimumVersion 3.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        $SHiPSInstalled = Get-Module -ListAvailable -Name SHiPS 
        if (-not $SHiPSInstalled)
        {
            Save-Module -Name SHiPS -Force -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }
    
        $AzurePSDriveInstalled = Get-Module -ListAvailable -Name AzurePSDrive 
        if (-not $AzurePSDriveInstalled)
        {
            Save-Module -Name AzurePSDrive -Force -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        Import-Module -Name $script:AzureRM_Resources -Force -Verbose
        Import-Module -Name $script:AzureRM_Profile -Force -Verbose
        Import-Module -Name $script:AzureRM_Compute -Force -Verbose
        Import-Module -Name $script:AzureRM_Network -Force -Verbose
        Import-Module -Name $script:AzureRM_Storage -Force -Verbose    
    }

    Import-Module -Name SHiPS -Force -Verbose
    & $script:AzureRM_Profile\Disable-AzureRmDataCollection
}

# Ensure all Test dependencies are installed when using PowerShell Core based environment
function Initialize-TestEnvironmentPSCore
{
    Install-Module -Name $script:AzureRM_Resources -Force -Verbose
    Install-Module -Name $script:AzureRM_Profile -Force -Verbose
    Install-Module -Name $script:AzureRM_Compute -Force -Verbose
    Install-Module -Name $script:AzureRM_Network -Force -Verbose
    Install-Module -Name $script:AzureRM_Storage -Force -Verbose    
}


# Login to AzureRM using Service Principal
function Login-AzureRM
{
    # These values are supplied from the environment, such as using Appveyor encryption
    # https://www.appveyor.com/docs/build-configuration/#secure-variables

    $azureAdAppId = $env:azureADAppId
    $password = $env:azurePassword
    $tenantId = $env:azureTenantId

    $secureString = ConvertTo-SecureString -String $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($azureAdAppId, $secureString)

    & $script:AzureRM_Profile\Login-AzureRmAccount -ServicePrincipal -Credential $cred -TenantId $tenantId -Verbose -ErrorAction Stop
}
