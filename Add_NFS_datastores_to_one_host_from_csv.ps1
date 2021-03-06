# ===============================================================================================
# 
# COMMENT: This script reads the contents from a CSV file and adds each datastore to a given host 
#    The CSV file must contain the following headers and corresponding values;
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

do {
	$esx = read-host -prompt "Enter the name of the host to add stores to"
} while ($esx -eq "")

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
	Get-VMHost -Name $esx | % { 
		$hostId = $_.Id
	
		# Check if datastore name has been supplied
		if ($item.DSname -eq "") {
			"No datastore has been supplied"
		}
		# Check if already exists
		if ($_ | Get-Datastore | where {$_.Name -match $item.DSname}) {
			"Datastore already exists on host - $($esx)" 
  		}
  		elseif ($_.Parent -match $item.Cluster) {
    		"Adding $($item.DSname) to $($esx).........."
			New-Datastore -Nfs -VMHost $esx -Name $item.DSname -Path $item.NFSpath -NfsHost $item.NFShost > $null
			# Quick error check
			if ($?) {
				"Success!"
			}
			else {
    			"An error has occurred. Please check the logs for more information."
			}
  		}
		else {
			"This datastore is not required on this host"
		}
	}
}

Disconnect-VIServer $vc -Confirm:$false