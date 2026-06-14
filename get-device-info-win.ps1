# CNS IT - Device Info Collector (Windows)
# Right-click RUN-Device-Info.bat then Run as Administrator

Clear-Host
Write-Host "=====================================================" -ForegroundColor DarkYellow
Write-Host "   CNS IT - Device Info Collector (Windows)           " -ForegroundColor DarkYellow
Write-Host "=====================================================" -ForegroundColor DarkYellow
Write-Host ""
Write-Host "Gathering device info..." -ForegroundColor Gray
Write-Host ""

# Model
try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $Model = ($cs.Manufacturer + " " + $cs.Model).Trim()
} catch { $Model = "Unknown" }

# Serial Number
try {
    $Serial = (Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop).SerialNumber
} catch { $Serial = "Unknown" }

# MAC Address
# MAC Addresses (Wi-Fi and Ethernet, internal only - exclude USB and virtual)
$WifiMac = ""
$EthMac = ""
try {
    $allAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {
        $_.InterfaceDescription -notmatch "Virtual|Bluetooth|VPN|TAP|Loopback|VMware|Hyper-V" -and
        $_.HardwareInterface -eq $true -and
        $_.PnPDeviceID -notmatch "^USB"
    }
    # Wi-Fi adapter
    $wifi = $allAdapters | Where-Object {
        $_.PhysicalMediaType -eq "Native 802.11" -or $_.InterfaceDescription -match "Wi-?Fi|Wireless|802\.11"
    } | Select-Object -First 1
    if ($wifi) { $WifiMac = $wifi.MacAddress -replace "-", ":" }

    # Ethernet adapter
    $eth = $allAdapters | Where-Object {
        $_.PhysicalMediaType -eq "802.3" -or $_.InterfaceDescription -match "Ethernet|Gigabit|GBE|RJ-?45"
    } | Where-Object {
        $_.InterfaceDescription -notmatch "Wi-?Fi|Wireless|802\.11"
    } | Select-Object -First 1
    if ($eth) { $EthMac = $eth.MacAddress -replace "-", ":" }
} catch { }

# Build display string
if ($WifiMac -and $EthMac) {
    $MacAddr = "Wi-Fi: $WifiMac  |  Ethernet: $EthMac"
} elseif ($WifiMac) {
    $MacAddr = "Wi-Fi: $WifiMac"
} elseif ($EthMac) {
    $MacAddr = "Ethernet: $EthMac"
} else {
    $MacAddr = "Unknown"
}

# OS Version
try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $OSName = $os.Caption -replace "Microsoft ", ""
    $OSBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).DisplayVersion
} catch { $OSName = "Windows"; $OSBuild = "" }

# BitLocker Status
try {
    $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
    if ($bl.ProtectionStatus -eq "On") {
        $pct = [string]$bl.EncryptionPercentage
        $Encryption = "BitLocker: On (" + $pct + " percent)"
    } else {
        $Encryption = "BitLocker: Off"
    }
} catch {
    $Encryption = "BitLocker: Unknown"
}

# Computer Name
$CompName = $env:COMPUTERNAME

# IP Address
try {
    $IP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch "^(127\.|169\.254)" } | Select-Object -First 1).IPAddress
} catch { $IP = "Unknown" }

# UT Tag (last 6 characters of computer name)
$UTTag = ""
if ($CompName.Length -ge 6) {
    $UTTag = $CompName.Substring($CompName.Length - 6)
} else {
    $UTTag = $CompName
}

# === OUTPUT ===
$line = "======================================================"
Write-Host $line -ForegroundColor DarkYellow
Write-Host "  DEVICE INFO - COPY INTO DEPLOYMENT FORM" -ForegroundColor White
Write-Host $line -ForegroundColor DarkYellow
Write-Host ""
Write-Host "  Model:        $Model" -ForegroundColor Cyan
Write-Host "  Serial:       $Serial" -ForegroundColor Cyan
if ($WifiMac) { Write-Host "  Wi-Fi MAC:    $WifiMac" -ForegroundColor Cyan }
if ($EthMac)  { Write-Host "  Ethernet MAC: $EthMac" -ForegroundColor Cyan }
if (-not $WifiMac -and -not $EthMac) { Write-Host "  MAC Address:  Unknown" -ForegroundColor Cyan }
Write-Host "  OS:           $OSName $OSBuild" -ForegroundColor Cyan
Write-Host "  Encryption:   $Encryption" -ForegroundColor Cyan
Write-Host "  Computer:     $CompName" -ForegroundColor Cyan
Write-Host "  UT Tag:       $UTTag" -ForegroundColor Yellow
Write-Host "  IP Address:   $IP" -ForegroundColor Cyan
Write-Host ""
Write-Host $line -ForegroundColor DarkYellow

# Save to USB drive
$usbDrive = ""
$removable = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 2 } | Select-Object -First 1
if ($removable) {
    $usbDrive = $removable.DeviceID + "\"
}
if ($usbDrive) {
    $usbDir = $usbDrive + "Windows deployed"
    if (-not (Test-Path $usbDir)) { New-Item -ItemType Directory -Path $usbDir -Force | Out-Null }
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $outFile = $usbDir + "\device-info-" + $CompName + "-" + $timestamp + ".txt"
    try {
        $lines = @(
            ("CNS IT Device Info - " + (Get-Date).ToString()),
            ("Model: " + $Model),
            ("Serial: " + $Serial)
        )
        if ($WifiMac) { $lines += ("Wi-Fi MAC: " + $WifiMac) }
        if ($EthMac)  { $lines += ("Ethernet MAC: " + $EthMac) }
        if (-not $WifiMac -and -not $EthMac) { $lines += "MAC Address: Unknown" }
        $lines += @(
            ("OS: " + $OSName + " " + $OSBuild),
            ("Encryption: " + $Encryption),
            ("Computer Name: " + $CompName),
            ("UT Tag: " + $UTTag),
            ("IP: " + $IP)
        )
        $lines | Out-File -FilePath $outFile -Encoding UTF8
        Write-Host ""
        Write-Host "  Saved to USB: $outFile" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "  (Could not save to USB)" -ForegroundColor Gray
    }
} else {
    Write-Host ""
    Write-Host "  (No USB drive detected)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Press Enter to close..." -ForegroundColor Gray
Read-Host
