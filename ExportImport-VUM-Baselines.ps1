# *************************************************************************
# Copyright 2010 VMware, Inc.  All rights reserved.
# *************************************************************************/

#
# This script exports and imports patch baselines from one VMware vCenter Update Manager server to another.
#
# PARAMETERS
#	$1 - Baselines
#		The baselines to be imported.
#	$2 - Destination Server
#		The server on which you want to import the baselines.
#
# USAGE
#	The following example creates on the $destinationServer a duplicate of the MyBaseline baseline.
#
# $destinationServer = Connect-VIServer <ip_address_of_the_destination_server>
# $sourceServer = Connect-VIServer <ip_address_of_the_source_server>
# $baselines = Get-PatchBaseline MyBaseline -Server $sourceServer
# ExportImportBaselines.ps1 $baselines $destinationServer 

Param([VMware.VumAutomation.Types.Baseline[]] $baselines, [VMware.VimAutomation.ViCore.Types.V1.VIServer[]]$destinationServers)

$ConfirmPreference = 'None'
$includePatches = @()
$excludePatches = @()

function ExtractPatchesFromServer([VMware.VumAutomation.Types.Patch[]]$patches, [VMware.VimAutomation.ViCore.Types.V1.VIServer]$destinationServer){
	$result = @()
	if ($patches -ne $null){
		foreach($patch in $patches){
			$extractedPatches = Get-Patch -Server $destinationServer -SearchPhrase $patch.Name
			if ($extractedPatches -eq $null){
				Write-Warning -Message "Patch '$($patch.Name)' is not available on the server $destinationServer"
			} else {
		    	$isFound = $false
				foreach ($newPatch in $extractedPatches){
					if ($newPatch.IdByVendor -eq $patch.IdByVendor){
						$result += $newPatch
						$isFound = $true
	       			} 
	    		}
				if ($isFound -eq $false) {
					Write-Warning -Message "Patch '$($patch.Name)' with VendorId '$($patch.IdByVendor)' is not available on the server $destinationServer"
				}
  	  		}
		}
	}
	return ,$result;
}


function CreateStaticBaseline([VMware.VumAutomation.Types.Baseline]$baseline,[VMware.VimAutomation.ViCore.Types.V1.VIServer]$destinationServer){
	$includePatches = ExtractPatchesFromServer $baseline.CurrentPatches $destinationServer
	if ($includePatches.Count -lt 1){
		write-error "Static baseline '$($baseline.Name)' can't be imported. No one of the patches it contains are available on the server $destinationServer"
	} else {	
		$command = 'New-PatchBaseline -Server $destinationServer -Name $baseline.Name -Description $baseline.Description -Static -TargetType $baseline.TargetType -IncludePatch $includePatches'
		if ($baseline.IsExtension) {
			$command += ' -Extension'
		}
		
		Invoke-Expression $command
	}
}

function CreateDynamicBaseline([VMware.VumAutomation.Types.Baseline]$baseline,[VMware.VimAutomation.ViCore.Types.V1.VIServer]$destinationServer){
	if ($baseline.BaselineContentType -eq 'Dynamic'){
	    $command = 'New-PatchBaseline -Server $destinationServer -Name $baseline.Name -Description $baseline.Description -TargetType $baseline.TargetType -Dynamic -SearchPatchStartDate $baseline.SearchPatchStartDate -SearchPatchEndDate $baseline.SearchPatchEndDate -SearchPatchProduct $baseline.SearchPatchProduct -SearchPatchSeverity $baseline.SearchPatchSeverity -SearchPatchVendor $baseline.SearchPatchVendor'
	} elseif ($baseline.BaselineContentType -eq 'Both'){	     
		$includePatches = ExtractPatchesFromServer $baseline.InclPatches $destinationServer
	  	$excludePatches = ExtractPatchesFromServer $baseline.ExclPatches $destinationServer
		
		$command = 'New-PatchBaseline -Server $destinationServer -Name $baseline.Name -Description $baseline.Description -TargetType $baseline.TargetType -Dynamic -SearchPatchStartDate $baseline.SearchPatchStartDate -SearchPatchEndDate $baseline.SearchPatchEndDate -SearchPatchProduct $baseline.SearchPatchProduct -SearchPatchSeverity $baseline.SearchPatchSeverity -SearchPatchVendor $baseline.SearchPatchVendor'
		if ($includePatches.Count -gt 0){
        	$command += ' -IncludePatch $includePatches'
		} 
		
		if ($excludePatches.Count -gt 0){
		    $command += ' -ExcludePatch $excludePatches'
		}		
	} 
	
	#check for null because there is known issue for creating baseline with null SearchPatchPhrase
	if ($baseline.SearchPatchPhrase -ne $null){
		$command += ' -SearchPatchPhrase $baseline.SearchPatchPhrase'
	}
	
	Invoke-Expression $command
}

foreach ($destinationServer in $destinationServers) {
    if ($baselines -eq $null) {
	   Write-Error "The baselines parameter is null"
	} else {
		foreach($baseline in $baselines){
		    if ($baseline.GetType().FullName -eq 'VMware.VumAutomation.Types.PatchBaselineImpl'){
				Write-Host "Import '" $baseline.Name "' to the server $destinationServer" 
				if($baseline.BaselineContentType -eq 'Static'){
					CreateStaticBaseline $baseline $destinationServer
				} else {
					CreateDynamicBaseline $baseline $destinationServer	
				}
			} else {
				Write-Warning -Message "Baseline '$($baseline.Name)' is not patch baseline and will be scipped."
			}
		}
	}
}

