$PSScriptRoot = $MyInvocation.MyCommand.Path

$script:Az_Profile = 'Az.Accounts'
$script:Az_Resources = 'Az.Resources'
$script:Az_Compute ='Az.Compute'
$script:Az_Network = 'Az.Network'
$script:Az_Storage = 'Az.Storage'

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
        $dependencyInstalled = (Get-Module -ListAvailable $script:Az_Resources | ForEach-Object Version) -ge [version]"0.2"
        if (-not $dependencyInstalled)
        {
            Save-Module -Name $script:Az_Resources -MinimumVersion 0.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        $dependencyInstalled = (Get-Module -ListAvailable $script:Az_Profile | ForEach-Object Version) -ge [version]"0.2"
        if (-not $dependencyInstalled)
        {
            Save-Module -Name $script:Az_Profile -MinimumVersion 0.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        $dependencyInstalled = (Get-Module -ListAvailable $script:Az_Compute | ForEach-Object Version) -ge [version]"0.2"
        if (-not $dependencyInstalled)
        {
            Save-Module -Name $script:Az_Compute -MinimumVersion 0.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        $dependencyInstalled = (Get-Module -ListAvailable $script:Az_Network | ForEach-Object Version) -ge [version]"0.2"
        if (-not $dependencyInstalled)
        {
            Save-Module -Name $script:Az_Network -MinimumVersion 0.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        $dependencyInstalled = (Get-Module -ListAvailable $script:Az_Storage | ForEach-Object Version) -ge [version]"0.2"
        if (-not $dependencyInstalled)
        {
            Save-Module -Name $script:Az_Storage -MinimumVersion 0.2.0 -Force -Verbose -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        $SHiPSInstalled = Get-Module -ListAvailable -Name SHiPS 
        if (-not $SHiPSInstalled)
        {
            Save-Module -Name SHiPS -Force -path "$($env:ProgramFiles)\WindowsPowerShell\Modules"
        }

        Import-Module -Name $script:Az_Resources -Force -Verbose
        Import-Module -Name $script:Az_Profile -Force -Verbose
        Import-Module -Name $script:Az_Compute -Force -Verbose
        Import-Module -Name $script:Az_Network -Force -Verbose
        Import-Module -Name $script:Az_Storage -Force -Verbose    
    }

    Import-Module -Name SHiPS -Force -Verbose
    & $script:Az_Profile\Disable-AzDataCollection
}

# Ensure all Test dependencies are installed when using PowerShell Core based environment
function Initialize-TestEnvironmentPSCore
{
    Install-Module -Name $script:Az_Resources -Force -Verbose
    Install-Module -Name $script:Az_Profile -Force -Verbose
    Install-Module -Name $script:Az_Compute -Force -Verbose
    Install-Module -Name $script:Az_Network -Force -Verbose
    Install-Module -Name $script:Az_Storage -Force -Verbose    
}


# Login to Az using Service Principal
function Login-Az
{
    # These values are supplied from the environment, such as using Appveyor encryption
    # https://www.appveyor.com/docs/build-configuration/#secure-variables

    $azureAdAppId = $env:azureADAppId
    $password = $env:azurePassword
    $tenantId = $env:azureTenantId

    $secureString = ConvertTo-SecureString -String $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($azureAdAppId, $secureString)

    & $script:Az_Profile\Login-AzAccount -ServicePrincipal -Credential $cred -TenantId $tenantId -Verbose -ErrorAction Stop
}
