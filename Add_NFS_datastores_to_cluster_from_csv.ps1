# ===============================================================================================
# 
# COMMENT: This script reads the contents from a CSV file and adds each datastore to the 
#    correct cluster. The CSV file must contain the following headers and corresponding values;
#    Cluster,NFSHost,NFSpath,DSname
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================

# Ask user for input
do {
	$csv = read-host -prompt "Enter full path to CSV file"
} while ($csv -eq "")

do {
	$vc = read-host -prompt "Enter the name of the vCenter to connect to"
} while ($vc -eq "")

# Import the csv data into an array
$data = Import-CSV $csv

# Get user login details
do {
	$cred = Get-Credential
} while ($cred -eq "")

Connect-VIServer -server $vc -Credential $cred

# Iterate through the array
foreach ($item in $data)
{
	# Get host info
	Get-Cluster -Name $item.Cluster | Get-VMHost | % { 
		$hostId = $_.Id
		$hostName = $_.Name
	
		# Check if datastore name has been supplied
		if ($item.DSname -eq "") {
			"No datastore has been supplied"
		}
		# Check if already exists
		if (Get-VMHost -Id $hostId | Get-Datastore | where {$_.Name -match $item.DSname}) {
			"Datastore already exists on host - $($hostName)" 
  		}
  		else {
    		"Adding $($item.DSname) to $($hostName).........."
			New-Datastore -Nfs -VMHost $hostName -Name $item.DSname -Path $item.NFSpath -NfsHost $item.NFShost > $null
			# Quick error check
			if ($?) {
				"Success!"
			}
			else {
    			"An error has occurred. Please check the logs for more information."
			}
  		}
	}
}

Disconnect-VIServer $vc -Confirm:$false