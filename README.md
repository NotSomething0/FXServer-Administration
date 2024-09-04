# FXServer Administration
A repository containing a collection of scripts to help manage and maintain Cfx.re platform servers (FXServer)

## FXServer artifact updater (artifact-updater.ps1)

### Prerequisites: 
- PowerShell 7 or higher
- Administrator privileges

### Overview
Automates the process of updating a Cfx.re platform server (FXserver). Validates the artifact version exists and hasn't been revoked, downloads the release binaries from https://runtime.fivem.net/artifacts/ stops any currently running FXServer instances removes the old artifact files and expands the new artifact binary into the specified directory. 


### Parameters: 
Two mandatory parameters and one optional parameter:

- newArtifactVersion: The version of the new artifact you wish to download. This can be a specific version number or "latest" to automatically use the newest version.
- currentArtifactPath: The file system path to the root directory of the current FXServer artifact. This is where the new artifact will be installed.
- keepDownload: Keeps the downloaded binary zip file in the root of your FXServer folder under the 'binaries' folder

### Functions:
- Get-Release:
	- Queries GitHub and the FiveM changelogs API to find download links for the requested FXServer artifact version. It handles both specific version requests and the latest version request.

- Start-ArtifactDownload:
	- Downloads the specified artifact to a subdirectory named binaries within the provided currentArtifactPath. If the artifact is already downloaded, it skips the download step.

- Remove-Artifact:
	- Stops the currently running FXServer instance if it is found running from the specified artifact path. It then deletes the old artifact files except for configurations, scripts, certificates, and the resources, cache, server-data, and binaries directories.

### Script Flow:
- Validation: The script starts by validating the provided newArtifactVersion and currentArtifactPath. It checks if the specified version exists and is supported, and verifies that the provided artifact path points to a valid FXServer installation.
- Artifact Information Request: It then proceeds to determine the necessary information about the artifact to download. This involves finding a download URL for the specified version.
- Download: The script downloads the new artifact into the binaries subdirectory within the specified current artifact path, unless it's already present.
- Artifact Removal: Before proceeding with the update, it stops any running FXServer instances found in the specified path and removes old artifact files, preserving configurations and other important files.
- Installation: The script then extracts the downloaded artifact into the specified path, effectively updating the FXServer installation.

### Execution Example:

```powershell
.\artifact-updater.ps1 -newArtifactVersion "latest" -currentArtifactPath "C:\FXServer"
```

This command updates the FXServer artifact to the latest version, installing it in C:\FXServer.

### Error Handling:
The script includes basic error handling, such as validation of input parameters and graceful exits in case of errors during the web requests or file operations. Ensure that you have the necessary permissions and that the specified paths are correct before running the script.