# Module file for shared code between SonicWall scripts.

# This module file MUST be in the same directory as the
# script you are trying to run.

# Install and import Posh-SSH.
# https://github.com/darkoperator/Posh-SSH
Install-Module "Posh-SSH" -Force
Import-Module "Posh-SSH"

# Wrapper functions for Write-Host
function Write-Host:Info {
  param([Parameter(Mandatory)][string]$message)
  $message | Write-Host -ForegroundColor Blue
}
function Write-Host:Error {
  param([Parameter(Mandatory)][string]$message)
  $message | Write-Host -ForegroundColor Red
}
function Write-Host:Success {
  param([Parameter(Mandatory)][string]$message)
  $message | Write-Host -ForegroundColor Green
}

# Write a message, close all SSH sessions, and exit the script.
function Exit-Script {
  param (
    [string]$message,
    [Parameter()][switch]$success,
    [Parameter()][switch]$err
  )
  if ($success.IsPresent -and $err.IsPresent) { throw "" }
  elseif ($success.IsPresent) { Write-Host:Success $message }
  elseif ($err.IsPresent) { Write-Host:Error $message }
  $global:stream = $null
  $global:fw_name = $null
  $global:expect = $null
  Get-SSHSession | Remove-SSHSession | Out-Null
  Write-Host:Info "Exiting script."
  exit
}

# Create an SSH connection with a SonicWall.
# Set global variables $global:stream and $global:fw_name.
# Note: All global variables will be set to $null when Exit-Script is called.
function Connect-SonicWall {
  param (
    # IP address of SonicWall
    [Parameter(Mandatory)][string]$ip,
    
    # Login credentials for SonicWall
    [Parameter(Mandatory)][pscredential]$credential
  )

  Write-Host:Info "Creating SSH session..."
  $session = New-SSHSession -ComputerName $ip -Credential $credential
  
  if ($null -eq $session -or -not $session.Connected)
    { Exit-Script "Connection unsuccessful. Check IP address and/or port." -err }

  Write-Host:Success "Successfully connected to SonicWall at '$ip'"
  Write-Host:Info "Authenticating credentials..."

  $stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 500)

  # Validate that the SonicWall command prompt is ready
  $output = $stream.Expect([regex]"$($credential.UserName)@(.+)>", (New-Object TimeSpan 0,0,3))
  
  if ($null -eq $output -or $output.Length -eq 0)
    { Exit-Script "Access denied" -err }

  # Extract the name of the firewall
  $output_arr = [System.Collections.ArrayList]$output.Split("`n")
  $fw_str = $output_arr[$output_arr.Count-1]
  $at_index = $fw_str.LastIndexOf('@')
  $global:fw_name = $fw_str.Substring($at_index+1, $fw_str.LastIndexOf('>')-$at_index-1)

  Write-Host:Success "Successfully logged in as '$($credential.UserName)'"

  $global:stream = $stream
}

# Write a line to the shell stream and return expected output
# if expected output is received.
function Send-Line {
  param (
    # Line of text to send
    [Parameter(Mandatory)]
    [string]$line,

    # Regex or string for SonicWall response to match
    [Parameter()]
    $expect = $global:expect,

    # Shell stream
    [Parameter()]
    [Renci.SshNet.ShellStream]$stream = $global:stream
  )
  if (($expect.GetType().Name -ne "Regex") -and ($expect.GetType().Name -ne "String"))
    { throw "-expect parameter must be either regex or string"; return }
  Write-Host:Info "Sending '$line'..."
  $stream.WriteLine($line)
  $output = $stream.Expect($expect, (New-Object TimeSpan 0,0,3))
  if (($null -eq $output) -or ($output.Length -eq 0))
    { Exit-Script "SonicWall took too long to respond." -err }
  $output_arr = [System.Collections.ArrayList]$output.Split("`n")
  try { return $output_arr.GetRange(1, $output_arr.Count-1) }
  catch { Write-Error $_; Exit-Script "Bad response." -err }
}
