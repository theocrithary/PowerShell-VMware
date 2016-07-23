# ===========================================================================================================
# 
# COMMENT: This script outputs a html file with a list of Datastores mounted on each ESX host seperated
#    by cluster and VC. Other useful information includes the freespace, capacity, usage and status.
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===========================================================================================================

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

# Get the date
$Date = date

# Set thresholds
$warning = 75
$alert = 85

# Alert user that process has started
echo "... Generating report"

########################################################
#### Producing HTML
echo "<html>" | Out-File $outputFile
echo "<head>" | Out-File -Append $outputFile
echo "<title>Datastore Usage Report</title>" | Out-File -Append $outputFile

echo "<style type=""text/css"">" | Out-File -Append $outputFile
echo "body {background-color: #FFFFFF}" | Out-File -Append $outputFile
echo ".head1 {background: grey; color: #FFFFFF}" | Out-File -Append $outputFile
echo ".head2 {background: #2B75B2; color: #FFFFFF}" | Out-File -Append $outputFile
echo ".head3 {background: #149947; color: #FFFFFF; text-align: left}" | Out-File -Append $outputFile
echo "a {text-decoration: none; color: #000000; font-size:10px}" | Out-File -Append $outputFile
echo "table {border: 1px solid #b5b5b5;border-collapse:collapse;}" | Out-File -Append $outputFile
echo "th {color: #ffffff;margin:0}" | Out-File -Append $outputFile
echo "img {height:20}" | Out-File -Append $outputFile
echo "</style>" | Out-File -Append $outputFile

echo "<script type='text/javascript'>" | Out-File -Append $outputFile
echo "window.onload = function() {" | Out-File -Append $outputFile
echo "var  div  = document.getElementById('expandable_div');" | Out-File -Append $outputFile
echo "if ( div ) {" | Out-File -Append $outputFile
echo "var p =  div .getElementsByTagName('p');" | Out-File -Append $outputFile
echo "for(var i = 0; i < p.length; i++) {" | Out-File -Append $outputFile
echo "var a = p[i].getElementsByTagName('b')[0].getElementsByTagName('a')[0];" | Out-File -Append $outputFile
echo "a.onclick = function() {" | Out-File -Append $outputFile
echo "var span = this.parentNode.getElementsByTagName('span')[0];" | Out-File -Append $outputFile
echo "span.style.display = span.style.display == 'none' ? 'block' : 'none';" | Out-File -Append $outputFile
echo "this.firstChild.nodeValue = span.style.display == 'none' ? '(Expand)' : '(Collapse)';" | Out-File -Append $outputFile
echo "};" | Out-File -Append $outputFile
echo "}" | Out-File -Append $outputFile
echo "}" | Out-File -Append $outputFile
echo "};" | Out-File -Append $outputFile
echo "</script>" | Out-File -Append $outputFile

echo "</head>" | Out-File -Append $outputFile
echo "<body>" | Out-File -Append $outputFile

echo "<b><font face=""Arial"" size=5>Datastore Usage Report</font></b><hr size=8 color=#149947>" | Out-File -Append $outputFile
echo "<font face="Arial" size="1"><b>This report was generated on: $Date</b></font><br>" | Out-File -Append $outputFile
echo "<center>"  | Out-File -Append $outputFile
echo "<div id='expandable_div'>" | Out-File -Append $outputFile

$totGlobCap = 0

foreach ($vc in $VCS) {
	connect-viserver -server $vc
	$totVCStoreCap = 0
	Get-Datastore | where {$_.Type -eq "NFS"} | % {
		$totVCStoreCap = [Math]::Round($totVCStoreCap+$_.CapacityMB,2)
	}
	$totVCStoreCap = [Math]::Round($totVCStoreCap/1024,0)
	
	echo "<p><b><table border=0 bordercolor=#FFFFFF bgcolor=#f0f0f0 width=80%><tr><th class=head1>$vc</th></tr></table>" | Out-File -Append $outputFile
	echo "<a href='#'>(Expand)</a><span style='display:none;'>" | Out-File -Append $outputFile

	echo "<table border=0 bordercolor=#FFFFFF bgcolor=#f0f0f0 width=80%>" | Out-File -Append $outputFile
	
	Get-Cluster | sort | % {
    	$clustername = $_.Name
		$datastore = $_ | Get-View | Select Datastore | sort
		$totClustCap = 0
		
		echo "<tr><th class=head2 colspan=5>" $clustername "</th></tr>" | Out-File -Append $outputFile
		echo "<tr class=head3><th><b>Datastore</b></th><th><b>Free Space</b></th><th><b>Capacity</b></th><th><b>Usage</b></th><th><b>Status</b></th></tr>" | Out-File -Append $outputFile
		
		for ($i=0; $i -lt $datastore.Datastore.count; $i++){
			Get-Datastore | where {$_.Id -match $datastore.Datastore[$i].Value -and $_.Type -eq "NFS"} | % {
				echo "<tr><td>" $_.Name "</td>" | Out-File -Append $outputFile
				$freespace = [Math]::Round($_.FreeSpaceMB/1024,2)
				$capacity = [Math]::Round($_.CapacityMB/1024,2)
				$totClustCap = [Math]::Round($totClustCap+$capacity)
				echo "<td>" $freespace "GB</td>" | Out-File -Append $outputFile
				echo "<td>" $capacity "GB</td>" | Out-File -Append $outputFile
				$usage = [Math]::Round((1-($_.FreeSpaceMB/$_.CapacityMB))*100,2)
				echo "<td>" $usage "%</td>" | Out-File -Append $outputFile
				if ($usage -gt $warning -and $usage -lt $alert) {
					echo "<td><i>Warning!</i></td></tr>" | Out-File -Append $outputFile
				} elseif ($usage -gt $alert) {
					echo "<td><i>Alert!</i></td></tr>" | Out-File -Append $outputFile
				} else {
					echo "<td><i>Good</i></td></tr>" | Out-File -Append $outputFile
				}
			}
		}
		echo "<tr><td align=center colspan=5><b>Total number of datastores in cluster = " $datastore.Datastore.count "</b></td></tr>" | Out-File -Append $outputFile	
		echo "<tr><td align=center colspan=5><b>Total capacity of datastores in cluster = " $totClustCap "GB</b></td></tr>" | Out-File -Append $outputFile
	}
	
	Disconnect-VIServer $vc -Confirm:$false
	echo "<tr><th class=head1 colspan=5>Total capacity of datastores available in " $vc " = " $totVCStoreCap "GB</th></tr>" | Out-File -Append $outputFile
  	echo "</table></span></b></p>" | Out-File -Append $outputFile
	
	$totGlobCap = [Math]::Round($totGlobCap+$totVCStoreCap)
}

echo "</div><table><tr><th colspan=5 bgcolor=black>Total capacity of all datastores globally = " $totGlobCap "GB</th></tr></table>" | Out-File -Append $outputFile		
echo "</center>"  | Out-File -Append $outputFile
echo "</body>" | Out-File -Append $outputFile
echo "</html>" | Out-File -Append $outputFile

#launch the output file with Internet Explorer
#Invoke-Item $outputFile

# Now resetting warning preference to original setting
$WarningPreference = $wpref