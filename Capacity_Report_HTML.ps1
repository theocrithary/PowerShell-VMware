# ===============================================================================================
# 
# COMMENT: This script outputs a html file with a list of VM's running on each ESX host seperated
#    by cluster and VC. Other useful information includes the ESX host uptime and any recent
#    vmotion acitivity.
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================


#################################################################
#### Global variables
#################################################################

$Date = Get-Date -format MM-dd-yyyy@HH:mm

# Prompt user for output file.
do {
  $outputFile = read-host -prompt "Enter full path for HTML output file"
} while ($outputFile -eq "")

# Ask user how many vCenters to connect to
do {
  $NumVCS = read-host -prompt "Enter the number of vCenter Servers you want to run the report for"
} while ($NumVCS -eq "")

$VCS = @()
for ($i=0; $i -lt $NumVCS; $i++) {    #Loop through adding vCenter Servers to array until count reached
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

# Set tolerance thresholds (aka. oversubscription factor)
$cpuThreshold = 4
$memThreshold = 1.75


  ########################################################
  #### Producing HTML Header

  echo "<html>" | Out-File $outputFile
  echo "<head>" | Out-File -Append $outputFile
  echo "<title>VMware Capacity report</title>" | Out-File -Append $outputFile

  echo "<style type=""text/css"">" | Out-File -Append $outputFile
  echo "#customtable{" | Out-File -Append $outputFile
  echo "font-family:'Trebuchet MS', Arial, Helvetica, sans-serif;" | Out-File -Append $outputFile
  echo "width:95%;" | Out-File -Append $outputFile
  echo "border-collapse:collapse;" | Out-File -Append $outputFile
  echo "text-align:center;}" | Out-File -Append $outputFile
  echo "#customtable td, #customtable th{" | Out-File -Append $outputFile
  echo "font-size:12;" | Out-File -Append $outputFile
  echo "border:1px solid #484848;" | Out-File -Append $outputFile
  echo "padding:3px 7px 2px 7px;}" | Out-File -Append $outputFile
  echo "#customtable th{" | Out-File -Append $outputFile
  echo "font-size:16;" | Out-File -Append $outputFile
  echo "padding-top:5px;" | Out-File -Append $outputFile
  echo "padding-bottom:4px;" | Out-File -Append $outputFile
  echo "background-color:#A7C942;" | Out-File -Append $outputFile
  echo "color:#fff;}" | Out-File -Append $outputFile
  echo "#customtable tr.header th{" | Out-File -Append $outputFile
  echo "color:#fff;" | Out-File -Append $outputFile
  echo "background-color:#149947;}" | Out-File -Append $outputFile
  echo "#customtable tr.titles td{" | Out-File -Append $outputFile
  echo "color:#fff;" | Out-File -Append $outputFile
  echo "background-color:#2B75B2;}" | Out-File -Append $outputFile
  echo "#customtable tr.total td{" | Out-File -Append $outputFile
  echo "color:#fff;" | Out-File -Append $outputFile
  echo "background-color:grey;}" | Out-File -Append $outputFile
  echo "#customtable tr.alt td{" | Out-File -Append $outputFile
  echo "color:#000;" | Out-File -Append $outputFile
  echo "background-color:#EAF2D3;}" | Out-File -Append $outputFile
  echo "</style>" | Out-File -Append $outputFile

  echo "</head>" | Out-File -Append $outputFile
  echo "<body>" | Out-File -Append $outputFile
  echo "<p><b><font face=""Arial"" size=5>VMware Capacity Report</font></b><hr size=8 color=grey>" | Out-File -Append $outputFile

  echo "<font face="Arial" size="1"><b>This report was generated on: $Date (CDT)</b></font></p>" | Out-File -Append $outputFile

  echo "<center>"  | Out-File -Append $outputFile

########################################################
#### Main body

foreach($vc in $VCS){

  Connect-VIServer -server $vc -Credential $cred
  
  # Totals
  $TotalHosts = 0
  $TotalVMs = 0
  $TotalSockets = 0
  $TotalCores = 0
  $TotalvCPU = 0
  $TotalMEM = 0  
  $TotalvMEM = 0
	

  # Table headers
  echo "<p><table id='customtable'>" | Out-File -Append $outputFile
  echo "<tr class='header'><th colspan=18>$vc</th></tr>" | Out-File -Append $outputFile
  echo "<tr class='titles'>" | Out-File -Append $outputFile
  echo "<td><b>Cluster</b></td>" | Out-File -Append $outputFile
  echo "<td><b>Total Hosts</b></td>" | Out-File -Append $outputFile
  echo "<td><b>VMs On</b></td>" | Out-File -Append $outputFile
  echo "<td><b>VMs / ESX</b></td>" | Out-File -Append $outputFile
  echo "<td><b>VMs / ESX-1</b></td>" | Out-File -Append $outputFile
  echo "<td><b>Sockets</b></td>" | Out-File -Append $outputFile  
  echo "<td><b>Total pCPU</b></td>" | Out-File -Append $outputFile
  echo "<td><b>Total vCPU</b></td>" | Out-File -Append $outputFile
  echo "<td><b>vCPU / ESX</b></td>" | Out-File -Append $outputFile  
  echo "<td><b>vCPU / ESX-1</b></td>" | Out-File -Append $outputFile  
  echo "<td><b>CPU Subscription</b></td>" | Out-File -Append $outputFile
  echo "<td><b>CPU Sub ESX-1</b></td>" | Out-File -Append $outputFile  
  echo "<td><b>CPU Sub Capacity</b></td>" | Out-File -Append $outputFile  
  echo "<td><b>Total pMEM</b></td>" | Out-File -Append $outputFile
  echo "<td><b>Total vMEM</b></td>" | Out-File -Append $outputFile
  echo "<td><b>MEM Subscription</b></td>" | Out-File -Append $outputFile
  echo "<td><b>MEM Sub ESX-1</b></td>" | Out-File -Append $outputFile
  echo "<td><b>MEM Sub Capacity</b></td></tr>" | Out-File -Append $outputFile  

  # setup variable to alternate table row highlights
  $alt = 0
  
  # Get Cluster info and iterate through each cluster
  Get-Cluster | sort | % {
  
    # Initialize re-usable variables to zero
  	$totCores = 0
  	$totSockets = 0	
  	$totpMEM = 0
  	$totvCPU = 0
  	$totvMEM = 0
  	
  	$clusterName = $_.Name
      
  	# Get Host info
  	$GVH = $_ | Get-VMHost | Get-View | select Name, @{N="Memory";E={$_.Hardware.MemorySize}}, @{N="Cores";E={$_.Hardware.CpuInfo.NumCpuCores}}, @{N="Sockets";E={$_.Hardware.CpuInfo.NumCpuPackages}}
  	$totHosts = $GVH.Count
  	$totHostsMin1 = $totHosts - 1
  	if ($totHosts -lt 2) {
  		$totHostsMin1 = $totHosts
  	}
  	
  	foreach ($ESX in $GVH) {
  		$memGB = [math]::Round($ESX.Memory/1GB,0)
  		$totSockets += $ESX.Sockets
  		$totCores += $ESX.Cores
  		$totpMEM += $memGB
  	}
  	
  	# Get VM info
  	$GVM = $_ | Get-VM | where {$_.PowerState -eq "PoweredOn"}
  	$totVMs = $GVM.Count
  	foreach ($vm in $GVM) {
  		$totvCPU += $vm.NumCPU
  		$totvMEM += [math]::Round($vm.MemoryMB/1024,0)
  	}
  	
  	if ($totCores -eq 0) {
  		$subCPU = ""
  	} else {
  	    $subCPU = [math]::Round($totvCPU/$totCores,2)
  	}
  	   
  	if ($totpMEM -eq 0) {
  	    $subMEM = ""
  	} else {
  	    $subMEM = [math]::Round(($totvMEM/$totpMEM)*100,1)
  	}

  	# Table data
  	if ($alt -eq 0){
  		echo "<tr class='alt'>" | Out-File -Append $outputFile
  		$alt = 1
  	} else {
  		echo "<tr>" | Out-File -Append $outputFile
  		$alt = 0
  	}
  	
  	# Calculations
  	$vmPerHost = [math]::Round($totVMs/$totHosts)
  	$vmPhMinus1 = [math]::Round($totVMs/$totHostsMin1)
  	$vcpuPerHost = [math]::Round($totvCPU/$totHosts)
  	$vcpuPerHostMin1 = [math]::Round($totvCPU/$totHostsMin1)
  	$cpuSubMinus1 = [math]::Round($totvCPU/(($totCores/$totHosts)*$totHostsMin1),2)
  	$cpuSubCapacity = [math]::Round((1-($cpuSubMinus1/$cpuThreshold))*100,2)
  	$memSubMinus1 = [math]::Round(($totvMEM/(($totpMEM/$totHosts)*$totHostsMin1))*100,2)
  	$memSubCapacity = [math]::Round(($memThreshold*100)-$memSubMinus1,2)
  	
  	
  	# Output
  	echo "<td>$clusterName</td>" | Out-File -Append $outputFile
  	echo "<td>$totHosts</td>" | Out-File -Append $outputFile
  	echo "<td>$totVMs</td>" | Out-File -Append $outputFile
  	echo "<td>$vmPerHost</td>" | Out-File -Append $outputFile
  	echo "<td>$vmPhMinus1</td>" | Out-File -Append $outputFile
  	echo "<td>$totSockets</td>" | Out-File -Append $outputFile	
  	echo "<td>$totCores</td>" | Out-File -Append $outputFile
  	echo "<td>$totvCPU</td>" | Out-File -Append $outputFile
  	echo "<td>$vcpuPerHost</td>" | Out-File -Append $outputFile	
  	echo "<td>$vcpuPerHostMin1</td>" | Out-File -Append $outputFile	
  	echo "<td>$subCPU</td>" | Out-File -Append $outputFile
  	echo "<td>$cpuSubMinus1</td>" | Out-File -Append $outputFile
  	echo "<td>$cpuSubCapacity%</td>" | Out-File -Append $outputFile	
  	echo "<td>$($totpMEM)GB</td>" | Out-File -Append $outputFile
  	echo "<td>$($totvMEM)GB</td>" | Out-File -Append $outputFile
  	echo "<td>$subMEM%</td>" | Out-File -Append $outputFile
  	echo "<td>$memSubMinus1%</td>" | Out-File -Append $outputFile
  	echo "<td>$memSubCapacity%</td>" | Out-File -Append $outputFile
  	
  	# Add Totals
  	$TotalHosts += $totHosts
  	$TotalVMs += $totVMs
  	$TotalSockets += $totSockets
  	$TotalCores += $totCores
  	$TotalvCPU += $totvCPU
  	$TotalMEM += $totpMEM 
  	$TotalvMEM += $totvMEM
  }

  echo "<tr class='total'><td><b>Totals</b></td>" | Out-File -Append $outputFile
  echo "<td><b>$TotalHosts</b></td>" | Out-File -Append $outputFile  
  echo "<td><b>$TotalVMs</b></td>" | Out-File -Append $outputFile
  echo "<td><b>&nbsp;</b></td>" | Out-File -Append $outputFile  
  echo "<td><b>&nbsp;</b></td>" | Out-File -Append $outputFile  
  echo "<td><b>$TotalSockets</b></td>" | Out-File -Append $outputFile
  echo "<td><b>$TotalCores</b></td>" | Out-File -Append $outputFile
  echo "<td><b>$TotalvCPU</b></td>" | Out-File -Append $outputFile
  echo "<td><b>&nbsp;</b></td>" | Out-File -Append $outputFile
  echo "<td><b>&nbsp;</b></td>" | Out-File -Append $outputFile
  echo "<td><b>&nbsp;</b></td>" | Out-File -Append $outputFile
  echo "<td><b>&nbsp;</b></td>" | Out-File -Append $outputFile
  echo "<td><b>&nbsp;</b></td>" | Out-File -Append $outputFile  
  echo "<td><b>$TotalMEM</b></td>" | Out-File -Append $outputFile
  echo "<td><b>$TotalvMEM</b></td>" | Out-File -Append $outputFile
  echo "<td><b>&nbsp;</b></td>" | Out-File -Append $outputFile
  echo "<td><b>&nbsp;</b></td>" | Out-File -Append $outputFile
  echo "<td><b>&nbsp;</b></td></tr>" | Out-File -Append $outputFile
  echo "</table></p>" | Out-File -Append $outputFile
  Disconnect-VIServer $vc -Confirm:$false
}

# Finish off the HTML file
echo "</center>"  | Out-File -Append $outputFile
echo "</body>" | Out-File -Append $outputFile
echo "</html>" | Out-File -Append $outputFile
  
# Now resetting warning preference to original setting
$WarningPreference = $wpref

#launch the output file with Internet Explorer
Invoke-Item $outputFile