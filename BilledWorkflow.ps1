<#
.SYNOPSIS
  Kopierer billeder fra brugeres mobil-backupmapper til J-drevet med datostruktur.

.DESCRIPTION
  Scriptet håndterer flere brugere og flere devices pr. bruger. Den scanner automatisk:
    \\torenas\homes\<bruger>\Photos\MobileBackup\<device>\DCIM\Camera\<år>

  Filer kopieres til:
    J:\Pictures\<år>\<dato>\fil.jpg

.PARAMETER Execute
  Udfører reelle handlinger: kopierer filer og opretter mapper.
  Uden parameter køres scriptet som tørkørsel.

.EXAMPLE
  .\MultiUserWorkflow.ps1 -Execute
#>

param (
    [switch]$Execute
)

# === Konfiguration ===
$baseRoot         = "\\torenas\homes"
$destinationRoot  = "J:\Pictures"
$currentYear      = (Get-Date).Year
$logFile          = "$PSScriptRoot\LastRun.log"

# === Logfunktion ===
function Log {
    param ([string]$message, [switch]$Error)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($Error) {
        Write-Host "$timestamp [FEJL] $message" -ForegroundColor Red
    } else {
        Write-Host "$timestamp [INFO] $message"
    }
}

# === Summaryfunktion ===
function LogSummary {
    param (
        [hashtable]$summary,
        [string]$user,
        [string]$device,
        [string]$year,
        [string]$logPath
    )
    Add-Content -Path $logPath -Value ""
    Add-Content -Path $logPath -Value "Bruger: ${user}"
    Add-Content -Path $logPath -Value "Enhed: ${device}"
    Add-Content -Path $logPath -Value "Summary for år ${year}:"
    foreach ($key in $summary.Keys | Sort-Object) {
        Add-Content -Path $logPath -Value $summary[$key]
    }
    Log "Skrev summary for $user / $device til logfilen."
}

# === Hovedloop: Find alle brugere og enheder ===
$brugerListe = @("Tore", "Sus")

foreach ($brugerNavn in $brugerListe) {
	$brugerSti = Join-Path $baseRoot $brugerNavn

    $brugerNavn = $brugerMappe.Name
    $mobileBackupPath = Join-Path $brugerSti "Photos\MobileBackup"

    if (!(Test-Path $mobileBackupPath)) {
        Log "Brugeren '$brugerNavn' har ingen MobileBackup-mappe." -Error
        continue
    }

    $deviceMapper = Get-ChildItem -Path $mobileBackupPath -Directory
    foreach ($deviceMappe in $deviceMapper) {
        $deviceNavn = $deviceMappe.Name
        $cameraPath = Join-Path $deviceMappe.FullName "DCIM\Camera\$currentYear"
        if (!(Test-Path $cameraPath)) {
            Log "Ingen billeder for $brugerNavn / $deviceNavn i $currentYear" -Error
            continue
        }

        Log "Behandler: $brugerNavn / $deviceNavn"
        try {
            $monthFolders = Get-ChildItem -Path $cameraPath -Directory
        } catch {
            Log "Fejl ved læsning af månedmapper: $_" -Error
            continue
        }

        $monthSummary = @{}
        foreach ($month in $monthFolders) {
            try {
                $imageFiles = Get-ChildItem -Path $month.FullName -File | Where-Object {
                    $_.Extension.ToLower() -match '\.(jpg|jpeg|png|heic|webp|mp4)$'
                }
                Log "Fandt $($imageFiles.Count) filer i måned: $($month.Name)"

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
                    $monthSummary[$monthKey] = "$monthKey Fandt $copiedCount nye filer"
                }

            } catch {
                Log "Fejl ved behandling af måned '$($month.Name)': $_" -Error
                continue
            }
        }

        # Tilføj summary for denne bruger/enhed
        LogSummary -summary $monthSummary -user $brugerNavn -device $deviceNavn -year $currentYear -logPath $logFile
    }
}

# === Log timestamp ===
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value ""
Add-Content -Path $logFile -Value "LastRun: $now"
Log "Logget tidspunkt: $now"