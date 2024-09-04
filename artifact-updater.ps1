#Requires -RunAsAdministrator

param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]
  $newArtifactVersion,

  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]
  $currentArtifactPath,

  [Parameter]
  [bool]
  $keepDownload = 1
)

function Get-Release() {
  $release = New-Object -TypeName psobject -ArgumentList @{
    version = $null,
    $download = $null
  }

  # Download links aren't avalible for all version of FXServer at https://changelogs-live.fivem.net so will try to create the link ourself
  if ($newArtifactVersion -ne "latest") {
    Write-Host "Requesting matching reference data from GitHub for tag v1.0.0.$newArtifactVersion"

    $referenceResponse = Invoke-RestMethod "https://api.github.com/repos/citizenfx/fivem/git/matching-refs/tags/v1.0.0.$newArtifactVersion" -Headers @{"accept"="application/vnd.github.v3+json"}

    if (-not $referenceResponse.object.url) {
      Write-Host "Unable to get reference data from GitHub for tag v1.0.0.$newArtifactVersion. Please try again in a few minutes"
      Exit
    }

    Write-Host "Got reference data requesting tag data from GitHub at $($referenceResponse.object.url)"

    $tagResponse = Invoke-RestMethod $referenceResponse.object.url -Headers @{"accept"="application/vnd.github.v3+json"}

    if (-not $tagResponse.object.sha) {
      Write-Host "Unable to get tag data from GitHub at $($referenceResponse.object.url). Please try again in a few minutes"
      Exit
    }

    $release.version = $newArtifactVersion
    $release.download = "https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/$newArtifactVersion-$($tagResponse.object.sha)/server.7z"

    Write-Host "Got tag data for artifact $($release.version) download link is $($release.download)"
  }

  if ($newArtifactVersion -eq 'latest') {
    $changelogResponse = Invoke-RestMethod -uri "https://changelogs-live.fivem.net/api/changelog/versions/win32/server" -StatusCodeVariable statusCode

    if ($statusCode -ne 200) {
      Write-Host 'Unable to get latest download from https://changelogs-live.fivem.net, please try again in a few minutes.'
      Exit
    }

    $release.version = $changelogResponse.latest
    $release.download = $changelogResponse.latest_download

    Write-Host "Latest release version is $($release.version) download link is $($release.download)"
  }

  return $release
}

function Start-ArtifactDownload($release) {
  $artifactStoragePath = Join-Path -Path $currentArtifactPath -ChildPath "binaries"

  if (-not (Test-Path -Path $artifactStoragePath)) {
    $result = New-Item -ItemType "directory" -Path $artifactStoragePath -Confirm

    if (-not $result) {
      Write-Host "Artifact storage path at $artifactStoragePath could not be created, run the script again and select 'Yes' when prompted."
      Exit
    }
  }

  $artifactFilePath = Join-Path -Path $artifactStoragePath -ChildPath "server-$($release.version).7z"

  if (-not (Test-Path -Path $artifactFilePath)) {
    Invoke-RestMethod $release.download -OutFile $artifactFilePath -StatusCodeVariable statusCode

    if ($statusCode -ne 200)
    {
      Write-Host "Failed to downloaded artifact $($release.version) from $($release.download). It may not be avalible yet or was revoked. Status code $statusCode"
      Exit
    }
  }

  return $artifactFilePath
}

function Remove-Artifact() {
  $FXServerProcess = Get-Process -Name FXServer -ErrorAction SilentlyContinue

  if ($FXServerProcess) {
    if ($FXServerProcess.MainModule.FileName -like "$currentArtifactPath*") {
      Write-Host "Terminating running instance of FXServer with process IDs: $($FXServerProcess.Id)"
      Stop-Process -ID $FXServerProcess.Id -Force
      # Stop-Process doesn't finish in time leading to "directory is not empty" errors when trying to delete some old artifact files so will give it a bit of extra time
      Start-Sleep 1
    }
  }

  $preservedPatterns = @("*.cfg","*.cmd","*.bat","*.zip","*.crt", "*.key", "resources","cache", "server-data", "binaries")

  Get-ChildItem $currentArtifactPath -Exclude $preservedPatterns -Force | ForEach-Object {
    Write-Host "Deleting:" $_.FullName
    Remove-Item $_.FullName -Recurse -Force
  }
}

Write-Host "Validating artifact version..."

if ($newArtifactVersion -ne "latest") {
  $numericArtifactVersion = $null

  if (-not [Int32]::TryParse($newArtifactVersion, [ref]$numericArtifactVersion)) {
    Write-Host "Supplied artifact version '$newArtifactVersion' could not be parsed to a number. Please provide a valid numeric version greater than"
  }

  $changelogResponse = Invoke-RestMethod "https://changelogs-live.fivem.net/api/changelog/versions/win32/server"
  
  $artifactSupportEntry = $changelogResponse.support_policy.$newArtifactVersion

  if (-not $artifactSupportEntry) {
    Write-Host "Artifact $newArtifactVersion is not in the support policy, specify a later release version."
    Exit
  }

  $artifactSupportDate = Get-Date -Date "$($changelogResponse.support_policy.$newArtifactVersion)"

  if ($artifactSupportDate -lt (Get-Date)) {
    Write-Host "Artifact $newArtifactVersion is no longer supported, specifiy a later release version."
    Exit
  }
}

Write-Host "Validated artifact version"
Write-Host "Validating artifact path..."

if (-not (Test-Path -Path $currentArtifactPath -PathType Container)) {
  throw "Supplied artifact path $currentArtifactPath is invalid. Please provide the root path to your current FXServer artifact folder."
}

# Make sure the supplied path is the root of an FXServer folder by checking for the server tls certificate
$serverTLSCertificatePath = Join-Path -Path $currentArtifactPath -ChildPath "server-tls.crt"

if (-not (Test-Path -Path $serverTLSCertificatePath -PathType Leaf)) {
  throw "Supplied artifact path $currentArtifactPath is invalid, could not find 'server-tls.crt'. Please provide the root path to your current FXServer artifact folder."
}

Write-Host "Validated artifact path"
Write-Host "Requesting artifact information"

$release = Get-Release
$artifactFilePath = Start-ArtifactDownload($release)

Remove-Artifact

Expand-Archive $artifactFilePath -DestinationPath $currentArtifactPath -Force

Write-Host "Successfully updated FXServer to artifact $($release.version)"