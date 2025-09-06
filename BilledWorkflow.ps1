param (
    [switch]$Execute,
    [string]$CallingProgram = "Ukendt"
)

# === Konfiguration ===
$baseRoot         = "\\torenas\homes"
$destinationRoot  = "L:\Billeder\Billedbibliotek" #"J:\Pictures"
$currentYear      = (Get-Date).Year
$logFile          = "$PSScriptRoot\LastRun.log"

# === Logfunktion ===
function Log {
    param (
        [string]$message,
        [switch]$IsError,
        [switch]$Warn,
        [switch]$Success
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($IsError) {
        Write-Host "$timestamp [FEJL] $message" -ForegroundColor Red
    } elseif ($Warn) {
        Write-Host "$timestamp [INFO] $message" -ForegroundColor Yellow
    } elseif ($Success) {
        Write-Host "$timestamp [INFO] $message" -ForegroundColor Green
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
        [string]$logPath,
        [switch]$Executed
    )

    if (!(Test-Path $logPath)) {
        New-Item -ItemType File -Path $logPath -Force | Out-Null
    }

    Add-Content -Path $logPath -Value ""
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "Run: $timestamp"
    Add-Content -Path $logPath -Value "   $user"
    Add-Content -Path $logPath -Value "      $device"

    if ($summary.Count -eq 0) {
        Add-Content -Path $logPath -Value "         Ingen opdateringer"
        return
    }

    Add-Content -Path $logPath -Value "         $year"
	foreach ($key in $summary.Keys | Sort-Object) {
		$value = $summary[$key]

		if ($key -eq "00") {
			$content = "             Ingen billeder i $year"
		}
		elseif ($Executed) {
			$content = "             $key $value er kopieret"
		}
		else {
			if ($value -eq 0) {
				$content = "             $key $value filer allerede kopieret"
			} else {
				$content = "             $key $value nye filer at kopiere"
			}
		}

		Add-Content -Path $logPath -Value $content
	}

    Log "Skrev udvidet summary for $user / $device til logfilen."
}

# === Hovedloop ===
$brugerListe = @("Tore", "Sus")

foreach ($brugerNavn in $brugerListe) {
    $brugerSti = Join-Path $baseRoot $brugerNavn
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
            Log "Ingen billeder for $brugerNavn / $deviceNavn i $currentYear" -Warn

            # Log en tom summary for enheden
            $monthSummary = @{}
            $monthSummary["00"] = "Ingen billeder i $currentYear"
            LogSummary -summary $monthSummary -user $brugerNavn -device $deviceNavn -year $currentYear -logPath $logFile -Executed:$Execute
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
        $seenFolders = @{}
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
                        if (-not $seenFolders.ContainsKey($destPath)) {
                            Log "Folder findes allerede: $destPath"
                            $seenFolders[$destPath] = $true
                        }
                    }

                    $targetFile = Join-Path $destPath $image.Name
						if (!(Test-Path $targetFile)) {
							if ($Execute) {
								try {
									Copy-Item -Path $image.FullName -Destination $targetFile -Force
									$copiedCount++
									Log "Kopierer: '$($image.FullName)' til '$targetFile'" -Success
								} catch {
									Log "Fejl ved kopiering: $_" -Error
								}
							} else {
								$copiedCount++
								Log "Ny fil klar til kopiering: '$($image.FullName)' til '$targetFile'" -Warn
							}
						}
                }

                $monthKey = $month.Name.PadLeft(2, '0')
                $monthSummary[$monthKey] = $copiedCount

            } catch {
                Log "Fejl ved behandling af måned '$($month.Name)': $_" -Error
                continue
            }
        }

        LogSummary -summary $monthSummary -user $brugerNavn -device $deviceNavn -year $currentYear -logPath $logFile -Executed:$Execute
    }
}

# === Log timestamp ===
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $logFile -Value ""
Add-Content -Path $logFile -Value "LastRun: $now ($CallingProgram)"
Log "Logget tidspunkt: $now"