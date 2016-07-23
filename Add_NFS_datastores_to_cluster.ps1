# ===============================================================================================
# 
# COMMENT: This script prompts the user for input and adds NFS datastores to a specified cluster. 
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================

# Get user input details
do {
	$VC = read-host -prompt "Enter vCenter Server to connect to"
} while ($VC -eq "")
do {
	$Cluster = read-host -prompt "Enter Cluster name (as shown in vSphere Client)"
} while ($Cluster -eq "")

# Get user login details
do {
	$cred = Get-Credential
} while ($cred -eq "")

do {
	$NumNFS = read-host -prompt "Enter the number of NFS stores you want to add to this cluster"
} while ($NumNFS -eq "")

########################################################
#### Running Script

for ($i=0; $i -lt $NumNFS; $i++) {		#Loop through adding datastore until count reached
	do {
		$NFShost = read-host -prompt "Enter NFS server IP"
	} while ($NFShost -eq "")
	do {
		$NFSpath = read-host -prompt "Enter NFS exported path (aka Folder)"
	} while ($NFSpath -eq "")
	do {
		$DSname = read-host -prompt "Enter Datastore Name"
	} while ($DSname -eq "")
	$count++

	Connect-VIServer -server $vc -Credential $cred

	# Get host info
	Get-Cluster -Name $Cluster | Get-VMHost | % { 
		$hostId = $_.Id
		$hostName = $_.Name
	
		# Check if already exists
		if (Get-VMHost -Id $hostId | Get-Datastore | where {$_.Name -match $DSname}) {
			echo "Datastore already exists on host - "$hostName 
  		}
  		else {
    		echo "Adding "$DSname" to "$hostName".........."
			New-Datastore -Nfs -VMHost $hostName -Name $DSname -Path $NFSpath -NfsHost $NFShost
 
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