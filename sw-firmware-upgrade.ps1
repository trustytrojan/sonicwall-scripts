# Author: trustytrojan

# The following script will create an SSH session with
# the SonicWall information you provide, give it the path
# to the firmware file to download from the SSH server you
# specify, and tell it to reboot once it has downloaded
# the firmware.

# This script MUST be in the same directory as the
# sw-ssh-module.psm1 module file.

# Example command line to execute script cleanly:
# .\sw-firmware-upgrade.ps1 -sw_ip 1.2.3.4 -sw_credential (Get-Credential) -fw_ip 5.6.7.8 -fw_credential (Get-Credential)

param(
  [string]$sw_ip = $(Read-Host "SonicWall IP"),
  [pscredential]$sw_credential = $(Get-Credential -Message "Enter SonicWall credentials"),
  [string]$fw_ip = $(Read-Host "Firmware server IP"),
  [pscredential]$fw_credential = $(Get-Credential -Message "Enter firmware server credentials"),
  [string]$fw_path = $(Read-Host "Path to .sig file on firmware server")
)

Import-Module .\sw-ssh-module.psm1 -DisableNameChecking

Connect-SonicWall $sw_ip $sw_credential

$config_prompt = "config($global:fw_name)#"

Send-Line "config" -expect $config_prompt
Send-Line "import firmware scp scp://$($fw_credential.UserName)@$fw_ip/$fw_path" -expect "(yes/no)"
Send-Line "yes" -expect "$($fw_credential.UserName)'s password:"
Write-Host:Info "The SonicWall will now download the firmware. This may take a minute or two."
Send-Line $fw_credential.GetNetworkCredential().Password -expect [regex]"Fetching (.+).sig"
$global:stream.Expect("% Activate Uploaded Firmware")
$global:stream.Expect($config_prompt)
Send-Line "boot uploaded" -expect "(yes/cancel)"
$global:stream.WriteLine("yes")

Exit-Script "Script finished." -success
