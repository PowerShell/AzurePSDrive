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
    $dependencyInstalled = (Get-Module -Name $script:AzureRM_Profile -ListAvailable)
    if (-not $dependencyInstalled)
    {
        Install-Module -Name $script:AzureRM_Profile -ErrorAction Stop
    }

    $dependencyInstalled = (Get-Module -Name $script:AzureRM_Resources -ListAvailable)
    if (-not $dependencyInstalled)
    {
        Install-Module -Name $script:AzureRM_Resources -ErrorAction Stop
    }

    $dependencyInstalled = (Get-Module -Name $script:AzureRM_Compute -ListAvailable)
    if (-not $dependencyInstalled)
    {
        Install-Module -Name $script:AzureRM_Compute -ErrorAction Stop
    }

    $dependencyInstalled = (Get-Module -Name $script:AzureRM_Network -ListAvailable)
    if (-not $dependencyInstalled)
    {
        Install-Module -Name $script:AzureRM_Network -ErrorAction Stop
    }

    $dependencyInstalled = (Get-Module -Name $script:AzureRM_Storage -ListAvailable)
    if (-not $dependencyInstalled)
    {
        Install-Module -Name $script:AzureRM_Storage -ErrorAction Stop
    }

    $dependencyInstalled = (Get-Module -Name SHiPS -ListAvailable)
    if (-not $dependencyInstalled)
    {
        Install-Module -Name SHiPS -ErrorAction Stop
    }

    $dependencyInstalled = (Get-Module -Name AzurePSDrive -ListAvailable )
    if (-not $dependencyInstalled)
    {
        Install-Module -Name AzurePSDrive -ErrorAction Stop
    }

    $dependentModules = @($script:AzureRM_Profile, $script:AzureRM_Resources, $script:AzureRM_Compute, $script:AzureRM_Network, $script:AzureRM_Storage, 'SHiPS', 'AzurePSDrive')

    foreach($dependentModule in $dependentModules)
    {
        Import-Module -Name $dependentModule -ErrorAction Stop
    }

    & $script:AzureRM_Profile\Disable-AzureRmDataCollection
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
