# ================= SAFE WORKSTATION LOCKDOWN SCRIPT =================

# 0. Detect groups based on localized OS
$AdminsGroup      = (Get-LocalGroup | Where-Object {$_.SID -eq "S-1-5-32-544"}).Name
$UsersGroup       = (Get-LocalGroup | Where-Object {$_.SID -eq "S-1-5-32-545"}).Name

# 1. Settings
$CurrentUser          = $env:USERNAME
$CurrentUserPassword  = "1111"

$AdminUser      = "admin"
$AdminPassword  = "298377"

Write-Host "Current logged-in user: $CurrentUser"
Write-Host "Detected admin group: $AdminsGroup"
Write-Host "Detected users group: $UsersGroup"


# ========================= 2. CREATE ADMIN ACCOUNT ==========================

try {
    if (-not (Get-LocalUser -Name $AdminUser -ErrorAction SilentlyContinue)) {
        Write-Host "Creating admin account $AdminUser ..."
        New-LocalUser -Name $AdminUser `
            -Password (ConvertTo-SecureString $AdminPassword -AsPlainText -Force) `
            -FullName $AdminUser `
            -PasswordNeverExpires `
            -UserMayNotChangePassword
    }
    else {
        Write-Host "Admin user already exists — OK"
    }

    Write-Host "Adding admin to $AdminsGroup ..."
    Add-LocalGroupMember -Group $AdminsGroup -Member $AdminUser -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Admin creation error: $($_.Exception.Message)"
}



# ========================= 3. ASK FOR NEW LOGIN ==========================

Write-Host ""
Write-Host "==== Rename current user ===="

$NewName = Read-Host "ENTER NEW LOGIN (new username)"



# ========================= 4. RENAME CURRENT USER ==========================

try {
    Write-Host "Renaming $CurrentUser → $NewName ..."
    Rename-LocalUser -Name $CurrentUser -NewName $NewName
}
catch {
    Write-Warning "Rename failed: $($_.Exception.Message)"
}

try {
    Write-Host "Setting FullName to $NewName ..."
    Set-LocalUser -Name $NewName -FullName $NewName
}
catch {
    Write-Warning "FullName update failed: $($_.Exception.Message)"
}



# ========================= 5. PASSWORD + GROUP FIX ==========================

try {
    Write-Host "Setting password for $NewName ..."
    Set-LocalUser -Name $NewName -Password (ConvertTo-SecureString $CurrentUserPassword -AsPlainText -Force)
}
catch {
    Write-Warning "Password update failed: $($_.Exception.Message)"
}

# MUST BE IN Users BEFORE removal from Administrators
try {
    Write-Host "Adding $NewName to Users group ($UsersGroup)..."
    Add-LocalGroupMember -Group $UsersGroup -Member $NewName -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Add to Users group failed: $($_.Exception.Message)"
}

# Only now remove admin rights (SAFE)
try {
    Write-Host "Removing $NewName from Administrators group..."
    Remove-LocalGroupMember -Group $AdminsGroup -Member $NewName -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Admin rights removal failed: $($_.Exception.Message)"
}



# ========================= 6. SOFTWARE RESTRICTION POLICIES ==========================

Write-Host ""
Write-Host "Applying SRP rules ..."

$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers"

New-Item -Path $RegPath -Force | Out-Null
Set-ItemProperty -Path $RegPath -Name "DefaultLevel" -Value 0x40000
Set-ItemProperty -Path $RegPath -Name "PolicyScope" -Value 0
Set-ItemProperty -Path $RegPath -Name "TransparentEnabled" -Value 1


function Add-SRP-Rule($Guid, $Path) {
    $Base = "$RegPath\0\Paths\$Guid"
    New-Item -Path $Base -Force | Out-Null
    Set-ItemProperty -Path $Base -Name "Description" -Value "Block $Path"
    Set-ItemProperty -Path $Base -Name "ItemData" -Value $Path
    Set-ItemProperty -Path $Base -Name "SaferFlags" -Value 0
    Set-ItemProperty -Path $Base -Name "LastModified" -Value (Get-Date).ToFileTime()
}

Add-SRP-Rule "{11111111-1111-1111-1111-111111111111}" "$env:USERPROFILE\Desktop\*"
Add-SRP-Rule "{22222222-2222-2222-2222-222222222222}" "$env:USERPROFILE\Downloads\*"

Write-Host "SRP rules applied."


# ========================= DONE ==========================

Write-Host ""
Write-Host "User successfully renamed to: $NewName"
Write-Host "Reboot is recommended."
Write-Host "====================================================="
