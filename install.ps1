# === SETTINGS ===
$OldUser = (Get-WmiObject Win32_ComputerSystem).UserName.Split("\")[-1]
$OldUserNewName = Read-Host "Enter new Username"
$OldUserPassword = "1111"

$AdminUser = "admin"
$AdminPassword = "298377"

Write-Host "Current logged-in user detected: $OldUser"


# === 1. Rename current user + set password + remove from Administrators ===

Write-Host "Renaming user $OldUser → $OldUserNewName"
wmic useraccount where "Name='$OldUser'" rename $OldUserNewName

Write-Host "Setting password for $OldUserNewName"
net user $OldUserNewName $OldUserPassword

Write-Host "Removing $OldUserNewName from Administrators"
net localgroup Administrators $OldUserNewName /delete 2>$null


# === 2. Create admin account ===

Write-Host "Creating admin account $AdminUser"
net user $AdminUser $AdminPassword /add

Write-Host "Adding admin account to Administrators"
net localgroup Administrators $AdminUser /add


# === 3. SOFTWARE RESTRICTION POLICIES (SRP) ===

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

Add-SRP-Rule "{11111111-1111-1111-1111-111111111111}" "%USERPROFILE%\Desktop\*"
Add-SRP-Rule "{22222222-2222-2222-2222-222222222222}" "%USERPROFILE%\Downloads\*"

Write-Host "SRP policy applied. A reboot is recommended."
