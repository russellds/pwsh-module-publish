[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]
    $ModuleName,

    [Parameter(Mandatory)]
    [string]
    $NuGetApiKey,

    [switch]
    $TestGallery
)

Write-Host "ModuleName: $ModuleName"

$modulesPath = Resolve-Path -Path './Modules'

$repositories = Get-PSRepository |
    Select-Object -ExpandProperty Name

Write-Host 'PowerShell Repositories:'

foreach ($repository in $repositories) {
    Write-Host "`t$( $repository )"
}

if ($TestGallery) {
    Write-Host 'Registering PoshTest Gallery...'

    $paramRegisterPSRepository = @{
        Name               = 'PoshTestGallery'
        SourceLocation     = 'https://www.poshtestgallery.com/api/v2/'
        PublishLocation    = 'https://www.poshtestgallery.com/api/v2/package/'
        InstallationPolicy = 'Trusted'
    }

    Register-PSRepository @paramRegisterPSRepository
} elseif ($repositories -notcontains 'PSGallery') {
    Write-Host 'Registering PowerShell Gallery...'

    $paramRegisterPSRepository = @{
        Default = $true
        InstallationPolicy = 'Trusted'
    }

    Register-PSRepository @paramRegisterPSRepository
}

Write-Host 'Updating $env:PSModulePath...'

$env:PSModulePath = '{0};{1}' -f $modulesPath.Path, $env:PSModulePath

Write-Host 'PowerShell Module Paths:'

foreach ($psModulePath in $env:PSModulePath.Split(';')) {
    Write-Host "`t$( $psModulePath )"
}

$importedModule = Import-Module -Name $ModuleName -Force -PassThru

if ($importedModule.PrivateData.PSData.Prerelease) {
    $importedModuleVersion = '{0}-{1}' -f $importedModule.Version.ToString(3), $importedModule.PrivateData.PSData.Prerelease
} else {
    importedModuleVersion = $importedModule.Version.ToString(3)
}

Write-Host "Version of $( $ModuleName ) to be published:"
Write-Host "`t$( $importedModuleVersion )"

$foundModules = Find-Module -Name $ModuleName -Repository $paramRegisterPSRepository.Name -AllowPrerelease -AllVersions

Write-Host "Currently published versions of $( $ModuleName ):"

if ($foundModules) {
    foreach ($foundModule in $foundModules) {
        Write-Host "`t$( $foundModule.Version )"
    }
} else {
    Write-Host "`tNo published versions found."
}

if ($foundModules.Version -notcontains $importedModuleVersion) {
    Write-Host "`nPublishing $( $ModuleName ) version $( $importedModuleVersion ) to $( $paramRegisterPSRepository.Name )"

    $paramPublishModule = @{
        Name        = $ModuleName
        Repository  = 'PSGallery'
        NuGetApiKey = $NuGetApiKey
    }

    if ($paramRegisterPSRepository) {
        $paramPublishModule.Repository  = $paramRegisterPSRepository.Name
    }

    Publish-Module @paramPublishModule

    Write-Host "$( $ModuleName ) successfully published to $( $paramPublishModule.Repository )."
} else {
    Write-Host "`nModule $( $ModuleName ) version: $( $importedModuleVersion ) - already published."
}
