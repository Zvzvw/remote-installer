# === SETTINGS ===
$CurrentUser = $env:USERNAME
$CurrentUserPassword = "1111"

$AdminUser = "admin"
$AdminPassword = "298377"

Write-Host "Current logged-in user: $CurrentUser"


# === 1. Set password for current user + remove admin rights ===

try {
    Write-Host "Setting password for $CurrentUser"
    Set-LocalUser -Name $CurrentUser -Password (ConvertTo-SecureString $CurrentUserPassword -AsPlainText -Force)
}
catch {
    Write-Warning "Password set failed: $($_.Exception.Message)"
}

try {
    Write-Host "Removing $CurrentUser from Administrators"
    $AdminsGroup = (Get-LocalGroup | Where-Object {$_.SID -eq "S-1-5-32-544"}).Name
    Remove-LocalGroupMember -Group $AdminsGroup -Member $CurrentUser -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Remove admin rights failed: $($_.Exception.Message)"
}


# === 2. Create admin account ===

try {
    if (-not (Get-LocalUser -Name $AdminUser -ErrorAction SilentlyContinue)) {
        Write-Host "Creating admin account $AdminUser"
        New-LocalUser -Name $AdminUser -Password (ConvertTo-SecureString $AdminPassword -AsPlainText -Force) -FullName $AdminUser -UserMayNotChangePassword -PasswordNeverExpires
    }
    else {
        Write-Host "Admin user '$AdminUser' already exists — skipping creation."
    }
}
catch {
    Write-Warning "Admin creation failed: $($_.Exception.Message)"
}

try {
    $AdminsGroup = (Get-LocalGroup | Where-Object {$_.SID -eq "S-1-5-32-544"}).Name
    Write-Host "Adding $AdminUser to administrators group ($AdminsGroup)"
    Add-LocalGroupMember -Group $AdminsGroup -Member $AdminUser -ErrorAction SilentlyContinue
}
catch {
    Write-Warning "Add admin to group failed: $($_.Exception.Message)"
}


# === 3. SOFTWARE RESTRICTION POLICIES (SRP) ===

Write-Host "Applying SRP rules..."

$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers"

New-Item -Path $RegPath -Force | Out-Null
Set-ItemProperty -Path $RegPath -Name "DefaultLevel" -Value 0x40000
Set-ItemProperty -Path $RegPath -Name "PolicyScope" -Value 0
Set-ItemProperty -Path $RegPath -Name "TransparentEnabled" -Value 1


function Add-SRP-Rule($Guid, $Path) {
    $Base = "$RegPath\0\Paths\$Guid"
    New-Item -Path $Base -Force | Out-Null
    New-ItemProperty -Path $Base -Name "Description" -Value "Block $Path" -Force | Out-Null
    New-ItemProperty -Path $Base -Name "ItemData"   -Value $Path -Force | Out-Null
    New-ItemProperty -Path $Base -Name "SaferFlags" -Value 0 -Force | Out-Null
    New-ItemProperty -Path $Base -Name "LastModified" -Value (Get-Date).ToFileTime() -Force | Out-Null
}

Add-SRP-Rule "{11111111-1111-1111-1111-111111111111}" "$env:USERPROFILE\Desktop\*"
Add-SRP-Rule "{22222222-2222-2222-2222-222222222222}" "$env:USERPROFILE\Downloads\*"

Write-Host "SRP rules applied."


# === 4. RENAME CURRENT USER ===

Write-Host ""
Write-Host "==== Rename current user ===="

$NewName = Read-Host "ENTER NEW LOGIN"

try {
    Write-Host "Renaming account to '$NewName'..."
    Rename-LocalUser -Name $CurrentUser -NewName $NewName
}
catch {
    Write-Warning "Rename failed: $($_.Exception.Message)"
}

try {
    Write-Host "Setting FullName to '$NewName'..."
    Set-LocalUser -Name $NewName -FullName $NewName
}
catch {
    Write-Warning "FullName set failed: $($_.Exception.Message)"
}

Write-Host "User successfully renamed to: $NewName"
Write-Host "Reboot is recommended."
