<#
.SYNOPSIS
  Kopierer billeder og videoer fra Pixel-backup (NAS) til lokal billedstruktur.

.DESCRIPTION
  Scriptet gennemgår undermapper for indeværende år og sorterer filer efter oprettelsesdato.
  Den opretter mapper automatisk under J:\Pictures som:
      J:\Pictures\<år>\<yyyy-MM-dd>\

  Følgende filtyper håndteres:
    - jpg
    - jpeg
    - png
    - heic
    - webp
    - mp4
    (case-insensitive)

.PARAMETER Execute
  Udfører reelle handlinger: mapper oprettes og filer kopieres.
  Uden denne parameter kører scriptet som en tørkørsel (kun visning/logning).

.EXAMPLE
  .\BilledWorkflow.ps1
    Vis hvad scriptet ville gøre — uden at ændre filer

  .\BilledWorkflow.ps1 -Execute
    Udfør kopiering og mappeoprettelse på J-drevet

.NOTES
  - Logfilen LastRun.log indeholder tidspunkt for sidste kørsel
  - Logningen viser:
      • Fejlbeskeder i rød tekst
      • Information om fundne mapper, antal filer og handlinger
      • Spring af eksisterende filer
      • Hvilke filer kopieres og hvorhen

.AUTHOR
  Tore
#>

param (
    [switch]$Execute
)

# === Opsætning ===
$sourceRoot = "\\torenas\homes\Tore\Photos\MobileBackup\Pixel 8a"
$destinationRoot = "J:\Pictures"
$currentYear = (Get-Date).Year
$logFile = "$PSScriptRoot\LastRun.log"

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

# === Månedsopsummering ===
function LogSummary {
    param (
        [hashtable]$summary,
        [string]$year,
        [string]$logPath
    )

    Add-Content -Path $logPath -Value ""
    Add-Content -Path $logPath -Value "Summary for år ${year}:"
    foreach ($key in $summary.Keys | Sort-Object) {
        Add-Content -Path $logPath -Value $summary[$key]
    }

    Log "Skrev månedsoversigt til logfil: $logPath"
}

# === Hent filsti til Camera-mappe ===
$cameraPath = Join-Path $sourceRoot "DCIM\Camera"
if (!(Test-Path $cameraPath)) {
    Log "Kamera-stien '$cameraPath' findes ikke." -Error
    return
}
Log "Kamera-sti fundet: $cameraPath"

# === Gennemgå undermapper for året ===
$yearPath = Join-Path $cameraPath "$currentYear"
if (!(Test-Path $yearPath)) {
    Log "Der er ingen mappe for året $currentYear i '$cameraPath'" -Error
    return
}
Log "Årstalsmappe fundet: $yearPath"

try {
    $monthFolders = Get-ChildItem -Path $yearPath -Directory
} catch {
    Log "Fejl ved læsning af månedmapper: $_" -Error
    return
}

$monthSummary = @{}

foreach ($month in $monthFolders) {
    try {
        $imageFiles = Get-ChildItem -Path $month.FullName -File | Where-Object {
            $_.Extension.ToLower() -match '\.(jpg|jpeg|png|heic|webp|mp4)$'
        }
        Log "Fandt $($imageFiles.Count) filer i måned: $($month.Name)"
    } catch {
        Log "Fejl ved læsning af billeder i '$($month.FullName)': $_" -Error
        continue
    }

    $copiedCount = 0

    foreach ($image in $imageFiles) {
        $dateFolder = $image.CreationTime.ToString("yyyy-MM-dd")
        $yearFolder = $image.CreationTime.Year
        if ($yearFolder -ne $currentYear) { continue }

        $destPath = Join-Path $destinationRoot "$yearFolder\$dateFolder"
        if (!(Test-Path $destPath)) {
            Log "Vil oprette folder: $destPath"
            if ($Execute) {
                try {
                    New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                } catch {
                    Log "Fejl ved oprettelse af folder '$destPath': $_" -Error
                    continue
                }
            }
        } else {
            Log "Folder findes allerede: $destPath"
        }

        $targetFile = Join-Path $destPath $image.Name
        if (!(Test-Path $targetFile)) {
            Log "Vil kopiere: '$($image.FullName)' til '$targetFile'"
            if ($Execute) {
                try {
                    Copy-Item -Path $image.FullName -Destination $targetFile -Force
                    $copiedCount++
                } catch {
                    Log "Fejl ved kopiering: $_" -Error
                }
            }
        } else {
            Log "Springer over, da filen allerede findes: $targetFile"
        }
    }

    $monthKey = $month.Name.PadLeft(2, '0')
    if ($copiedCount -eq 0) {
        $monthSummary[$monthKey] = "$monthKey Ingen tilføjelser"
    } else {
        $monthSummary[$monthKey] = "$monthKey Fandt $copiedCount nye filer som blev kopieret"
    }
}

# === Log timestamp og summary ===
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
try {
    Add-Content -Path $logFile -Value ""
	Add-Content -Path $logFile -Value "LastRun: $now"

    Log "Logget tidspunkt for sidste kørsel: $now"
    LogSummary -summary $monthSummary -year $currentYear -logPath $logFile
} catch {
    Log "Fejl ved skrivning af logfil." -Error
}