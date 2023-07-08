# The following script will
# - create address objects provided by the $objs_csv file,
# - create an address group with name $group_name
#   containing the newly created objects,
# - and create an access rule with options described in file
#   $rule_options (which is formatted following rule-options-template.txt)
#   and name $rule_name

# This script MUST be in the same directory as the
# sw-ssh-module.psm1 module file.

# Example command line to execute script cleanly:

param (
  [Parameter(Mandatory)][string]$ip,
  [Parameter(Mandatory)][pscredential]$credential,
  [Parameter(Mandatory)][string]$objs_csv,
  [Parameter(Mandatory)][string]$group_name,
  [Parameter(Mandatory)][string]$rule_options,
  [Parameter(Mandatory)][string]$rule_name
)

# Import necessary commandlets
Import-Module .\sw-ssh-module.psm1 -DisableNameChecking -Force

# Get an SSH shell stream hooked to the SonicWall
Connect-SonicWall $ip $credential
$config_prompt = "config($global:fw_name)#"
$objs = Import-CSV $objs_csv

Send-Line "config" -expect $config_prompt
foreach ($obj in $objs) {
  $global:expect = [regex]"\((add|edit)-ipv4-address-object\[$($obj.name)\]\)#"
  Send-Line "address-object ipv4 `"$($obj.name)`""
  Send-Line "host $($obj.ip)"
  Send-Line "zone $($obj.zone)"
  Send-Line "exit" -expect $config_prompt
}
$global:expect = [regex]"\((add|edit)-ipv4-address-group\[$group_name\]\)#"
Send-Line "address-group ipv4 `"$group_name`""
foreach ($obj in $objs) {
  Send-Line "address-object ipv4 `"$($obj.name)`""
}
Send-Line "exit" -expect $config_prompt
$output = Send-Line ((Get-Content $rule_options) -join "`n").Replace("`n","") -expect ([regex]"\((add|edit)-access-rule\)#")
if ($output -eq "(edit-access-rule)# ") {
  Write-Host:Error "Access rule already exists. No changes will be made to access rules."
} elseif ($output -eq "(add-access-rule)# ") {
  Send-Line "name `"$rule_name`"" -expect "(add-access-rule)#"
  Send-Line "exit" -expect $config_prompt
} else {
  Write-Host:Error "unexpected output"
}
# "% (No )?[Cc]hanges made\."
Send-Line "commit" -expect "% Applying changes..."

Exit-Script "Script finished." -success
