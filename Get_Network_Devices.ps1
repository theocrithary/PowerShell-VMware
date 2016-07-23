# ===============================================================================================
# 
# COMMENT: This script outputs a html file with a list of network devices for each ESX host seperated
#    by cluster and VC. Other useful information includes the freespace, capacity, usage and status.
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================

$Date = date

########################################################
#### Get user input details

# Prompt user for output file.
do {
  $outputFile = read-host -prompt "Enter full path for HTML output file"
} while ($outputFile -eq "")

# Ask user how many vCenters to connect to
do {
	$NumVCS = read-host -prompt "Enter the number of vCenter Servers you want to run the report for"
} while ($NumVCS -eq "")

$VCS = @()
for ($i=0; $i -lt $NumVCS; $i++) {		#Loop through adding vCenter Servers to array until count reached
	$VC = read-host -prompt "Enter the name of the vCenter to connect to"
	$VCS += $VC
}

# Get user login details
do {
    $cred = Get-Credential
} while ($cred -eq "")

# Alert user that process has started
echo "... Generating report"

########################################################
#### Producing HTML
echo "<html>" | Out-File $outputFile
echo "<head>" | Out-File -Append $outputFile
echo "<title>ESX NIC Audit</title>" | Out-File -Append $outputFile

echo "<style type=""text/css"">" | Out-File -Append $outputFile
echo "body {background-color: #CECFCE}" | Out-File -Append $outputFile
echo ".style1 {font-family: geneva, arial, helvetica, sans-serif}" | Out-File -Append $outputFile
echo "</style>" | Out-File -Append $outputFile

echo "</head>" | Out-File -Append $outputFile
echo "<body>" | Out-File -Append $outputFile
echo "<center>"  | Out-File -Append $outputFile

echo "<table border=""2"" bordercolor=""#FFFFFF"" bgcolor=""#CEDAEA"" >" | Out-File -Append $outputFile
echo "<tr align=""center""> <td><b>Host</b></td> <td> <b>Device Name</b></td></tr>" | Out-File -Append $outputFile

foreach($vc in $VCS){
  $hosts = Get-VMHost | sort
  foreach($esx in $hosts){
    echo "<tr><td> $esx.name </td>" | Out-File -Append $outputFile
    $view = $esx | get-view
    $device = $view.hardware.pcidevice | select devicename -Unique
	echo "<td> " $device.devicename "</td></tr>" | Out-File -Append $outputFile
  }
}

echo "</table>" | Out-File -Append $outputFile
echo "</center>"  | Out-File -Append $outputFile
echo "</body>" | Out-File -Append $outputFile
echo "</html>" | Out-File -Append $outputFile

#launch the output file with Internet Explorer
Invoke-Item $outputFile