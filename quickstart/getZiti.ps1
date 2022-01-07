<#
.SYNOPSIS
Gets the latest ziti from github and adds it to your path

.DESCRIPTION
This script will:
    - detect the lastest version of ziti
    - download the latest versio of ziti into the folder of your choice, defaulting to $env:userprofile.ziti\bin)
    - unzip the downloaded file
    - optionally add the extracted path to your path if executed with a "dot" as in: . getLatestZiti.ps1

.INPUTS
None.

.OUTPUTS
None. If "dot sourced" this script will add the resultant directory to your path

.EXAMPLE
PS> . .\getLatestZiti.ps1
#>
$latestFromGitHub=(irm https://api.github.com/repos/openziti/ziti/releases/latest)
$version=($latestFromGitHub.tag_name)
$zitidl=($latestFromGitHub).assets | where {$_.browser_download_url -Match "ziti-windows.*zip"}
$downloadUrl=($zitidl.browser_download_url)
$name=$zitidl.name
$defaultFolder="$env:USERPROFILE\.ziti\bin"
$toDir=$(Read-Host "Where folder should be used for ziti? [default: ${defaultfolder}]")
if($toDir.Trim() -eq "") {
    $toDir=("${defaultfolder}")
}

$zipFile="${toDir}\${name}"
if($(Test-Path -Path $zipFile -PathType Leaf)) {
    Write-Output "The file has already been downloading. No need to download again"
} else {
    mkdir "${toDir}" -ErrorAction SilentlyContinue
    Write-Output "Downloading file "
    Write-Output "    from: ${downloadUrl} "
    Write-Output "      to: ${zipFile}"
    iwr ${downloadUrl} -OutFile "$zipFile"
}

Expand-Archive -Path $zipFile -DestinationPath "${toDir}\${version}" -ErrorAction SilentlyContinue

if(! $env:Path.Contains("${toDir}\${version}\ziti\")){
    $env:Path+=";${toDir}\${version}\ziti\"
}
