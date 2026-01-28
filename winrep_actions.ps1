[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        "dism_scanhealth",
        "dism_checkhealth",
        "dism_restorehealth",
        "dism_componentcleanup",
        "sfc_scannow",
        "sysinfo",
        "net_reset",
        "wu_reset",
        "temp_cleanup",
        "upgrade_pro",
        "power_high",
        "chkdsk_c",
        "bitlocker_disable",
        "battery_info"
    )]
    [string]$Action
)

$ErrorActionPreference = "Stop"

Write-Output "WinRep PowerShell-Aktionen"
Write-Output "==========================="
Write-Output "Action: $Action"
Write-Output ""

switch ($Action) {

    # -------------------------------------------------------------------------
    # 1: DISM /ScanHealth
    # -------------------------------------------------------------------------
    "dism_scanhealth" {
        Write-Output "Windows Komponentenspeicher wird geprüft (ScanHealth) ..."
        Write-Output ""

        try {
            DISM /Online /Cleanup-Image /ScanHealth
            $code = $LASTEXITCODE
            Write-Output ""
            if ($code -ne 0) {
                Write-Output "DISM /ScanHealth beendet. Rückgabecode: $code"
            } else {
                Write-Output "DISM /ScanHealth erfolgreich abgeschlossen."
            }
            exit $code
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER bei DISM /ScanHealth:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 2: DISM /CheckHealth
    # -------------------------------------------------------------------------
    "dism_checkhealth" {
        Write-Output "Prüfe, ob Windows als beschädigt markiert ist (CheckHealth) ..."
        Write-Output ""

        try {
            DISM /Online /Cleanup-Image /CheckHealth
            $code = $LASTEXITCODE
            Write-Output ""
            if ($code -ne 0) {
                Write-Output "DISM /CheckHealth beendet. Rückgabecode: $code"
            } else {
                Write-Output "DISM /CheckHealth erfolgreich abgeschlossen."
            }
            exit $code
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER bei DISM /CheckHealth:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # DISM /RestoreHealth – mit Klartext-Ergebnis
    # -------------------------------------------------------------------------
    "dism_restorehealth" {
        Write-Output "Automatische Reparatur des Windows-Komponentenspeichers wird durchgeführt ..."
        Write-Output ""

        try {
            $output = DISM /Online /Cleanup-Image /RestoreHealth
            Write-Output $output
            Write-Output ""

            if ($output -match 'Der Wiederherstellungsvorgang wurde erfolgreich abgeschlossen') {
                Write-Output "Ergebnis: Der Windows-Komponentenspeicher wurde erfolgreich repariert."
                exit 0
            }
            elseif ($output -match 'Keine Beschädigung des Komponentenspeichers erkannt') {
                Write-Output "Ergebnis: Keine Beschädigungen gefunden. Keine Reparatur erforderlich."
                exit 0
            }
            elseif ($output -match 'Fehler') {
                Write-Output "Ergebnis: Reparatur fehlgeschlagen."
                Write-Output "Empfehlung: Windows Update / Installationsmedium prüfen."
                exit 2
            }
            else {
                Write-Output "Ergebnis: Unklarer DISM-Status. Bitte Log prüfen."
                exit 1
            }
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER bei DISM RestoreHealth:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 4: DISM StartComponentCleanup
    # -------------------------------------------------------------------------
    "dism_componentcleanup" {
        Write-Output "Abgelöste Startkomponenten werden bereinigt (StartComponentCleanup) ..."
        Write-Output ""

        try {
            DISM /Online /Cleanup-Image /StartComponentCleanup
            $code = $LASTEXITCODE
            if ($code -ne 0) {
                Write-Output "DISM /StartComponentCleanup beendet. Rückgabecode: $code"
            } else {
                Write-Output "DISM /StartComponentCleanup erfolgreich abgeschlossen."
            }
            exit $code
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER bei DISM /StartComponentCleanup:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # SFC /SCANNOW – finale, robuste Auswertung
    # -------------------------------------------------------------------------
    "sfc_scannow" {
        Write-Output "Systemdateien werden mit sfc /scannow geprüft und ggf. repariert ..."
        Write-Output ""

        try {
            # SFC einfach laufen lassen, Ausgabe geht direkt ins Log
            cmd /c "chcp 850 >nul & sfc /scannow"
            $code = $LASTEXITCODE

            Write-Output ""
            Write-Output "sfc /scannow beendet. Rückgabecode: $code"
            exit $code
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER bei sfc /scannow:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # CHKDSK C: – Reparaturmodus beim nächsten Neustart planen
    # -------------------------------------------------------------------------
    "chkdsk_c" {
        Write-Output "CHKDSK-Reparatur für Laufwerk C: wird vorbereitet ..."
        Write-Output ""
        Write-Output "Das Dateisystem wird beim nächsten Neustart überprüft und repariert."
        Write-Output "Hinweis: Der Vorgang kann je nach Laufwerksgröße einige Zeit dauern."
        Write-Output ""

        try {
            # Dirty-Bit setzen -> Windows führt beim nächsten Boot Autochk (CHKDSK /F) aus.
            fsutil dirty set C: | Out-Null

            Write-Output "CHKDSK wurde erfolgreich für den nächsten Systemstart eingeplant."
            Write-Output "Bitte den Computer neu starten, damit die Überprüfung durchgeführt wird."
            exit 0
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER beim Einplanen von CHKDSK:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 6: Systeminformationen → Report auf Desktop + Notepad
    # -------------------------------------------------------------------------
    "sysinfo" {
        Write-Output "Erstelle Systeminformationen-Report auf dem Desktop ..."
        Write-Output ""

        try {
            $desktopPath = [Environment]::GetFolderPath("Desktop")
            $filePath    = Join-Path $desktopPath "WinRep_Systeminfo.txt"

            $os    = Get-CimInstance Win32_OperatingSystem
            $cpu   = Get-CimInstance Win32_Processor | Select-Object -First 1
            $gpus  = Get-CimInstance Win32_VideoController
            $board = Get-CimInstance Win32_BaseBoard | Select-Object -First 1
            $bios  = Get-CimInstance Win32_BIOS | Select-Object -First 1
            $memModules = Get-CimInstance Win32_PhysicalMemory
            $disks = Get-CimInstance Win32_DiskDrive

            $output = @"
Systeminformationen

Betriebssystem
    Edition       = $($os.Caption)
    Build-Nummer  = $($os.Version)

Prozessor
    Name          = $($cpu.Name)
    Kerne/Threads = $($cpu.NumberOfCores) C / $($cpu.NumberOfLogicalProcessors) T
    Sockel        = $($cpu.SocketDesignation)

"@

            if ($gpus) {
                foreach ($gpu in $gpus) {
                    $output += @"
Grafik
    Chip-Name     = $($gpu.Name)
    Treiberversion= $($gpu.DriverVersion)
    Treiberdatum  = $($gpu.DriverDate)

"@
                }
            }

            if ($board -and $bios) {
                $output += @"
Mainboard
    Hersteller    = $($board.Manufacturer)
    Modell        = $($board.Product)
    Seriennummer  = $($board.SerialNumber)
    Revision      = $($board.Version)
    BIOS-Version  = $($bios.SMBIOSBIOSVersion)

"@
            }

            if ($memModules) {
                $output += "Arbeitsspeicher`n"
                foreach ($m in $memModules) {
                    $sizeGB = [math]::Round($m.Capacity / 1GB, 0)
                    $output += @"
    Modul
        Hersteller    = $($m.Manufacturer)
        Modell        = $($m.PartNumber)
        Seriennummer  = $($m.SerialNumber)
        Steckplatz    = $($m.DeviceLocator)
        Speicher      = ${sizeGB} GB
        Taktfrequenz  = $($m.ConfiguredClockSpeed) MHz

"@
                }
            }

            if ($disks) {
                $output += "Laufwerke`n"
                foreach ($disk in $disks) {
                    $sizeGB = [math]::Round($disk.Size / 1GB, 0)

                    $volName = ""
                    $volLetter = ""
                    try {
                        $partitions = Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($disk.DeviceID)'} WHERE AssocClass=Win32_DiskDriveToDiskPartition"
                        foreach ($part in $partitions) {
                            $logical = Get-CimInstance -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($part.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition" | Select-Object -First 1
                            if ($logical) {
                                $volLetter = $logical.DeviceID
                                $volName   = $logical.VolumeName
                                break
                            }
                        }
                    } catch {
                        # ignorieren
                    }

                    $output += @"
    Datenträger
        Modell        = $($disk.Model)
        Größe         = ${sizeGB} GB
        Schnittstelle = $($disk.InterfaceType)
        Laufwerk      = $volLetter
        Volumename    = $volName

"@
                }
            }

            Set-Content -Path $filePath -Encoding UTF8 -Value $output
            Start-Process "notepad.exe" -ArgumentList "`"$filePath`""

            Write-Output ""
            Write-Output "Systeminformationen wurden nach:"
            Write-Output "  $filePath"
            Write-Output "geschrieben und in Notepad geöffnet."
            exit 0
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER beim Erstellen des Systeminfo-Reports:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 7: Netzwerkeinstellungen zurücksetzen
    # -------------------------------------------------------------------------
    "net_reset" {
        Write-Output "Netzwerk-Reset wird ausgeführt ..."
        Write-Output ""

        try {
            # 1) Adapter auf DHCP setzen (IPv4/IPv6/DNS)
            Write-Output "1/6: IPv4/IPv6 & DNS aller aktiven Adapter auf DHCP setzen ..."
            $networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
            foreach ($adapter in $networkAdapters) {
                netsh interface ip set address name="$($adapter.Name)" source=dhcp | Out-Null
                netsh interface ip set dns name="$($adapter.Name)" source=dhcp | Out-Null
                netsh interface ipv6 set dnsservers "$($adapter.Name)" dhcp | Out-Null
            }

            # 2) Winsock-Katalog zurücksetzen
            Write-Output "2/6: Winsock-Katalog zurücksetzen ..."
            netsh winsock reset | Out-Null

            # 3) TCP/IP-Stack zurücksetzen
            Write-Output "3/6: TCP/IP-Einstellungen auf Standard zurücksetzen ..."
            netsh int ip reset | Out-Null

            # 4) IP erneuern + DNS-Cache leeren
            Write-Output "4/6: IP-Adresse erneuern & DNS-Cache leeren ..."
            ipconfig /release  | Out-Null
            ipconfig /renew    | Out-Null
            ipconfig /flushdns | Out-Null

            # 5) Windows-Firewall zurücksetzen
            Write-Output "5/6: Windows-Firewall auf Standardregeln zurücksetzen ..."
            netsh advfirewall reset | Out-Null

            # 6) Proxy zurücksetzen
            Write-Output "6/6: Proxy-Einstellungen zurücksetzen ..."
            netsh winhttp reset proxy | Out-Null

            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
            if (Test-Path $regPath) {
                Set-ItemProperty -Path $regPath -Name AutoConfigURL -Value "" -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $regPath -Name ProxyEnable   -Value 0  -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $regPath -Name AutoDetect    -Value 1  -ErrorAction SilentlyContinue
            }

            Write-Output ""
            Write-Output "Netzwerk-Reset abgeschlossen. Ein Neustart des Systems wird empfohlen."
            exit 0
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER beim Netzwerk-Reset:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 8: Windows Update Komponenten resetten
    # -------------------------------------------------------------------------
    "wu_reset" {
        Write-Output "Windows-Update-Komponenten werden zurückgesetzt ..."
        Write-Output ""

        $ErrorActionPreference = 'SilentlyContinue'

        try {
            attrib -h -r -s "$env:windir\system32\catroot2"      2>$null
            attrib -h -r -s "$env:windir\system32\catroot2\*.*"  2>$null

            Write-Output "• Dienste anhalten (wuauserv, CryptSvc, BITS, msiserver) ..."
            Stop-Service -Name wuauserv -Force
            Stop-Service -Name CryptSvc -Force
            Stop-Service -Name BITS     -Force
            Stop-Service -Name msiserver -Force

            Write-Output "• Cache-Ordner umbenennen ..."
            Rename-Item -Path "$env:windir\SoftwareDistribution" -NewName "SoftwareDistribution.old" -ErrorAction SilentlyContinue
            Rename-Item -Path "$env:windir\system32\catroot2"   -NewName "catroot2.old"             -ErrorAction SilentlyContinue

            Write-Output "• Dienste wieder starten ..."
            Start-Service -Name wuauserv
            Start-Service -Name CryptSvc
            Start-Service -Name BITS
            Start-Service -Name msiserver

            Write-Output ""
            Write-Output "Windows-Update-Komponenten wurden zurückgesetzt."
            exit 0
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER beim Windows-Update-Reset:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 9: Temporäre Dateien bereinigen (Datenträgerbereinigung)
    # -------------------------------------------------------------------------
    "temp_cleanup" {
        Write-Output "Bereinigung temporärer Dateien mit Datenträgerbereinigung ..."
        Write-Output ""

        try {
            $Keys = @(
                "Active Setup Temp Folders",
                "Downloaded Program Files",
                "Internet Cache Files",
                "Memory Dump Files",
                "Old ChkDsk Files",
                "Previous Installations",
                "Recycle Bin",
                "Service Pack Cleanup",
                "Setup Log Files",
                "System error memory dump files",
                "System error minidump files",
                "Temporary Files",
                "Temporary Setup Files",
                "Thumbnail Cache",
                "Update Cleanup",
                "Upgrade Discarded Files",
                "Windows Error Reporting Archive Files",
                "Windows Error Reporting Queue Files",
                "Windows Error Reporting System Archive Files",
                "Windows Error Reporting System Queue Files",
                "Windows Upgrade Log Files"
            )

            $BaseKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

            Write-Output "• Cleanup-Kategorien für cleanmgr (/sagerun:200) aktivieren ..."
            foreach ($Key in $Keys) {
                New-ItemProperty -Path "$BaseKey\$Key" `
                    -Name "StateFlags0200" `
                    -PropertyType DWORD `
                    -Value 0x2 `
                    -Force `
                    -ErrorAction SilentlyContinue | Out-Null
            }

            Write-Output "• Datenträgerbereinigung wird gestartet, dies kann einige Minuten dauern ..."
            Start-Process -Wait -FilePath "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/sagerun:200" -NoNewWindow

            Write-Output ""
            Write-Output "Bereinigung abgeschlossen."
            exit 0
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER bei der Bereinigung:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 10: Upgrade Windows Home -> Pro (generischer Key)
    # -------------------------------------------------------------------------
    "upgrade_pro" {
        Write-Output "Prüfe Windows-Edition für Upgrade auf Pro ..."
        Write-Output ""

        try {
            $OS      = Get-CimInstance Win32_OperatingSystem
            $caption = $OS.Caption
            Write-Output "Gefundene Edition: $caption"
            Write-Output ""

            if ($caption -like "*Windows 10 Home*" -or $caption -like "*Windows 11 Home*") {
                Write-Output "Setze generischen Windows Pro Product Key (Upgrade) ..."
                Changepk.exe /ProductKey VK7JG-NPHTM-C97JM-9MPGT-3V66T
                Write-Output ""
                Write-Output "Der Key wurde gesetzt. Ein Neustart und anschließende Aktivierung sind ggf. erforderlich."
                exit 0
            }
            else {
                Write-Output "Dieses System ist keine unterstützte Home-Edition – Upgrade wird nicht ausgeführt."
                exit 0
            }
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER beim Upgrade-Versuch:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 11: BitLocker auf C: deaktivieren
    # -------------------------------------------------------------------------
    "bitlocker_disable" {
        Write-Output "BitLocker-Verschlüsselung auf Laufwerk C: wird deaktiviert ..."
        Write-Output ""

        try {
            if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) {
                $vol = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction SilentlyContinue
                if (-not $vol) {
                    Write-Output "Für Laufwerk C: wurde kein BitLocker-Volume gefunden."
                    exit 1
                }

                if ($vol.ProtectionStatus -eq 0) {
                    Write-Output "BitLocker ist auf Laufwerk C: bereits deaktiviert."
                    exit 0
                }

                Disable-BitLocker -MountPoint 'C:' | Out-Null
                Write-Output "BitLocker-Deaktivierung wurde gestartet."
                Write-Output "Die Entschlüsselung läuft im Hintergrund und kann je nach Laufwerksgröße lange dauern."
                exit 0
            }
            else {
                Write-Output "BitLocker-Cmdlets sind auf diesem System nicht verfügbar."
                exit 1
            }
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER bei der BitLocker-Deaktivierung:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 11: Performance / Höchstleistungsmodus + CPU/USB/Buttons-Optimierung
    # -------------------------------------------------------------------------
    "power_high" {
        Write-Output "Performance-Optimierung wird ausgeführt ..."
        Write-Output ""

        try {
            # Energiesparplan: Höchstleistung aktivieren (GUID 8c5e7fda-...)
            $planGUID    = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
            $powerPlans  = powercfg.exe /list
            $planExists  = $powerPlans -match $planGUID

            if (-not $planExists) {
                Write-Output "• Höchstleistungsplan nicht gefunden – Standardplan wird dupliziert ..."
                powercfg -duplicatescheme "$planGUID" | Out-Null 2>$null
            }

            Write-Output "• Aktiviere Höchstleistungs-Energieplan ..."
            # PreferredPlan in der Systemsteuerung setzen (optional, für UI)
            Set-ItemProperty `
                -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\explorer\ControlPanel\NameSpace\{025A5937-A6BE-4686-A844-36FE4BEC8B6D}' `
                -Name PreferredPlan `
                -Value $planGUID `
                -ErrorAction SilentlyContinue

            powercfg -setactive $planGUID | Out-Null

            # Ruhezustand deaktivieren
            Write-Output "• Deaktiviere Ruhezustand ..."
            powercfg -hibernate off | Out-Null

            # Mindest-CPU-Zustand
            Write-Output "• Optimiere Mindest-CPU-Zustand [AC: 50% | DC: 5%] ..."
            # Subgroup: Prozessorenergieverwaltung
            # Setting: Mindestprozessorzustand
            $subProcessor = "54533251-82be-4824-96c1-47b60b740d00"
            $setMinProc   = "893dee8e-2bef-41e0-89c6-b55d0929964c"
            powercfg -SETACVALUEINDEX SCHEME_CURRENT $subProcessor $setMinProc 50 | Out-Null
            powercfg -SETDCVALUEINDEX SCHEME_CURRENT $subProcessor $setMinProc 5  | Out-Null

            # Core Parking
            Write-Output "• Optimiere Core Parking [AC: 100% | DC: 50%] ..."
            # Setting: Prozessor-Leerlaufzustand – Minimaler Prozessorzustand für Core-Parking
            $setCoreParking = "0cc5b647-c1df-4637-891a-dec35c318583"
            powercfg -SETACVALUEINDEX SCHEME_CURRENT $subProcessor $setCoreParking 100 | Out-Null
            powercfg -SETDCVALUEINDEX SCHEME_CURRENT $subProcessor $setCoreParking 50  | Out-Null

            # Festplatten-Timeout
            Write-Output "• Optimiere Festplatten-Timeout [AC: 0 Minuten | DC: 15 Minuten] ..."
            powercfg -change -disk-timeout-ac 0  | Out-Null
            powercfg -change -disk-timeout-dc 15 | Out-Null

            # USB selektiver Energiesparmodus
            Write-Output "• Optimiere USB-Selektivmodus [AC: Aus | DC: Ein] ..."
            $subUsb    = "2a737441-1930-4402-8d77-b2bebba308a3"
            $setUsbSel = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
            powercfg -SETACVALUEINDEX SCHEME_CURRENT $subUsb $setUsbSel 0 | Out-Null  # aus
            powercfg -SETDCVALUEINDEX SCHEME_CURRENT $subUsb $setUsbSel 1 | Out-Null  # ein

            # Monitor- und Standby-Timeout
            Write-Output "• Optimiere Monitor/Standby-Timeout [AC: 0 Min | DC: 10 Min (Monitor)] ..."
            powercfg -change -standby-timeout-ac 0  | Out-Null
            powercfg -change -standby-timeout-dc 0  | Out-Null
            powercfg -change -monitor-timeout-ac 0  | Out-Null
            powercfg -change -monitor-timeout-dc 10 | Out-Null

            # Tasten-/Deckel-Aktionen (sub_buttons)
            $subButtons = "sub_buttons"

            Write-Output "• Optimiere Aktion beim Schließen des Notebook-Deckels [AC/DC: Nichts tun] ..."
            $lidAction = "5ca83367-6e45-459f-a27b-476b1d01c936"
            powercfg -setdcvalueindex scheme_current $subButtons $lidAction 0 | Out-Null
            powercfg -setacvalueindex scheme_current $subButtons $lidAction 0 | Out-Null

            Write-Output "• Optimiere Schlaftaste [AC/DC: Nichts tun] ..."
            $sleepAction = "96996bc0-ad50-47ec-923b-6f41874dd9eb"
            powercfg -setdcvalueindex scheme_current $subButtons $sleepAction 0 | Out-Null
            powercfg -setacvalueindex scheme_current $subButtons $sleepAction 0 | Out-Null

            Write-Output "• Optimiere Ein-/Ausschalter [AC/DC: Herunterfahren] ..."
            $powerButton = "7648efa3-dd9c-4e3e-b566-50f929386280"
            powercfg -setdcvalueindex scheme_current $subButtons $powerButton 3 | Out-Null
            powercfg -setacvalueindex scheme_current $subButtons $powerButton 3 | Out-Null

            # Optionale weitere Tasten-/UI-Anpassung wie im Original
            $extraButtons = "a7066653-8d6c-40a8-910e-a1f54b84c7e5"
            powercfg -setdcvalueindex scheme_current $subButtons $extraButtons 2 | Out-Null
            powercfg -setacvalueindex scheme_current $subButtons $extraButtons 2 | Out-Null

            # Aktuellen Plan mit allen Änderungen aktiv setzen
            powercfg /setactive SCHEME_CURRENT | Out-Null

            # Hintergrund-Apps deaktivieren (wie im Originalscript)
            Write-Output "• Deaktiviere Hintergrundzugriff für ausgewählte Apps ..."
            $apps = @(
                "Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe",
                "Microsoft.Microsoft3DViewer_8wekyb3d8bbwe",
                "Microsoft.WindowsAlarms_8wekyb3d8bbwe",
                "Microsoft.WindowsCalculator_8wekyb3d8bbwe",
                "Microsoft.WindowsCamera_8wekyb3d8bbwe",
                "Microsoft.549981C3F5F10_8wekyb3d8bbwe",
                "Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe",
                "Microsoft.GetHelp_8wekyb3d8bbwe",
                "Microsoft.ZuneMusic_8wekyb3d8bbwe",
                "microsoft.windowscommunicationsapps_8wekyb3d8bbwe",
                "Microsoft.WindowsMaps_8wekyb3d8bbwe",
                "Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe",
                "Microsoft.WindowsStore_8wekyb3d8bbwe",
                "Microsoft.ZuneVideo_8wekyb3d8bbwe",
                "Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe",
                "Microsoft.Office.OneNote_8wekyb3d8bbwe",
                "Microsoft.MSPaint_8wekyb3d8bbwe",
                "Microsoft.People_8wekyb3d8bbwe",
                "Microsoft.Windows.Photos_8wekyb3d8bbwe",
                "windows.immersivecontrolpanel_cw5n1h2txyewy",
                "Microsoft.SkypeApp_kzf8qxf38zg5c",
                "Microsoft.ScreenSketch_8wekyb3d8bbwe",
                "Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe",
                "Microsoft.Getstarted_8wekyb3d8bbwe",
                "Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe",
                "Microsoft.BingWeather_8wekyb3d8bbwe",
                "Microsoft.XboxApp_8wekyb3d8bbwe",
                "Microsoft.YourPhone_8wekyb3d8bbwe",
                "Microsoft.MixedReality.Portal_8wekyb3d8bbwe",
                "Microsoft.Xbox.TCUI_8wekyb3d8bbwe"
            )

            foreach ($app in $apps) {
                $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\$app"
                if (!(Test-Path $path)) {
                    New-Item -Path $path -Force | Out-Null
                }
                Set-ItemProperty -Path $path -Name "Disabled"      -Value 1 -Type DWord
                Set-ItemProperty -Path $path -Name "DisabledByUser" -Value 1 -Type DWord
            }

            Write-Output ""
            Write-Output "Performance-Optimierung abgeschlossen."
            Write-Output "Hinweis: Einige Einstellungen (Tasten/Deckel) wirken sich v. a. auf Notebooks aus."
            exit 0
        }
        catch {
            Write-Output ""
            Write-Output "FEHLER bei der Performance-Optimierung:"
            Write-Output $_.Exception.Message
            exit 1
        }
    }
    # -------------------------------------------------------------------------
    # 12: Akkuinformationen anzeigen
    # -------------------------------------------------------------------------
    "battery_info" {
    Write-Output "Akkuzustand wird analysiert ..."
    Write-Output ""

    try {
        # Prüfen, ob überhaupt ein Akku vorhanden ist
        $bat = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if (-not $bat) {
            Write-Output "Es wurde kein Akku gefunden (Desktop-PC oder kein Akku verbaut)."
            exit 0
        }

        # Desktop ermitteln
        $desktop = [Environment]::GetFolderPath('Desktop')
        if (-not $desktop) {
            $desktop = "$env:USERPROFILE\Desktop"
        }

        $reportName = "CLS-BatteryReport.html"
        $reportPath = Join-Path $desktop $reportName

        Write-Output "Erstelle Windows-Batteriereport ..."
        Write-Output "  Ziel: $reportPath"
        Write-Output ""

        # Battery-Report erstellen (überschreibt vorhandenen Report)
        $null = powercfg /batteryreport /output "$reportPath" /format HTML 2>$null

        # Schnell-Daten aus WMI/WMI ermitteln
        $static = Get-WmiObject -Class "BatteryStaticData" -Namespace "ROOT\WMI" -ErrorAction SilentlyContinue | Select-Object -First 1
        $full   = Get-WmiObject -Class "BatteryFullChargedCapacity" -Namespace "ROOT\WMI" -ErrorAction SilentlyContinue | Select-Object -First 1
        $cycle  = Get-WmiObject -Class "BatteryCycleCount" -Namespace "ROOT\WMI" -ErrorAction SilentlyContinue | Select-Object -First 1

        if (-not $static -and -not $full) {
            Write-Output "Es konnten keine detaillierten Akkudaten aus WMI gelesen werden."
            Write-Output ""
            Write-Output "Der Windows-Batteriereport wurde auf dem Desktop gespeichert:"
            Write-Output "  $reportPath"
            exit 0
        }

        $design  = $static.DesignedCapacity
        $fullCap = $full.FullChargedCapacity

        $health = $null
        if ($design -and $fullCap -and $design -gt 0) {
            $health = [math]::Round(($fullCap * 100.0 / $design), 1)
        }

        Write-Output "Schnellübersicht Akkuzustand:"
        if ($design)  { Write-Output ("  Designkapazität:        {0} mWh" -f $design) }
        if ($fullCap) { Write-Output ("  Volle Ladekapazität:    {0} mWh" -f $fullCap) }

        if ($health -ne $null) {
            Write-Output ("  Akkugesundheit:         {0} %" -f $health)

            $rating = if ($health -ge 90) {
                "sehr gut"
            }
            elseif ($health -ge 80) {
                "gut"
            }
            elseif ($health -ge 65) {
                "noch akzeptabel"
            }
            else {
                "kritisch – Akkutausch empfohlen"
            }

            Write-Output ("  Bewertung:              {0}" -f $rating)
        }

        if ($cycle -and $cycle.CycleCount -ne $null) {
            Write-Output ("  Ladezyklen (laut Firmware): {0}" -f $cycle.CycleCount)
        }

        Write-Output ""
        Write-Output "Hinweis:"
        Write-Output "Der vollständige Windows-Batteriereport wurde auf dem Desktop gespeichert:"
        Write-Output "  $reportPath"

        exit 0
    }
    catch {
        Write-Output ""
        Write-Output "FEHLER beim Ermitteln des Akkuzustands:"
        Write-Output $_.Exception.Message
        exit 1
    }
    }
}
