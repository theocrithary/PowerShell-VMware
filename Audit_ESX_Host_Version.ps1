# ===============================================================================================
# 
# COMMENT: This script outputs a html file that lists ESX host version and color codes them
#    according to compliance with a set build ID.
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================

# Get the date to use in filename
$Date = Get-Date -format MM-dd-yyyy@HH:mm

# Prompt user for output file.
do {
  $outputFile = read-host -prompt "Enter full path for XML output file"
} while ($outputFile -eq "")

# Set master build ID's
$build_40 = "332073"
$build_41i = "VMware ESXi 4.1.0 build-348481"
$build_support = "VMware ESXi 4.1.0 build-381591"

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
echo "Note: this may take up to 15 mins, depending on how many VC's are connected"
echo "... Generating report"

########################################################
#### Producing HTML
echo "<html>" | Out-File $outputFile
echo "<head>" | Out-File -Append $outputFile
echo "<title>ESX Version Report</title>" | Out-File -Append $outputFile

echo "<style type=""text/css"">" | Out-File -Append $outputFile
echo "body {background-color: #FFFFFF}" | Out-File -Append $outputFile
echo ".style1 {font-family: geneva, arial, helvetica, sans-serif}" | Out-File -Append $outputFile
echo "a {text-decoration: none; color: #ffffff}" | Out-File -Append $outputFile
echo "table {border: 1px solid #b5b5b5;border-collapse:collapse;}" | Out-File -Append $outputFile
echo "th {color: #ffffff;margin:0}" | Out-File -Append $outputFile
echo "</style>" | Out-File -Append $outputFile

echo "</head>" | Out-File -Append $outputFile
echo "<body>" | Out-File -Append $outputFile

echo "<b><font face=""Arial"" size=5>ESX host version report</font></b><hr size=8 color=#149947>" | Out-File -Append $outputFile
echo "<font face="Arial" size="1"><b>This report was generated on: $Date (CDT)</b></font><br>" | Out-File -Append $outputFile
echo "<center>"  | Out-File -Append $outputFile


foreach ($vc in $VCS) {
	connect-viserver -server $vc 
	
	$hostview = Get-VMHost | Get-View | select Name,@{N="Version";E={$_.Config.Product.FullName}},@{N="Vendor";E={$_.Summary.Hardware.Vendor}},@{N="Model";E={$_.Hardware.SystemInfo.Model}} | sort Name
	$esxcount = $hostview.count

	echo "<table border=""2"" bordercolor=""#FFFFFF"" bgcolor=""#CEDAEA"" >" | Out-File -Append $outputFile
	
	echo "<tr><th colspan=4 bgcolor=#2B75B2>" $vc "</th></tr>" | Out-File -Append $outputFile
	echo "<tr bgcolor=#149947><th>Host</th></th><th>Hardware</th><th>Version</th><th>Compliant</th></tr>" | Out-File -Append $outputFile
	
	foreach ($esx in $hostview) {
		
		if (($esx.Version -match $build_40) -or ($esx.Version -match $build_41i) -or ($esx.Version -match $build_support)) {
			echo "<tr><td>&nbsp;" $esx.Name "&nbsp;</td>" | Out-File -Append $outputFile
			echo "<td>&nbsp;" $esx.Vendor $esx.Model "&nbsp;</td>" | Out-File -Append $outputFile
			echo "<td>&nbsp;" $esx.Version "&nbsp;</td>" | Out-File -Append $outputFile			
			echo "<td align=center><img src=""../images/tick.png"" width=20px></td></tr>" | Out-File -Append $outputFile			
		}
		else {
			echo "<tr><td>&nbsp;" $esx.Name "&nbsp;</td>" | Out-File -Append $outputFile
			echo "<td>&nbsp;" $esx.Vendor $esx.Model "&nbsp;</td>" | Out-File -Append $outputFile
			echo "<td>&nbsp;" $esx.Version "&nbsp;</td>" | Out-File -Append $outputFile			
			echo "<td align=center><img src=""../images/cross.png"" width=20px></td></tr>" | Out-File -Append $outputFile						
		}
		
	}

	echo "<tr bgcolor=#149947><th align=""center"" colspan=4>Total number of hosts = " $esxcount "</th></tr>" | Out-File -Append $outputFile
	
	Disconnect-VIServer $vc -Confirm:$false
	
	echo "</table></br>" | Out-File -Append $outputFile
}

echo "</center>"  | Out-File -Append $outputFile
echo "</body>" | Out-File -Append $outputFile
echo "</html>" | Out-File -Append $outputFile

#launch the output file with Internet Explorer
Invoke-Item $outputFile

# Now resetting warning preference to original setting
$WarningPreference = $wpref