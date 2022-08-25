# Author: trustytrojan

# The following script will create an SSH session with the
# SonicWall information you provide, and ask it to display
# its version info.

# This script MUST be in the same directory as the
# sw-ssh-module.psm1 module file.

# Example command line to execute script cleanly:
# .\sw_show_version.ps1 -ip 1.2.3.4 -credential (Get-Credential)

param (
  [Parameter(Mandatory)][string]$ip,
  [Parameter(Mandatory)][pscredential]$credential
)

# Import necessary commandlets
Import-Module .\sw-ssh-module.psm1 -DisableNameChecking -Force

# Get an SSH shell stream hooked to the SonicWall
Connect-SonicWall $ip $credential

$prompt = "$($credential.UserName)@$global:fw_name>"

# Start executing commands on the SonicWall
Send-Line "show ver" -expect $prompt

Exit-Script "Script finished." -success
