# ===============================================================================================
# 
# COMMENT: This script outputs a CSV file capacity report for a given vCenter 
#    Requires that host running script has both PowerCLI and MS Office installed
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================


#################################################################
#### Global variables
#################################################################

# Get the date to use in filename
$Date = date

# Prompt user for output file.
do {
	$outputFile = read-host -prompt "Enter full path for CSV output file"
} while ($outputFile -eq "")

# Create an Excel workbook to export data into
$Excel = New-Object -Com Excel.Application
$Excel.visible = $True
$Workbook = $Excel.Workbooks.Add()

# Ask user how many vCenters to connect to
do {
	$NumVCS = read-host -prompt "Enter the number of vCenter Servers you want to run the report for"
} while ($NumVCS -eq "")

$VCS = @()
for ($i=0; $i -lt $NumVCS; $i++) {		#Loop through adding vCenter Servers to array until count reached
	$VC = read-host -prompt "Enter the name of the vCenter to connect to"
	$VCS += $VC
}

# Specify the worksheet to start on
$SheetCount = 1

# Get user login details
do {
	$cred = Get-Credential
} while ($cred -eq "")

echo "Getting VC information for connection ..."
########################################################
#### Pulling the data and generating the content
########################################################

# Going to go VC-by-VC to avoid problems with duplicate datacenter names
foreach ($vc in $VCS) {
   
   # Use this connection if connecting from non-hosted server
   connect-viserver -server $vc -Credential $cred

   echo "Pulling data from $vc ..."

   # Get datacenter info
   Get-Datacenter | % { 
     $dcId = $_.ID
	 $dcName = $_.Name
	 
	 # Build the Excel workbook
	 
	 $SheetTotal = $Workbook.WorkSheets.Count
	 if($SheetCount -gt $SheetTotal) {
	 	$lastSheet = $workBook.WorkSheets.Item($SheetTotal)
	 	$lastSheet = $Workbook.WorkSheets.Add([System.Reflection.Missing]::Value,$lastSheet)
	 }
	 
	 $Sheet = $Workbook.WorkSheets | where {$_.index -eq $SheetCount}
	 $Sheet.Activate()
	 	 
	 $Sheet.Cells.Item(1,1) = $vc
	 $Sheet.Cells.Item(1,2) = $dcName
	 $Sheet.Name = $vc
	 $Sheet.Cells.Item(2,1) = "Cluster"
	 $Sheet.Cells.Item(2,2) = "Total Hosts"
	 $Sheet.Cells.Item(2,3) = "VMs On"
	 $Sheet.Cells.Item(2,4) = "Total pCPU"
	 $Sheet.Cells.Item(2,5) = "Total vCPU"
	 $Sheet.Cells.Item(2,6) = "CPU Subscription"
	 $Sheet.Cells.Item(2,7) = "Total pMEM"
	 $Sheet.Cells.Item(2,8) = "Total vMEM"
	 $Sheet.Cells.Item(2,9) = "MEM Subscription"
	 $Sheet = $Sheet.UsedRange
	 $Sheet.Interior.Color = 192
	 $Sheet.Font.ColorIndex = 2
	 $Sheet.Font.Bold = $True
	 
	 $RowCount = 3
	 
	 # Get cluster info 
	 $_ | Get-Cluster | sort | % { 
	   $clusterName = $_.Name
	   
	   # Initialize re-usable variables to zero
	   $totpCPU = 0
	   $totpMEM = 0
	   $totvCPU = 0
	   $totvMEM = 0
	   
	   # Get VM host info
	   $GVH = $_ | Get-VMHost | select Name, NumCpu, MemoryTotalMB | sort
	   	 $totHosts = $GVH.Count
		 foreach ($ESX in $GVH) {
		   $numCPU = $ESX.NumCpu
		   $memGB = [math]::Round($ESX.MemoryTotalMB/1024,0)
		   $totpCPU += $numCPU
		   $totpMEM += $memGB
		 }
	   
	   # Get VM info
	   $GVM = $_ | Get-VM | where {$_.PowerState -eq "PoweredOn"}
		 $totVMs = $GVM.Count
	   foreach ($vm in $GVM) {
	     $totvCPU += $vm.NumCPU
		 $totvMEM += [math]::Round($vm.MemoryMB/1024,0)
	   }
	   
	   if ($totpCPU -eq 0) {
	     $subCPU = ""
	   } else {
	     $subCPU = [math]::Round($totvCPU/$totpCPU,2)
	   }
	   
	   if ($totpMEM -eq 0) {
	     $subMEM = ""
	   } else {
	     $subMEM = [math]::Round(($totvMEM/$totpMEM)*100,1)
	   }
	   
	   # Populating the dc table
  	   $Sheet.Cells.Item($RowCount,1) = $clusterName
  	   $Sheet.Cells.Item($RowCount,2) = $totHosts
  	   $Sheet.Cells.Item($RowCount,3) = $totVMs
  	   $Sheet.Cells.Item($RowCount,4) = $totpCPU
  	   $Sheet.Cells.Item($RowCount,5) = $totvCPU
  	   $Sheet.Cells.Item($RowCount,6) = $subCPU
  	   $Sheet.Cells.Item($RowCount,7) = $totpMEM
  	   $Sheet.Cells.Item($RowCount,8) = $totvMEM
  	   $Sheet.Cells.Item($RowCount,9) = $subMEM
	   
	   $RowCount++
	   
	   $Sheet.EntireColumn.AutoFit()
  
	 } # End of cluster info
	 
  } # End of datacenter info
  
  Disconnect-VIServer $vc -Confirm:$false
  
  	 # Adding Totals
	 
	 $SumRow = $RowCount-1
	 
  	 $Sheet.Cells.Item($RowCount,1) = "Totals"
  	 $Sheet.Cells.Item($RowCount,2) = "=sum(B3:B"+$SumRow+")"
  	 $Sheet.Cells.Item($RowCount,3) = "=sum(C3:C"+$SumRow+")"
  	 $Sheet.Cells.Item($RowCount,4) = "=sum(D3:D"+$SumRow+")"
  	 $Sheet.Cells.Item($RowCount,5) = "=sum(E3:E"+$SumRow+")"
  	 $Sheet.Cells.Item($RowCount,6) = "=sum(F3:F"+$SumRow+")"
  	 $Sheet.Cells.Item($RowCount,7) = "=sum(G3:G"+$SumRow+")"
  	 $Sheet.Cells.Item($RowCount,8) = "=sum(H3:H"+$SumRow+")"
  	 $Sheet.Cells.Item($RowCount,9) = "=sum(I3:I"+$SumRow+")"
	 
	 $Sheet = $Sheet.Range("A$($RowCount):I$($RowCount)")
	 $Sheet.Font.Bold = $True

  $SheetCount++
  
} # End of VC list

$Workbook.SaveAs($outputFile)

$Excel.Quit()
