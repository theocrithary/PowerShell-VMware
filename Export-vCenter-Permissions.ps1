# ===============================================================================================
# 
# COMMENT: Export vCenter roles and permissions to XML file
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================

########################################################
#### Get user input details

# Prompt user for output file.
do {
  $OutputFile = read-host -prompt "Enter full path for XML output file"
} while ($OutputFile -eq "")

# Ask user for vCenter to import permissions
do {
    $vc = read-host -prompt "Enter VC to export permissions from"
} while ($vc -eq "")

# Get user login details
do {
    $cred = Get-Credential
} while ($cred -eq "")

########################################################
#### Running Script

# Connect to vCenter server
Connect-VIServer -server $vc -Credential $cred

# Root of the XML file
$global:vInventory = [xml]"<Inventory></Inventory>"

# Functions
function New-XmlNode{
	param($node, $nodeName)

	$tmp = $global:vInventory.CreateElement($nodeName)
	$node.AppendChild($tmp)
}

function Set-XmlAttribute{
	param($node, $name, $value)

	$node.SetAttribute($name, $value)
}
function Get-XmlNode{
	param ($path)
	$global:vInventory.SelectNodes($path)
}

function Get-Roles{
  begin{
    $authMgr = Get-View AuthorizationManager
    $report = @()
  }
  process{
    foreach($role in $authMgr.roleList){
      $ret = New-Object PSObject
      $ret | Add-Member -Type noteproperty -Name "Name" -Value $role.name
      $ret | Add-Member -Type noteproperty -Name "Label" -Value $role.info.label
      $ret | Add-Member -Type noteproperty -Name "Summary" -Value $role.info.summary
      $ret | Add-Member -Type noteproperty -Name "RoleId" -Value $role.roleId
      $ret | Add-Member -Type noteproperty -Name "System" -Value $role.system
      $ret | Add-Member -Type noteproperty -Name "Privilege" -Value $role.privilege
      $report += $ret
    }
  }
  end{
    return $report
  }
}
function Get-Permissions
{
  begin{
    $report = @()
    $authMgr = Get-View AuthorizationManager
    $roleHash = @{}
    $authMgr.RoleList | %{
      $roleHash[$_.RoleId] = $_.Name
    }
  }
  process{
    $perms = $authMgr.RetrieveAllPermissions()
    foreach($perm in $perms){
      $ret = New-Object PSObject
      $entity = Get-View $perm.Entity
      $ret | Add-Member -Type noteproperty -Name "Entity" -Value $entity.Name
      $ret | Add-Member -Type noteproperty -Name "EntityType" -Value $entity.gettype().Name
      $ret | Add-Member -Type noteproperty -Name "Group" -Value $perm.Group
      $ret | Add-Member -Type noteproperty -Name "Principal" -Value $perm.Principal
      $ret | Add-Member -Type noteproperty -Name "Propagate" -Value $perm.Propagate
      $ret | Add-Member -Type noteproperty -Name "Role" -Value $roleHash[$perm.RoleId]
      $report += $ret
    }
  }
  end{
    return $report
  }
}
$global:vInventory = [xml]"<Inventory><Roles/><Permissions/></Inventory>"

# Main
# Roles
  $XMLRoles = Get-XmlNode "Inventory/Roles"
Get-Roles | where {-not $_.System} | % {
  $XMLRole = New-XmlNode $XMLRoles "Role"
  Set-XmlAttribute $XMLRole "Name" $_.Name
  Set-XmlAttribute $XMLRole "Label" $_.Label
  Set-XmlAttribute $XMLRole "Summary" $_.Summary
  $_.Privilege | % {
    $XMLPrivilege = New-XmlNode $XMLRole "Privilege"
    Set-XmlAttribute $XMLPrivilege "Name" $_
  }
}

# Permissions
$XMLPermissions = Get-XmlNode "Inventory/Permissions"
Get-Permissions | % {
  $XMLPerm = New-XmlNode $XMLPermissions "Permission"
  Set-XmlAttribute $XMLPerm "Entity" $_.Entity
  Set-XmlAttribute $XMLPerm "EntityType" $_.EntityType
  Set-XmlAttribute $XMLPerm "Group" $_.Group
  Set-XmlAttribute $XMLPerm "Principal" $_.Principal
  Set-XmlAttribute $XMLPerm "Propagate" $_.Propagate
  Set-XmlAttribute $XMLPerm "Role" $_.Role
}

# Create XML file
$global:vInventory.Save($OutputFile)
