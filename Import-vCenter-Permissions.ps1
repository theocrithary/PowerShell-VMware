# ===============================================================================================
# 
# COMMENT: Import vCenter roles and permissions from XML file
#
# Changes:
#    Version 1.0 - Original - Theo Crithary
#
# ===============================================================================================

########################################################
#### Get user input details

# Prompt user for input file.
do {
  $InputFile = read-host -prompt "Enter full path for XML input file"
} while ($InputFile -eq "")

# Ask user for vCenter to import permissions
do {
    $vc = read-host -prompt "Enter VC to import permissions into"
} while ($vc -eq "")

# Get user login details
do {
    $cred = Get-Credential
} while ($cred -eq "")

########################################################
#### Running Script

# Connect to vCenter server
Connect-VIServer -server $vc -Credential $cred

# Functions
function New-Role
{
    param($name, $privIds)
    Begin{}
    Process{

        $roleId = $authMgr.AddAuthorizationRole($name,$privIds)
    }
    End{
        return $roleId
    }
}

function Set-Permission
{
param(
[VMware.Vim.ManagedEntity]$object,
[VMware.Vim.Permission]$permission
)
Begin{}
Process{
    $perms = $authMgr.SetEntityPermissions($object.MoRef,@($permission))
}
End{
    return
}
}

# Main
# Create hash table with the current roles
$authMgr = Get-View AuthorizationManager
$roleHash = @{}
$authMgr.RoleList | % {
    $roleHash[$_.Name] = $_.RoleId
}

# Read XML file
$vInventory = [xml]"<dummy/>"
$vInventory.Load($InputFile)

# Define Xpaths for the roles and the permissions
$XpathRoles = “Inventory/Roles/Role”
$XpathPermissions = “Inventory/Permissions/Permission”

# Create custom roles
$vInventory.SelectNodes($XpathRoles) | % {
    if(-not $roleHash.ContainsKey($_.Name)){
        $privArray = @()
        $_.Privilege | % {
            $privArray += $_.Name
        }
        $roleHash[$_.Name] = (New-Role $_.Name $privArray)
    }
}

# Set permissions
$vInventory.SelectNodes($XpathPermissions) | % {
    $perm = New-Object VMware.Vim.Permission
    $perm.group = &{if ($_.Group -eq “true”) {$true} else {$false}}
    $perm.principal = $_.Principal
    $perm.propagate = &{if($_.Propagate -eq “true”) {$true} else {$false}}
    $perm.roleId = $roleHash[$_.Role]

    $EntityName = $_.Entity.Replace(“(“,“\(“).Replace(“)”,“\)”)
    $EntityName = $EntityName.Replace(“[","\[").Replace("]“,“\]”)
    $EntityName = $EntityName.Replace(“{“,“\{“).Replace(“}”,“\}”)

    $entity = Get-View -ViewType $_.EntityType -Filter @{“Name”=("^" + $EntityName + "$")}
    Set-Permission $entity $perm
}
