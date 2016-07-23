# ===============================================================================================
# 
# COMMENT: This script gets all the VSS port groups for a given cluster and creates a vDS
# equivalent port group on a given destination dvSwitch.
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================


"Welcome, this script will prompt you to enter a source cluster and destination vDS switch name."
"Then, vDS port groups will be created equivalent to the port groups retrieved from the source VSS"

########################################################
#### Get user input details
do {
	$vc = read-host -prompt "Enter VC to connect to"
} while ($vc -eq "")
do {
	$vDS = read-host -prompt "Enter the name of the destination vDS switch (e.g. vDS-Cluster_A)"
} while ($vDS -eq "")
do {
	$pg_sub = read-host -prompt "Enter the proceeding characters to append to the beginning of the port group name (e.g. dvClusterA-)"
} while ($pg_sub -eq "")

# Get user login details
do {
	$cred = Get-Credential
} while ($cred -eq "")


########################################################
#### Running Script

# Connect to vCenter server
Connect-VIServer -server $vc -Credential $cred

# Get the VSS port groups (not including management port groups)
$vsPG = Get-VirtualPortGroup | where {$_.ExtensionData -like "VMware.Vim.HostPortGroup" -and $_.Name -notlike "VMkernel" -and $_.Name -notlike "VMotion" -and $_.Name -notlike "Management Network"} | select -Unique

# Check if the vDS switch already exists, otherwise create a new one

If ((Get-VirtualSwitch | where {$_.Name -like $vDS}) -eq $null){
	"no vDS exists"
} else {
	"vDS already exists"
}



$gvDS | Get-VirtualPortGroup | where {$_.Name -notlike "*DVUplinks*"} | Get-View | % {
	$pg_name = $_.Name
	[int]$vlan_id = $_.Config.DefaultPortConfig.Vlan.VlanId
	$pg_subname = $pg_name.Substring($pg_sub)
	
	"Portgroup: " + $pg_name
	# Get the ESX hosts for the given cluster
	Get-Cluster -Name $Cluster | Get-VMHost | % {
		if ($_ | Get-VirtualPortGroup | where {$_.ExtensionData -like "VMware.Vim.HostPortGroup" -and $_.Name -like $pg_subname -and $_.VlanId -like $vlan_id}) {	# Get the VSS portgroups for each host and check for vDS VLAN
			"VLAN already exists on host: " + $_.Name
		} else {
			"VLAN does not exist on host: " + $_.Name + ", adding it now...."
			$vswitch = Get-VMHost $_.Name | Get-VirtualSwitch | where {$_.ExtensionData -like "VMware.Vim.HostVirtualSwitch"} 
			"vSwitch: " + $vswitch.Name + ", Portgroup name: " + $pg_subname + ", VLAN: " + $vlan_id
			New-VirtualPortGroup -VirtualSwitch $vswitch -VLanId $vlan_id -Name $pg_subname
			
		}
	}
}

########################################################
#### End of script

Disconnect-VIServer $vc -Confirm:$false


