param (
    [switch]$Execute
)

# === Opsætning ===
$sourceRoot = "\\torenas\Homes\Tore\Photos\MobileBackup\Pixel 8a"  # Justér IP/navn
$destinationRoot = "J:\Pictures"
$currentYear = (Get-Date).Year

# === Logning ===
function Log {
    param ([string]$message, [switch]$Error)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($Error) {
        Write-Host "$timestamp [FEJL] $message" -ForegroundColor Red
    } else {
        Write-Host "$timestamp [INFO] $message"
    }
}

# === Tjek adgang ===
if (!(Test-Path $sourceRoot)) {
    Log "Kan ikke tilgå stien: $sourceRoot" -Error
    return
}

Log "Test lykkedes – adgang til: $sourceRoot"

# === Ekstra test: Find 2025-mappe under DCIM\Camera ===
$cameraPath = Join-Path $sourceRoot "DCIM\Camera"
$yearPath = Join-Path $cameraPath "$currentYear"

if (!(Test-Path $yearPath)) {
    Log "Ingen mappe for året $currentYear i: $cameraPath" -Error
    return
}

Log "Fandt stien for kamera og aar: " + $yearPath + "