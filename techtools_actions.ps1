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
        "battery_info",
        "device_driver_check",
        "disk_space_check",
        "pending_reboot_check",
        "disk_health_check",
        "disk_event_check",
        "network_diag",
        "wu_diag",
        "event_diag",
        "security_status",
        "dump_check",
        "startup_overview",
        "service_diag",
        "printer_diag",
        "printer_queue_clear",
        "printer_test_page",
        "time_diag",
        "time_resync",
        "report_export",
        "secureboot_ca_install"
    )]
    [string]$Action
)

$ErrorActionPreference = "Stop"

Write-Output "TechTools PowerShell-Aktionen"
Write-Output "==========================="
Write-Output "Action: $Action"
Write-Output ""

function Write-ToolStatus {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("OK", "INFO", "WARNUNG", "KRITISCH", "FEHLER")]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Output ("[{0}] {1}" -f $Level, $Message)
}

function Format-ToolSize {
    param([Nullable[double]]$Bytes)

    if ($null -eq $Bytes) { return "Nicht verfügbar" }
    if ($Bytes -ge 1TB) { return ("{0:N1} TB" -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ("{0:N1} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N1} MB" -f ($Bytes / 1MB)) }
    return ("{0:N0} B" -f $Bytes)
}

function Get-DeviceProblemText {
    param([int]$Code)

    switch ($Code) {
        1  { "Gerät ist nicht korrekt konfiguriert." }
        10 { "Gerät kann nicht gestartet werden." }
        18 { "Treiber sollte neu installiert werden." }
        22 { "Gerät ist deaktiviert." }
        24 { "Gerät ist nicht vorhanden oder funktioniert nicht korrekt." }
        28 { "Für dieses Gerät ist kein Treiber installiert." }
        31 { "Ein benÖer Treiber kann nicht geladen werden." }
        32 { "Der Treiberdienst ist deaktiviert." }
        43 { "Das Gerät hat Windows einen Fehler gemeldet." }
        45 { "Gerät ist derzeit nicht angeschlossen." }
        48 { "Treiber wurde wegen Problemen blockiert." }
        52 { "Digitale Signatur kann nicht Ü werden." }
        default { "Windows meldet Problemcode $Code." }
    }
}

function Get-DeviceProblemLevel {
    param([int]$Code)

    switch ($Code) {
        22 { "INFO" }
        45 { "INFO" }
        43 { "KRITISCH" }
        default { "WARNUNG" }
    }
}

function Test-PendingRebootReason {
    $reasons = New-Object System.Collections.Generic.List[string]

    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $reasons.Add("Component Based Servicing")
    }
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $reasons.Add("Windows Update")
    }

    $sessionManager = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -ErrorAction SilentlyContinue
    if ($sessionManager -and $sessionManager.PendingFileRenameOperations) {
        $reasons.Add("Ausstehende Dateioperationen")
    }

    $computerName = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -ErrorAction SilentlyContinue
    $activeName = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" -ErrorAction SilentlyContinue
    if ($computerName -and $activeName -and $computerName.ComputerName -ne $activeName.ComputerName) {
        $reasons.Add("Computerumbenennung")
    }

    return $reasons
}

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
    # DISM /RestoreHealth - mit Klartext-Ergebnis
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
    # SFC /SCANNOW - finale, robuste Auswertung
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
    # CHKDSK C: - Reparaturmodus beim nächsten Neustart planen
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
            $filePath    = Join-Path $desktopPath "TechTools_Systeminfo.txt"

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
                Write-Output "Dieses System ist keine unterstützte Home-Edition - Upgrade wird nicht ausgeführt."
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
                Write-Output "• Höchstleistungsplan nicht gefunden - Standardplan wird dupliziert ..."
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
            powercfg -SETACVALUEINDEX SCHEME_CURRENT $subProcessor $setMinProc 5 | Out-Null
            powercfg -SETDCVALUEINDEX SCHEME_CURRENT $subProcessor $setMinProc 5  | Out-Null

            # Core Parking
            Write-Output "• Optimiere Core Parking [AC: 100% | DC: 50%] ..."
            # Setting: Prozessor-Leerlaufzustand - Minimaler Prozessorzustand für Core-Parking
            $setCoreParking = "0cc5b647-c1df-4637-891a-dec35c318583"
            powercfg -SETACVALUEINDEX SCHEME_CURRENT $subProcessor $setCoreParking 50 | Out-Null
            powercfg -SETDCVALUEINDEX SCHEME_CURRENT $subProcessor $setCoreParking 30  | Out-Null

            # Processor Performance Decrease Time
            Write-Output "• Optimiere CPU Decrease Time [AC: 1500ms | DC: 750ms] ..."
            $setDecreaseTime = "4d2b0152-7d5c-498b-88e2-34345392a2c5"
            powercfg -SETACVALUEINDEX SCHEME_CURRENT $subProcessor $setDecreaseTime 1500 | Out-Null
            powercfg -SETDCVALUEINDEX SCHEME_CURRENT $subProcessor $setDecreaseTime 750  | Out-Null

            # Processor Performance Decrease Threshold
            Write-Output "• Optimiere CPU Decrease Threshold [AC: 20% | DC: 20%] ..."
            $setDecreaseThreshold = "12a0ab44-fe28-4fa9-b3bd-4b64f44960a6"
            powercfg -SETACVALUEINDEX SCHEME_CURRENT $subProcessor $setDecreaseThreshold 20 | Out-Null
            powercfg -SETDCVALUEINDEX SCHEME_CURRENT $subProcessor $setDecreaseThreshold 20 | Out-Null

            # Processor Performance Increase Time
            Write-Output "• Optimiere CPU Increase Time [AC: 200ms | DC: 200ms] ..."
            $setIncreaseTime = "984cf492-3bed-4488-a8f9-4286f832755"
            powercfg -SETACVALUEINDEX SCHEME_CURRENT $subProcessor $setIncreaseTime 200 | Out-Null
            powercfg -SETDCVALUEINDEX SCHEME_CURRENT $subProcessor $setIncreaseTime 200 | Out-Null

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

        if ($true) {
            $batteries = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
            if (-not $batteries) {
                Write-ToolStatus "INFO" "Kein Akku erkannt - Akkudiagnose wurde übersprungen."
                exit 0
            }

            $desktop = [Environment]::GetFolderPath('Desktop')
            if (-not $desktop) { $desktop = "$env:USERPROFILE\Desktop" }

            $reportName = "SD-ITLab-BatteryReport.html"
            $reportPath = Join-Path $desktop $reportName

            Write-Output "Erstelle Windows-Batteriereport ..."
            Write-Output "  Ziel: $reportPath"
            Write-Output ""
            $null = powercfg /batteryreport /output "$reportPath" /format HTML 2>$null

            $staticItems = @(Get-WmiObject -Class "BatteryStaticData" -Namespace "ROOT\WMI" -ErrorAction SilentlyContinue)
            $fullItems   = @(Get-WmiObject -Class "BatteryFullChargedCapacity" -Namespace "ROOT\WMI" -ErrorAction SilentlyContinue)
            $cycleItems  = @(Get-WmiObject -Class "BatteryCycleCount" -Namespace "ROOT\WMI" -ErrorAction SilentlyContinue)

            Write-Output ("Erkannte Akkus: {0}" -f @($batteries).Count)
            Write-Output ""

            $index = 0
            foreach ($battery in @($batteries)) {
                $index++
                $static = $staticItems | Select-Object -Index ($index - 1) -ErrorAction SilentlyContinue
                $full = $fullItems | Select-Object -Index ($index - 1) -ErrorAction SilentlyContinue
                $cycle = $cycleItems | Select-Object -Index ($index - 1) -ErrorAction SilentlyContinue

                $batteryName = "Unbekannt"
                if ($battery.Name) { $batteryName = $battery.Name }
                Write-Output ("Akku {0}: {1}" -f $index, $batteryName)

                $design = $null
                $fullCap = $null
                if ($static -and $static.DesignedCapacity -gt 0) { $design = [double]$static.DesignedCapacity }
                if ($full -and $full.FullChargedCapacity -gt 0) { $fullCap = [double]$full.FullChargedCapacity }

                if ($design) { Write-Output ("  Designkapazität:     {0:N0} mWh" -f $design) }
                if ($fullCap) { Write-Output ("  Volle Ladekapazität: {0:N0} mWh" -f $fullCap) }

                if ($design -and $fullCap -and $design -gt 0) {
                    $health = [math]::Round(($fullCap * 100.0 / $design), 1)
                    if ($health -ge 80) {
                        Write-ToolStatus "OK" ("Akku-Gesundheit: {0} %" -f $health)
                    } elseif ($health -ge 60) {
                        Write-ToolStatus "WARNUNG" ("Akku-Gesundheit: {0} %" -f $health)
                    } else {
                        Write-ToolStatus "KRITISCH" ("Akku-Gesundheit: {0} %" -f $health)
                    }
                } else {
                    Write-ToolStatus "INFO" "Herstellerdaten für Design- oder Ladekapazität sind nicht vollständig verfügbar."
                }

                if ($cycle -and $cycle.CycleCount -ne $null) {
                    Write-Output ("  Ladezyklen:           {0}" -f $cycle.CycleCount)
                }
                Write-Output ""
            }

            Write-Output "Hinweis: Akkudaten werden vom Gerät bzw. Hersteller bereitgestellt und können unvollständig sein."
            Write-Output "Der vollständige Windows-Batteriereport wurde gespeichert:"
            Write-Output "  $reportPath"
            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Akkuzustand konnte nicht ermittelt werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 13: Geräte- und Treiberprobleme prüfen (read-only)
    # -------------------------------------------------------------------------
    "device_driver_check" {
        Write-Output "Geräte- und Treiberprobleme werden geprüft ..."
        Write-Output ""

        try {
            if (-not (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue)) {
                Write-ToolStatus "INFO" "Get-PnpDevice ist auf diesem System nicht verfügbar."
                exit 0
            }

            $devices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object {
                $_.Problem -ne $null -and [int]$_.Problem -ne 0
            })

            if ($devices.Count -eq 0) {
                Write-ToolStatus "OK" "Keine vorhandenen Geräte mit Windows-Problemcode erkannt."
                exit 0
            }

            $critical = @($devices | Where-Object { [int]$_.Problem -eq 43 })
            if ($critical.Count -gt 0) {
                Write-ToolStatus "KRITISCH" ("{0} Gerät(e) mit kritischem Problemcode erkannt." -f $critical.Count)
            } else {
                Write-ToolStatus "WARNUNG" ("{0} Gerät(e) mit Problemcode erkannt." -f $devices.Count)
            }
            Write-Output ""

            foreach ($device in $devices) {
                $code = [int]$device.Problem
                Write-ToolStatus (Get-DeviceProblemLevel $code) ("{0} (Code {1})" -f $device.FriendlyName, $code)
                Write-Output ("  Klasse:      {0}" -f $device.Class)
                Write-Output ("  Status:      {0}" -f $device.Status)
                Write-Output ("  Bedeutung:   {0}" -f (Get-DeviceProblemText $code))
                Write-Output ("  Instance-ID: {0}" -f $device.InstanceId)
                Write-Output ""
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Geräte- und Treiberdiagnose konnte nicht abgeschlossen werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 14: Speicherplatz prüfen (read-only)
    # -------------------------------------------------------------------------
    "disk_space_check" {
        Write-Output "Speicherplatz lokaler Laufwerke wird geprüft ..."
        Write-Output ""

        try {
            $volumes = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop |
                Where-Object { $_.DeviceID -and $_.Size -and $_.Size -ge 5GB })

            if ($volumes.Count -eq 0) {
                Write-ToolStatus "INFO" "Keine bewertbaren lokalen Dateisystemlaufwerke gefunden."
                exit 0
            }

            foreach ($vol in $volumes) {
                $size = [double]$vol.Size
                $free = [double]$vol.FreeSpace
                $used = $size - $free
                $freePct = [math]::Round(($free * 100.0 / $size), 1)

                if ($freePct -lt 8) {
                    $level = "KRITISCH"
                    $msg = ("{0} nur noch {1}% frei" -f $vol.DeviceID, $freePct)
                } elseif ($freePct -lt 15) {
                    $level = "WARNUNG"
                    $msg = ("{0} nur noch {1}% frei" -f $vol.DeviceID, $freePct)
                } else {
                    $level = "OK"
                    $msg = ("{0} {1}% freier Speicher" -f $vol.DeviceID, $freePct)
                }

                Write-ToolStatus $level $msg
                $fileSystem = "Unbekannt"
                if ($vol.FileSystem) { $fileSystem = $vol.FileSystem }
                Write-Output ("  Dateisystem: {0}" -f $fileSystem)
                Write-Output ("  Gesamt:      {0}" -f (Format-ToolSize $size))
                Write-Output ("  Belegt:      {0}" -f (Format-ToolSize $used))
                Write-Output ("  Frei:        {0}" -f (Format-ToolSize $free))
                Write-Output ""
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Speicherplatzprüfung konnte nicht abgeschlossen werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 15: Ausstehenden Neustart erkennen (read-only)
    # -------------------------------------------------------------------------
    "pending_reboot_check" {
        Write-Output "Ausstehender Neustart wird geprüft ..."
        Write-Output ""

        try {
            $reasons = @(Test-PendingRebootReason)
            if ($reasons.Count -eq 0) {
                Write-ToolStatus "INFO" "Kein ausstehender Neustart erkannt."
                exit 0
            }

            Write-ToolStatus "WARNUNG" "Ein Neustart ist ausstehend."
            foreach ($reason in $reasons) {
                Write-Output ("Grund: {0}" -f $reason)
            }
            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Neustartstatus konnte nicht ermittelt werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 16: Datenträgerzustand prüfen (read-only)
    # -------------------------------------------------------------------------
    "disk_health_check" {
        Write-Output "Datenträgerzustand wird geprüft ..."
        Write-Output ""

        try {
            $physicalDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
            $cimDisks = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)
            $smartItems = @(Get-CimInstance -Namespace "root\wmi" -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue)

            if ($physicalDisks.Count -eq 0 -and $cimDisks.Count -eq 0) {
                Write-ToolStatus "INFO" "Windows stellt keine Datenträgerliste bereit."
                exit 0
            }

            foreach ($disk in $cimDisks) {
                Write-Output ("Datenträger: {0}" -f $disk.Model)
                Write-Output ""

                $pd = $physicalDisks | Where-Object {
                    $_.FriendlyName -eq $disk.Model -or $_.SerialNumber -eq $disk.SerialNumber
                } | Select-Object -First 1

                if ($pd) {
                    Write-Output ("  Bus-Typ:      {0}" -f $pd.BusType)
                    Write-Output ("  Medientyp:    {0}" -f $pd.MediaType)
                    Write-Output ("  HealthStatus: {0}" -f $pd.HealthStatus)
                    Write-Output ("  Operational:  {0}" -f ($pd.OperationalStatus -join ", "))

                    if ($pd.HealthStatus -eq "Healthy" -and (($pd.OperationalStatus -join ",") -match "OK")) {
                        Write-ToolStatus "OK" "Windows meldet für diesen Datenträger keine Auffälligkeiten."
                    }
                    elseif ($pd.HealthStatus -eq "Unhealthy") {
                        Write-ToolStatus "KRITISCH" "Windows meldet den Datenträger als Unhealthy."
                    }
                    else {
                        Write-ToolStatus "WARNUNG" ("Windows meldet HealthStatus: {0}" -f $pd.HealthStatus)
                    }

                    $reliability = $null
                    try { $reliability = Get-StorageReliabilityCounter -PhysicalDisk $pd -ErrorAction Stop } catch {}
                    if ($reliability) {
                        if ($reliability.Temperature -ne $null) { Write-Output ("  Temperatur:   {0} C" -f $reliability.Temperature) }
                        if ($reliability.Wear -ne $null) { Write-Output ("  Verschleiß:  {0} %" -f $reliability.Wear) }
                        if ($reliability.ReadErrorsTotal -ne $null) { Write-Output ("  Lesefehler:   {0}" -f $reliability.ReadErrorsTotal) }
                        if ($reliability.WriteErrorsTotal -ne $null) { Write-Output ("  Schreibfehler:{0}" -f $reliability.WriteErrorsTotal) }
                    }
                    else {
                        Write-ToolStatus "INFO" "Keine erweiterten Zuverlässigkeitsdaten verfügbar."
                    }
                }
                else {
                    Write-ToolStatus "INFO" "Für diesen Datenträger stellt Windows keine erweiterten Zustandsdaten bereit."
                }

                $smart = $smartItems | Select-Object -First 1
                if ($smart -and $smart.PredictFailure) {
                    Write-ToolStatus "KRITISCH" "SMART Failure Prediction ist aktiv. Datensicherung durchführen."
                }

                Write-Output ""
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Datenträgerzustand konnte nicht ermittelt werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 17: Datenträgerereignisse prüfen (read-only)
    # -------------------------------------------------------------------------
    "disk_event_check" {
        Write-Output "Datenträgerereignisse der letzten 30 Tage werden geprüft ..."
        Write-Output ""

        try {
            $start = (Get-Date).AddDays(-30)
            $providers = @("disk", "Ntfs", "ReFS", "volmgr", "storahci", "stornvme", "iaStorA", "iaStorAC", "partmgr")
            $events = @(Get-WinEvent -FilterHashtable @{ LogName = "System"; StartTime = $start; Level = 1,2,3 } -ErrorAction SilentlyContinue |
                Where-Object { $providers -contains $_.ProviderName })

            if ($events.Count -eq 0) {
                Write-ToolStatus "OK" "Keine relevanten Datenträgerereignisse gefunden."
                exit 0
            }

            $criticalCount = @($events | Where-Object { $_.Level -le 2 }).Count
            if ($criticalCount -gt 0) {
                Write-ToolStatus "KRITISCH" ("{0} kritische/fehlerhafte Datenträgerereignisse gefunden." -f $criticalCount)
            }
            else {
                Write-ToolStatus "WARNUNG" ("{0} Datenträgerwarnungen gefunden." -f $events.Count)
            }

            $groups = $events | Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 12
            foreach ($group in $groups) {
                $sample = $group.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1
                Write-Output ("{0} x {1}, Event-ID {2}" -f $group.Count, $sample.ProviderName, $sample.Id)
                Write-Output ("  Letztes Ereignis: {0}" -f $sample.TimeCreated)
                Write-Output ("  Stufe: {0}" -f $sample.LevelDisplayName)
            }

            Write-Output ""
            Write-Output "Hinweis: Bei Auffälligkeiten Datensicherung durchführen und mit einem erweiterten Diagnosetool prüfen."
            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Datenträgerereignisse konnten nicht ausgewertet werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 18: Netzwerkdiagnose (read-only)
    # -------------------------------------------------------------------------
    "network_diag" {
        Write-Output "Netzwerkdiagnose wird ausgeführt ..."
        Write-Output ""

        try {
            $configs = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq "Up" })
            if ($configs.Count -eq 0) {
                Write-ToolStatus "WARNUNG" "Kein aktiver Netzwerkadapter gefunden."
                exit 0
            }

            foreach ($cfg in $configs) {
                Write-Output ("Adapter: {0}" -f $cfg.InterfaceAlias)
                $adapter = Get-NetAdapter -InterfaceIndex $cfg.InterfaceIndex -ErrorAction SilentlyContinue
                if ($adapter) {
                    Write-ToolStatus "OK" ("Adapter verbunden: {0}" -f $adapter.LinkSpeed)
                }

                $ipv4 = $cfg.IPv4Address | Select-Object -First 1
                if ($ipv4) {
                    $mode = "Unbekannt"
                    if ($ipv4.PrefixOrigin -eq "Dhcp") { $mode = "DHCP" }
                    if ($ipv4.PrefixOrigin -eq "Manual") { $mode = "Statisch" }
                    Write-ToolStatus "OK" ("IPv4-Adresse vorhanden: {0} ({1})" -f $ipv4.IPAddress, $mode)
                }
                else {
                    Write-ToolStatus "WARNUNG" "Keine IPv4-Adresse vorhanden."
                }

                if ($cfg.IPv6Address) {
                    Write-ToolStatus "INFO" ("IPv6-Adressen: {0}" -f @($cfg.IPv6Address).Count)
                }

                if ($cfg.IPv4DefaultGateway) {
                    $gw = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
                    $gwOk = Test-Connection -ComputerName $gw -Count 1 -Quiet -ErrorAction SilentlyContinue
                    if ($gwOk) {
                        Write-ToolStatus "OK" ("Standardgateway erreichbar: {0}" -f $gw)
                    }
                    else {
                        Write-ToolStatus "WARNUNG" ("Standardgateway nicht per ICMP erreichbar: {0}" -f $gw)
                    }
                }
                else {
                    Write-ToolStatus "WARNUNG" "Kein IPv4-Standardgateway konfiguriert."
                }

                $dnsServers = @($cfg.DNSServer.ServerAddresses)
                if ($dnsServers.Count -gt 0) {
                    Write-Output ("  DNS-Server: {0}" -f ($dnsServers -join ", "))
                }
                else {
                    Write-ToolStatus "WARNUNG" "Keine DNS-Server ermittelt."
                }

                Write-Output ""
            }

            try {
                Resolve-DnsName "www.microsoft.com" -ErrorAction Stop | Out-Null
                Write-ToolStatus "OK" "DNS-Auflösung funktioniert."
            }
            catch {
                Write-ToolStatus "WARNUNG" "DNS-Auflösung für www.microsoft.com fehlgeschlagen."
            }

            try {
                Invoke-WebRequest -Uri "https://www.microsoft.com" -UseBasicParsing -Method Head -TimeoutSec 10 -ErrorAction Stop | Out-Null
                Write-ToolStatus "OK" "HTTPS-Verbindung funktioniert."
            }
            catch {
                Write-ToolStatus "WARNUNG" "HTTPS-Verbindung zu www.microsoft.com fehlgeschlagen."
            }

            $winHttpProxy = (netsh winhttp show proxy) -join " "
            if ($winHttpProxy -match "Direkter Zugriff|Direct access|DirectAccess|kein Proxyserver") {
                Write-ToolStatus "OK" "WinHTTP-Proxy ist nicht konfiguriert."
            }
            else {
                Write-ToolStatus "WARNUNG" "WinHTTP-Proxy ist konfiguriert."
                Write-Output $winHttpProxy
            }

            $userProxy = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
            if ($userProxy -and $userProxy.ProxyEnable -eq 1) {
                Write-ToolStatus "WARNUNG" ("Benutzerproxy ist aktiv: {0}" -f $userProxy.ProxyServer)
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Netzwerkdiagnose konnte nicht abgeschlossen werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 19: Windows-Update-Diagnose (read-only)
    # -------------------------------------------------------------------------
    "wu_diag" {
        Write-Output "Windows-Update-Diagnose wird ausgeführt ..."
        Write-Output ""

        try {
            $serviceNames = @("wuauserv", "BITS", "CryptSvc", "UsoSvc")
            foreach ($name in $serviceNames) {
                $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
                if ($svc) {
                    if ($svc.Status -eq "Running") {
                        Write-ToolStatus "OK" ("Dienst {0} wird ausgeführt." -f $name)
                    }
                    else {
                        Write-ToolStatus "WARNUNG" ("Dienst {0} ist {1}." -f $name, $svc.Status)
                    }
                }
                else {
                    Write-ToolStatus "INFO" ("Dienst {0} ist nicht vorhanden." -f $name)
                }
            }

            $reasons = @(Test-PendingRebootReason)
            if ($reasons.Count -gt 0) {
                Write-ToolStatus "WARNUNG" "Für Windows ist ein Neustart ausstehend."
                foreach ($reason in $reasons) { Write-Output ("Grund: {0}" -f $reason) }
            }
            else {
                Write-ToolStatus "OK" "Kein ausstehender Neustart erkannt."
            }

            $start = (Get-Date).AddDays(-30)
            $wuEvents = @(Get-WinEvent -FilterHashtable @{ LogName = "System"; ProviderName = "Microsoft-Windows-WindowsUpdateClient"; StartTime = $start; Level = 2,3 } -ErrorAction SilentlyContinue)
            if ($wuEvents.Count -gt 0) {
                Write-ToolStatus "WARNUNG" ("In den letzten 30 Tagen wurden {0} Updatewarnungen/-fehler protokolliert." -f $wuEvents.Count)
                $wuEvents | Sort-Object TimeCreated -Descending | Select-Object -First 5 | ForEach-Object {
                    Write-Output ("  {0}: Event-ID {1}, {2}" -f $_.TimeCreated, $_.Id, $_.LevelDisplayName)
                }
            }
            else {
                Write-ToolStatus "OK" "Keine Windows-Update-Fehler der letzten 30 Tage im Systemprotokoll gefunden."
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Windows-Update-Diagnose konnte nicht abgeschlossen werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 20: Kompakte Ereignisdiagnose (read-only)
    # -------------------------------------------------------------------------
    "event_diag" {
        Write-Output "Kompakte Ereignisdiagnose der letzten 7 Tage wird erstellt ..."
        Write-Output ""

        try {
            $start = (Get-Date).AddDays(-7)
            $all = @()
            $all += @(Get-WinEvent -FilterHashtable @{ LogName = "System"; StartTime = $start; Level = 1,2,3 } -ErrorAction SilentlyContinue)
            $all += @(Get-WinEvent -FilterHashtable @{ LogName = "Application"; StartTime = $start; Level = 1,2,3 } -ErrorAction SilentlyContinue)

            $relevant = @($all | Where-Object {
                $_.ProviderName -in @(
                    "Microsoft-Windows-Kernel-Power",
                    "Microsoft-Windows-WHEA-Logger",
                    "disk",
                    "Ntfs",
                    "ReFS",
                    "Service Control Manager",
                    "Application Error",
                    "Windows Error Reporting",
                    "Microsoft-Windows-WindowsUpdateClient"
                ) -or $_.Id -in @(41, 1001, 6008)
            })

            if ($relevant.Count -eq 0) {
                Write-ToolStatus "OK" "Keine relevanten Ereignisse gefunden."
                exit 0
            }

            Write-ToolStatus "WARNUNG" ("{0} relevante Ereignisse gefunden." -f $relevant.Count)
            $groups = $relevant | Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 15
            foreach ($group in $groups) {
                $sample = $group.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1
                Write-Output ""
                Write-Output ("{0} x {1}, Event-ID {2}" -f $group.Count, $sample.ProviderName, $sample.Id)
                Write-Output ("  Letztes Ereignis: {0}" -f $sample.TimeCreated)
                Write-Output ("  Stufe: {0}" -f $sample.LevelDisplayName)
                $message = ($sample.Message -replace "`r|`n", " ")
                if ($message.Length -gt 180) { $message = $message.Substring(0, 180) + "..." }
                Write-Output ("  Kurztext: {0}" -f $message)
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Ereignisdiagnose konnte nicht abgeschlossen werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 21: Sicherheitsstatus (read-only)
    # -------------------------------------------------------------------------
    "security_status" {
        Write-Output "Sicherheitsstatus wird geprüft ..."
        Write-Output ""

        try {
            if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
                $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
                if ($mp) {
                    if ($mp.RealTimeProtectionEnabled) {
                        Write-ToolStatus "OK" "Microsoft Defender Echtzeitschutz aktiv."
                    } else {
                        Write-ToolStatus "WARNUNG" "Microsoft Defender Echtzeitschutz ist nicht aktiv."
                    }

                    if ($mp.AntivirusSignatureLastUpdated) {
                        Write-Output ("  Signaturen: {0}" -f $mp.AntivirusSignatureLastUpdated)
                    }
                }
            }
            else {
                Write-ToolStatus "INFO" "Defender-Cmdlets sind nicht verfügbar."
            }

            $profiles = @(Get-NetFirewallProfile -ErrorAction SilentlyContinue)
            if ($profiles.Count -gt 0) {
                $disabled = @($profiles | Where-Object { -not $_.Enabled })
                if ($disabled.Count -eq 0) {
                    Write-ToolStatus "OK" "Windows-Firewall ist in allen Profilen aktiv."
                } else {
                    Write-ToolStatus "WARNUNG" ("Firewall deaktiviert für: {0}" -f (($disabled | ForEach-Object Name) -join ", "))
                }
            }

            try {
                if (Confirm-SecureBootUEFI -ErrorAction Stop) {
                    Write-ToolStatus "OK" "Secure Boot aktiv."
                } else {
                    Write-ToolStatus "INFO" "Secure Boot nicht aktiv."
                }
            }
            catch {
                Write-ToolStatus "INFO" "Secure Boot nicht verfügbar oder nicht abfragbar."
            }

            if (Get-Command Get-Tpm -ErrorAction SilentlyContinue) {
                $tpm = Get-Tpm -ErrorAction SilentlyContinue
                if ($tpm -and $tpm.TpmPresent -and $tpm.TpmReady) {
                    Write-ToolStatus "OK" "TPM vorhanden und bereit."
                } elseif ($tpm -and $tpm.TpmPresent) {
                    Write-ToolStatus "WARNUNG" "TPM vorhanden, aber nicht bereit."
                } else {
                    Write-ToolStatus "INFO" "TPM nicht vorhanden oder nicht verfügbar."
                }
            }

            if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
                $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
                if ($bl) {
                    if ([int]$bl.ProtectionStatus -eq 1) {
                        Write-ToolStatus "OK" "BitLocker-Schutz für C: aktiv."
                    } else {
                        Write-ToolStatus "INFO" "BitLocker-Schutz für C: nicht aktiv."
                    }
                }
            }

            $uac = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue
            if ($uac -and $uac.EnableLUA -eq 1) {
                Write-ToolStatus "OK" "UAC ist aktiv."
            } else {
                Write-ToolStatus "WARNUNG" "UAC ist deaktiviert."
            }

            $rdp = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -ErrorAction SilentlyContinue
            if ($rdp -and $rdp.fDenyTSConnections -eq 0) {
                Write-ToolStatus "INFO" "Remote Desktop ist aktiviert."
            } else {
                Write-ToolStatus "OK" "Remote Desktop ist deaktiviert."
            }

            try {
                $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
                if ($smb1 -and $smb1.State -eq "Enabled") {
                    Write-ToolStatus "WARNUNG" "SMBv1 ist aktiviert."
                } else {
                    Write-ToolStatus "OK" "SMBv1 ist nicht aktiviert."
                }
            }
            catch {
                Write-ToolStatus "INFO" "SMBv1-Status konnte nicht ohne erhöhte Rechte ermittelt werden."
            }

            $admins = @(Get-LocalGroupMember -Group "Administratoren" -ErrorAction SilentlyContinue)
            if ($admins.Count -gt 0) {
                Write-Output ""
                Write-Output "Lokale Administratoren:"
                $admins | Select-Object -First 12 | ForEach-Object {
                    Write-Output ("  - {0}" -f $_.Name)
                }
                if ($admins.Count -gt 12) {
                    Write-Output ("  ... weitere {0}" -f ($admins.Count - 12))
                }
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Sicherheitsstatus konnte nicht ermittelt werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 22: Bluescreen- und Absturzdateien finden (read-only)
    # -------------------------------------------------------------------------
    "dump_check" {
        Write-Output "Bluescreen- und Absturzdateien werden gesucht ..."
        Write-Output ""

        try {
            $targets = @(
                @{ Name = "Minidumps"; Path = "$env:SystemRoot\Minidump"; Filter = "*.dmp" },
                @{ Name = "MEMORY.DMP"; Path = "$env:SystemRoot\MEMORY.DMP"; Filter = $null },
                @{ Name = "LiveKernelReports"; Path = "$env:SystemRoot\LiveKernelReports"; Filter = "*.dmp" }
            )

            $allFiles = @()
            foreach ($target in $targets) {
                Write-Output $target.Name
                if (Test-Path $target.Path) {
                    if ($target.Filter) {
                        $files = @(Get-ChildItem -Path $target.Path -Filter $target.Filter -File -Recurse -ErrorAction SilentlyContinue)
                    } else {
                        $files = @(Get-Item -Path $target.Path -ErrorAction SilentlyContinue)
                    }

                    if ($files.Count -eq 0) {
                        Write-ToolStatus "INFO" "Keine Dump-Dateien gefunden."
                    } else {
                        Write-ToolStatus "WARNUNG" ("{0} Dump-Datei(en) gefunden." -f $files.Count)
                        $allFiles += $files
                        $files | Sort-Object LastWriteTime -Descending | Select-Object -First 8 | ForEach-Object {
                            Write-Output ("  {0} | {1} | {2}" -f $_.LastWriteTime, (Format-ToolSize ([double]$_.Length)), $_.FullName)
                        }
                    }
                } else {
                    Write-ToolStatus "INFO" "Pfad nicht vorhanden."
                }
                Write-Output ""
            }

            if ($allFiles.Count -gt 0) {
                $newest = $allFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                Write-Output ("Neuester Dump: {0}" -f $newest.LastWriteTime)
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Dump-Dateien konnten nicht ermittelt werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 23: Autostartübersicht (read-only)
    # -------------------------------------------------------------------------
    "startup_overview" {
        Write-Output "Autostartübersicht wird erstellt ..."
        Write-Output ""

        try {
            $entries = New-Object System.Collections.Generic.List[object]
            $runKeys = @(
                @{ Source = "HKLM Run"; Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" },
                @{ Source = "HKLM RunOnce"; Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" },
                @{ Source = "HKCU Run"; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" },
                @{ Source = "HKCU RunOnce"; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" }
            )

            foreach ($key in $runKeys) {
                $props = Get-ItemProperty -Path $key.Path -ErrorAction SilentlyContinue
                if ($props) {
                    foreach ($prop in $props.PSObject.Properties) {
                        if ($prop.Name -notmatch "^PS") {
                            $entries.Add([PSCustomObject]@{ Source = $key.Source; Name = $prop.Name; Command = [string]$prop.Value })
                        }
                    }
                }
            }

            $startupFolders = @(
                @{ Source = "Benutzer-Autostart"; Path = [Environment]::GetFolderPath("Startup") },
                @{ Source = "System-Autostart"; Path = [Environment]::GetFolderPath("CommonStartup") }
            )
            foreach ($folder in $startupFolders) {
                if ($folder.Path -and (Test-Path $folder.Path)) {
                    Get-ChildItem -Path $folder.Path -File -ErrorAction SilentlyContinue | ForEach-Object {
                        $entries.Add([PSCustomObject]@{ Source = $folder.Source; Name = $_.Name; Command = $_.FullName })
                    }
                }
            }

            $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
                $_.Triggers | Where-Object { $_.CimClass.CimClassName -match "LogonTrigger" }
            } | Select-Object -First 30)
            foreach ($task in $tasks) {
                $entries.Add([PSCustomObject]@{ Source = "Geplante Aufgabe"; Name = $task.TaskName; Command = $task.TaskPath })
            }

            if ($entries.Count -eq 0) {
                Write-ToolStatus "INFO" "Keine Autostarteinträge gefunden."
                exit 0
            }

            Write-ToolStatus "INFO" ("{0} Autostarteinträge gefunden." -f $entries.Count)
            $entries | Select-Object -First 60 | ForEach-Object {
                Write-Output ""
                Write-Output ("Name:   {0}" -f $_.Name)
                Write-Output ("Quelle: {0}" -f $_.Source)
                Write-Output ("Befehl: {0}" -f $_.Command)
            }
            if ($entries.Count -gt 60) {
                Write-Output ""
                Write-Output ("Ausgabe gekürzt, weitere Einträge: {0}" -f ($entries.Count - 60))
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Autostartübersicht konnte nicht erstellt werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 24: Dienstediagnose (read-only)
    # -------------------------------------------------------------------------
    "service_diag" {
        Write-Output "Dienstediagnose wird ausgeführt ..."
        Write-Output ""

        try {
            $autoStopped = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {
                $_.StartMode -eq "Auto" -and $_.State -ne "Running"
            } | Select-Object -First 25)

            if ($autoStopped.Count -gt 0) {
                Write-ToolStatus "WARNUNG" ("{0} automatisch gestartete Dienste sind aktuell nicht aktiv." -f $autoStopped.Count)
                foreach ($svc in $autoStopped) {
                    Write-Output ("  {0} ({1}) - {2}" -f $svc.Name, $svc.State, $svc.DisplayName)
                }
            } else {
                Write-ToolStatus "OK" "Keine auffälligen gestoppten Auto-Dienste gefunden."
            }

            $invalidPath = @()
            $servicesWithPath = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.PathName })
            foreach ($svc in $servicesWithPath) {
                $rawPath = $svc.PathName.Trim()
                $exePath = $null

                if ($rawPath -match '^"([^"]+)"') {
                    $exePath = $Matches[1]
                }
                elseif ($rawPath -match '^(.+?\.exe)') {
                    $exePath = $Matches[1]
                }

                if ($exePath -and -not (Test-Path -LiteralPath $exePath)) {
                    $invalidPath += $svc
                }
            }
            $invalidPath = @($invalidPath | Select-Object -First 15)
            if ($invalidPath.Count -gt 0) {
                Write-ToolStatus "WARNUNG" ("{0} Dienste mit nicht gefundenem Programmpfad erkannt." -f $invalidPath.Count)
                foreach ($svc in $invalidPath) {
                    Write-Output ("  {0}: {1}" -f $svc.Name, $svc.PathName)
                }
            }

            $start = (Get-Date).AddDays(-7)
            $events = @(Get-WinEvent -FilterHashtable @{ LogName = "System"; ProviderName = "Service Control Manager"; StartTime = $start; Level = 2,3 } -ErrorAction SilentlyContinue)
            if ($events.Count -gt 0) {
                Write-ToolStatus "WARNUNG" ("{0} Dienstwarnungen/-fehler in den letzten 7 Tagen gefunden." -f $events.Count)
                $events | Group-Object Id | Sort-Object Count -Descending | Select-Object -First 8 | ForEach-Object {
                    $sample = $_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1
                    Write-Output ("  {0} x Event-ID {1}, letztes: {2}" -f $_.Count, $sample.Id, $sample.TimeCreated)
                }
            } else {
                Write-ToolStatus "OK" "Keine Service-Control-Manager-Fehler der letzten 7 Tage gefunden."
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Dienstediagnose konnte nicht abgeschlossen werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 25: Druckerdiagnose (read-only)
    # -------------------------------------------------------------------------
    "printer_diag" {
        Write-Output "Druckerdiagnose wird ausgeführt ..."
        Write-Output ""

        try {
            $spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
            if ($spooler) {
                if ($spooler.Status -eq "Running") {
                    Write-ToolStatus "OK" "Druckwarteschlange/Spooler läuft."
                } else {
                    Write-ToolStatus "WARNUNG" ("Spooler ist {0}." -f $spooler.Status)
                }
            }

            $printers = @(Get-Printer -ErrorAction SilentlyContinue)
            if ($printers.Count -eq 0) {
                Write-ToolStatus "INFO" "Keine installierten Drucker gefunden."
                exit 0
            }

            Write-ToolStatus "INFO" ("{0} installierte Drucker gefunden." -f $printers.Count)
            $defaultPrinter = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object { $_.Default } | Select-Object -First 1
            $offlinePrinters = @($printers | Where-Object { $_.PrinterStatus -match "Offline" })
            if ($offlinePrinters.Count -gt 0) {
                Write-ToolStatus "WARNUNG" ("{0} Drucker offline oder nicht erreichbar." -f $offlinePrinters.Count)
                $offlinePrinters | ForEach-Object {
                    Write-Output ("  - {0}" -f $_.Name)
                }
            }

            foreach ($printer in $printers) {
                Write-Output ""
                Write-Output ("Drucker: {0}" -f $printer.Name)
                $isDefault = ($defaultPrinter -and $defaultPrinter.Name -eq $printer.Name)
                Write-Output ("  Standard: {0}" -f $isDefault)
                Write-Output ("  Offline:  {0}" -f $printer.PrinterStatus)
                Write-Output ("  Port:     {0}" -f $printer.PortName)
                Write-Output ("  Treiber:  {0}" -f $printer.DriverName)
            }

            $ports = @(Get-PrinterPort -ErrorAction SilentlyContinue)
            if ($ports.Count -gt 0) {
                Write-Output ""
                Write-Output "Druckeranschlüsse:"
                $ports | Select-Object -First 20 | ForEach-Object {
                    $hostInfo = if ($_.PrinterHostAddress) { $_.PrinterHostAddress } else { "-" }
                    Write-Output ("  {0} | Host: {1}" -f $_.Name, $hostInfo)
                }
                if ($ports.Count -gt 20) {
                    Write-Output ("  ... weitere {0}" -f ($ports.Count - 20))
                }
            }

            $jobs = @()
            foreach ($printer in $printers) {
                $jobs += @(Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue)
            }
            if ($jobs.Count -gt 0) {
                Write-ToolStatus "WARNUNG" ("{0} Druckauftrag/-aufträge in Warteschlangen gefunden." -f $jobs.Count)
                $jobs | Select-Object -First 12 | ForEach-Object {
                    Write-Output ("  {0}: Job {1}, {2}, {3}" -f $_.PrinterName, $_.ID, $_.JobStatus, $_.SubmittedTime)
                }
            } else {
                Write-ToolStatus "OK" "Keine Druckaufträge in Warteschlangen gefunden."
            }

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Druckerdiagnose konnte nicht abgeschlossen werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 26: Druckwarteschlange leeren / Spooler neu starten
    # -------------------------------------------------------------------------
    "printer_queue_clear" {
        Write-Output "Druckwarteschlange wird geleert ..."
        Write-Output ""
        Write-ToolStatus "WARNUNG" "Alle offenen Druckaufträge werden gelöscht."

        try {
            Stop-Service -Name Spooler -Force -ErrorAction Stop
            $spoolPath = Join-Path $env:SystemRoot "System32\spool\PRINTERS"
            if (Test-Path $spoolPath) {
                Remove-Item -Path (Join-Path $spoolPath "*") -Force -ErrorAction SilentlyContinue
            }
            Start-Service -Name Spooler -ErrorAction Stop
            Write-ToolStatus "OK" "Druckwarteschlange wurde geleert und Spooler neu gestartet."
            exit 0
        }
        catch {
            try { Start-Service -Name Spooler -ErrorAction SilentlyContinue } catch {}
            Write-ToolStatus "FEHLER" "Druckwarteschlange konnte nicht geleert werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 27: Drucker-Testseite drucken
    # -------------------------------------------------------------------------
    "printer_test_page" {
        Write-Output "Drucker-Testseite wird vorbereitet ..."
        Write-Output ""

        try {
            $defaultPrinter = Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object { $_.Default } | Select-Object -First 1
            if (-not $defaultPrinter) {
                Write-ToolStatus "WARNUNG" "Kein Standarddrucker gefunden."
                exit 1
            }

            Write-Output ("Standarddrucker: {0}" -f $defaultPrinter.Name)
            Start-Process -FilePath "rundll32.exe" -ArgumentList ("printui.dll,PrintUIEntry /k /n `"{0}`"" -f $defaultPrinter.Name) -Wait -ErrorAction Stop
            Write-ToolStatus "OK" "Testseite wurde an den Standarddrucker übergeben."
            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Testseite konnte nicht gedruckt werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 28: Uhrzeit, Zeitzone und Zeitsynchronisierung (read-only)
    # -------------------------------------------------------------------------
    "time_diag" {
        Write-Output "Zeit- und Zeitzonendiagnose wird ausgeführt ..."
        Write-Output ""

        try {
            Write-Output ("Lokale Uhrzeit: {0}" -f (Get-Date))
            $tz = Get-TimeZone -ErrorAction SilentlyContinue
            if ($tz) {
                Write-Output ("Zeitzone:       {0} ({1})" -f $tz.DisplayName, $tz.Id)
            }

            $svc = Get-Service -Name W32Time -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.Status -eq "Running") {
                    Write-ToolStatus "OK" "Windows-Zeitdienst läuft."
                } else {
                    Write-ToolStatus "WARNUNG" ("Windows-Zeitdienst ist {0}." -f $svc.Status)
                }
            }

            Write-Output ""
            Write-Output "w32tm /query /status"
            $status = w32tm /query /status 2>&1
            Write-Output $status

            Write-Output ""
            Write-Output "w32tm /query /source"
            $source = w32tm /query /source 2>&1
            Write-Output $source

            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Zeitdiagnose konnte nicht abgeschlossen werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 29: Windows-Zeit neu synchronisieren
    # -------------------------------------------------------------------------
    "time_resync" {
        Write-Output "Windows-Zeit wird neu synchronisiert ..."
        Write-Output ""

        try {
            Start-Service -Name W32Time -ErrorAction SilentlyContinue
            $result = w32tm /resync 2>&1
            Write-Output $result

            if ($LASTEXITCODE -eq 0) {
                Write-ToolStatus "OK" "Zeitsynchronisierung wurde angestoßen."
                exit 0
            }

            Write-ToolStatus "WARNUNG" ("w32tm /resync meldete Rückgabecode: {0}." -f $LASTEXITCODE)
            exit $LASTEXITCODE
        }
        catch {
            Write-ToolStatus "FEHLER" "Zeitsynchronisierung konnte nicht gestartet werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # 30: Bericht als TXT exportieren
    # -------------------------------------------------------------------------
    "report_export" {
        Write-Output "Bericht wird erstellt ..."
        Write-Output ""

        try {
            $desktop = [Environment]::GetFolderPath("Desktop")
            if (-not $desktop) { $desktop = "$env:USERPROFILE\Desktop" }
            $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $path = Join-Path $desktop ("SD-ITLab-TechTools-Bericht_{0}.txt" -f $stamp)

            $warnings = New-Object System.Collections.Generic.List[string]
            $lines = New-Object System.Collections.Generic.List[string]

            function Add-ReportLine([string]$Text = "") {
                $script:lines.Add($Text) | Out-Null
            }

            function Format-ReportDate($Value) {
                if (-not $Value) { return "-" }
                try { return ([datetime]$Value).ToString("dd.MM.yyyy HH:mm:ss") } catch { return [string]$Value }
            }

            function Format-ReportNominalSize {
                param([Nullable[double]]$Bytes)

                if ($null -eq $Bytes -or $Bytes -le 0) { return "-" }

                $gb = [double]$Bytes / 1GB
                $commonGb = @(1, 2, 3, 4, 6, 8, 10, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256)
                $nearest = $commonGb |
                    Sort-Object { [math]::Abs($gb - $_) } |
                    Select-Object -First 1

                if ($nearest -and [math]::Abs($gb - $nearest) -le [math]::Max(0.25, $nearest * 0.035)) {
                    return ("{0:N0} GB" -f $nearest)
                }

                if ($gb -ge 1) { return ("{0:N1} GB" -f $gb) }
                return (Format-ToolSize $Bytes)
            }

            function Get-ReportGpuMemory {
                param([string]$GpuName, [Nullable[double]]$FallbackBytes)

                $videoKeys = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Video" -ErrorAction SilentlyContinue
                foreach ($videoKey in $videoKeys) {
                    $subKeys = Get-ChildItem $videoKey.PSPath -ErrorAction SilentlyContinue
                    foreach ($subKey in $subKeys) {
                        $props = Get-ItemProperty $subKey.PSPath -ErrorAction SilentlyContinue
                        if (-not $props) { continue }

                        $adapterName = [string]$props."HardwareInformation.AdapterString"
                        $driverDesc = [string]$props.DriverDesc
                        $matchesName = $false
                        if ($adapterName -and $GpuName -and ($GpuName.Contains($adapterName) -or $adapterName.Contains($GpuName))) { $matchesName = $true }
                        if ($driverDesc -and $GpuName -and ($GpuName.Contains($driverDesc) -or $driverDesc.Contains($GpuName))) { $matchesName = $true }
                        if (-not $matchesName -and $adapterName -and $GpuName -and $GpuName.Contains("NVIDIA") -and $adapterName.Contains("NVIDIA")) { $matchesName = $true }
                        if (-not $matchesName -and $adapterName -and $GpuName -and $GpuName.Contains("AMD") -and $adapterName.Contains("AMD")) { $matchesName = $true }
                        if (-not $matchesName -and -not $adapterName -and -not $driverDesc) { continue }

                        $memory = $props."HardwareInformation.qwMemorySize"
                        if ($memory -and [double]$memory -gt 0) {
                            return [double]$memory
                        }
                    }
                }

                if ($FallbackBytes -and $FallbackBytes -gt 0) { return [double]$FallbackBytes }
                return $null
            }

            function Get-ReportBootInfo {
                $boot = "Unbekannt"
                try {
                    $fw = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "PEFirmwareType" -ErrorAction SilentlyContinue).PEFirmwareType
                    if ($fw) {
                        $boot = switch ($fw) {
                            1 { "Legacy / BIOS" }
                            2 { "UEFI" }
                            default { "Unbekannt" }
                        }
                    }
                } catch {}

                if ($boot -eq "Unbekannt") {
                    if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State") { $boot = "UEFI" }
                    else { $boot = "Legacy / BIOS" }
                }

                $style = ""
                try {
                    $diskObj = Get-Partition -DriveLetter C -ErrorAction SilentlyContinue | Get-Disk -ErrorAction SilentlyContinue
                    if ($diskObj.PartitionStyle) { $style = [string]$diskObj.PartitionStyle }
                } catch {}

                if ($style) { return "$boot ($style)" }
                return $boot
            }

            function Get-ReportSecureBootInfo {
                $firmwareType = $env:firmware_type
                $sbParentKey = Get-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" -ErrorAction SilentlyContinue
                $isUEFI = ($firmwareType -eq "UEFI") -or ($sbParentKey -ne $null)
                if (-not $isUEFI) { return "Kein UEFI (Legacy BIOS)" }

                $sbStateKey = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -ErrorAction SilentlyContinue
                $sbEnabled = ($sbStateKey -ne $null -and $sbStateKey.UEFISecureBootEnabled -eq 1)
                if (-not $sbEnabled) { return "SecureBoot deaktiviert" }

                try {
                    $dbVar = Get-SecureBootUEFI db -ErrorAction Stop
                    if ($dbVar -and $dbVar.bytes) {
                        $dbStr = [System.Text.Encoding]::ASCII.GetString($dbVar.bytes)
                        if ($dbStr -match "Windows UEFI CA 2023" -or $dbStr -match "Microsoft UEFI CA 2023") {
                            return "SecureBoot AN, CA 2023 aktiv"
                        }
                    }
                    return "SecureBoot AN, CA 2023 fehlt"
                } catch {
                    return "SecureBoot AN (CA 2023 ohne Admin nicht prüfbar)"
                }
            }

            function Get-ReportFastStartupInfo {
                try {
                    if (-not (Test-Path -LiteralPath "$env:SystemDrive\hiberfil.sys")) {
                        return "Deaktiviert (Ruhezustand aus)"
                    }

                    $powercfgAvailableStates = @(powercfg /a 2>&1) -join " "
                    if ($powercfgAvailableStates -match "Schnellstart" -and
                        $powercfgAvailableStates -match "Ruhezustand (ist nicht verfügbar|wurde nicht aktiviert|ist nicht verf)") {
                        return "Deaktiviert (Ruhezustand aus)"
                    }

                    $powerRoot = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -ErrorAction SilentlyContinue
                    if ($powerRoot -and $null -ne $powerRoot.HibernateEnabled -and [int]$powerRoot.HibernateEnabled -eq 0) {
                        return "Deaktiviert (Ruhezustand aus)"
                    }

                    $hiberboot = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -ErrorAction Stop
                    if ([int]$hiberboot.HiberbootEnabled -eq 1) { return "Aktiv" }
                    if ([int]$hiberboot.HiberbootEnabled -eq 0) { return "Deaktiviert" }
                    return "Unbekannt"
                } catch {
                    return "Nicht eindeutig ermittelbar"
                }
            }

            function Get-ReportDismCheckHealthInfo {
                try {
                    $output = @(DISM /Online /Cleanup-Image /CheckHealth 2>&1)
                    $code = $LASTEXITCODE
                    $text = ($output -join " ")

                    if ($text -match "Keine Beschädigung des Komponentenspeichers erkannt|No component store corruption detected") {
                        return "OK - keine Beschädigung markiert"
                    }
                    if ($text -match "Der Komponentenspeicher kann repariert werden|The component store is repairable") {
                        return "WARNUNG - Komponentenstore als reparierbar markiert"
                    }
                    if ($text -match "Der Komponentenspeicher kann nicht repariert werden|The component store is not repairable") {
                        return "KRITISCH - Komponentenstore nicht reparierbar markiert"
                    }
                    if ($code -eq 0) {
                        return "OK - keine Beschädigung markiert"
                    }
                    return ("WARNUNG - Rückgabecode {0}" -f $code)
                } catch {
                    return ("Nicht ermittelbar - {0}" -f $_.Exception.Message)
                }
            }

            function Get-ReportKbId {
                param([string]$Text)
                if ($Text -match "(KB\d{6,8})") { return $Matches[1] }
                return ""
            }

            function Test-ReportStartupEnabled {
                param([string]$ApprovedPath, [string]$Name)

                if (-not $ApprovedPath -or -not $Name) { return $true }
                try {
                    $approved = Get-ItemProperty -Path $ApprovedPath -ErrorAction SilentlyContinue
                    if (-not $approved) { return $true }
                    $value = $approved.PSObject.Properties[$Name].Value
                    if ($null -eq $value -or $value.Count -eq 0) { return $true }
                    return ([byte]$value[0] -ne 3)
                } catch {
                    return $true
                }
            }

            function Get-ReportServiceEventText {
                param($Event)

                switch ([int]$Event.Id) {
                    7000 { return "Dienst konnte nicht gestartet werden" }
                    7001 { return "Dienstabhängigkeit konnte nicht gestartet werden" }
                    7009 { return "Zeitüberschreitung beim Dienststart" }
                    7011 { return "Zeitüberschreitung bei Dienstreaktion" }
                    7022 { return "Dienst hängt beim Start" }
                    7023 { return "Dienst wurde mit Fehler beendet" }
                    7024 { return "Dienst wurde mit dienstspezifischem Fehler beendet" }
                    7031 { return "Dienst wurde unerwartet beendet" }
                    7034 { return "Dienst wurde unerwartet beendet" }
                    default {
                        $msg = if ($Event.Message) { ($Event.Message -replace "`r|`n", " ") } else { "Dienstfehler" }
                        if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 120) + "..." }
                        return $msg
                    }
                }
            }

            function Get-ReportServiceNameFromEvent {
                param($Event)

                $message = if ($Event.Message) { [string]$Event.Message } else { "" }
                $patterns = @(
                    "Der Dienst [`"“„']?([^`"””']+)[`"“„']?",
                    "The ([^`r`n]+?) service ",
                    "Dienstname:\s*([^`r`n]+)",
                    "Service Name:\s*([^`r`n]+)"
                )

                foreach ($pattern in $patterns) {
                    if ($message -match $pattern) {
                        return ($Matches[1].Trim())
                    }
                }

                return "Unbekannter Dienst"
            }

            Add-ReportLine "SD-ITLab TechTools - Bericht"
            Add-ReportLine "======================="
            Add-ReportLine ("Datum: {0}" -f (Get-Date))
            Add-ReportLine ("Computer: {0}" -f $env:COMPUTERNAME)
            Add-ReportLine ""

            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
            $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
            $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
            $baseBoard = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
            $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name })
            $ramText = if ($cs.TotalPhysicalMemory) { Format-ReportNominalSize ([double]$cs.TotalPhysicalMemory) } else { "-" }
            $lic = Get-CimInstance SoftwareLicensingProduct -ErrorAction SilentlyContinue | Where-Object { $_.PartialProductKey -and $_.LicenseStatus -eq 1 } | Select-Object -First 1
            $activationText = if ($lic) { "Ja" } else { "Nein / unklar" }
            if (-not $lic) { $warnings.Add("Windows-Aktivierung unklar oder nicht aktiv erkannt.") | Out-Null }

            Add-ReportLine "System"
            Add-ReportLine "------"
            Add-ReportLine ("Windows: {0} ({1})" -f $os.Caption, $os.Version)
            Add-ReportLine ("Aktiviert: {0}" -f $activationText)
            Add-ReportLine ("Build: {0}" -f $os.BuildNumber)
            Add-ReportLine ("Boot: {0}" -f (Get-ReportBootInfo))
            Add-ReportLine ("SecureBoot: {0}" -f (Get-ReportSecureBootInfo))
            Add-ReportLine ("Schnellstart: {0}" -f (Get-ReportFastStartupInfo))
            Add-ReportLine ("DISM CheckHealth: {0}" -f (Get-ReportDismCheckHealthInfo))
            Add-ReportLine ("Installationsdatum: {0}" -f (Format-ReportDate $os.InstallDate))
            Add-ReportLine ("Letzter Systemstart: {0}" -f (Format-ReportDate $os.LastBootUpTime))
            Add-ReportLine ""

            Add-ReportLine "Hardware"
            Add-ReportLine "--------"
            Add-ReportLine ("Hersteller/Modell: {0} {1}" -f $cs.Manufacturer, $cs.Model)
            if ($baseBoard) {
                Add-ReportLine ("Mainboard: {0} {1}" -f $baseBoard.Manufacturer, $baseBoard.Product)
            }
            Add-ReportLine ("CPU: {0}" -f $cpu.Name)
            Add-ReportLine ("RAM: {0}" -f $ramText)
            if ($gpus.Count -eq 0) {
                Add-ReportLine "GPU: Nicht erkannt."
            } else {
                foreach ($gpu in $gpus) {
                    $gpuMemory = Get-ReportGpuMemory -GpuName $gpu.Name -FallbackBytes $gpu.AdapterRAM
                    $gpuRam = if ($gpuMemory) { " | VRAM: {0}" -f (Format-ReportNominalSize $gpuMemory) } else { "" }
                    Add-ReportLine ("GPU: {0}{1}" -f $gpu.Name, $gpuRam)
                }
            }
            Add-ReportLine ("BIOS: {0}" -f $bios.SMBIOSBIOSVersion)
            Add-ReportLine ""

            Add-ReportLine "Datenträger"
            Add-ReportLine "------------"
            $physicalDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
            if ($physicalDisks.Count -eq 0) {
                Add-ReportLine "Keine Datenträgerdaten über Get-PhysicalDisk verfügbar."
            } else {
                foreach ($disk in $physicalDisks) {
                    Add-ReportLine ("{0} | {1} | {2} | {3}" -f $disk.FriendlyName, $disk.BusType, $disk.MediaType, $disk.HealthStatus)
                    if ($disk.HealthStatus -ne "Healthy") { $warnings.Add("Datenträgerstatus auffällig: $($disk.FriendlyName)") | Out-Null }
                }
            }
            Add-ReportLine ""

            Add-ReportLine "Akku"
            Add-ReportLine "----"
            $batteries = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
            if ($batteries.Count -eq 0) {
                Add-ReportLine "Kein Akku erkannt."
            } else {
                foreach ($bat in $batteries) {
                    Add-ReportLine ("{0} | Status: {1} | Ladung: {2}%" -f $bat.Name, $bat.Status, $bat.EstimatedChargeRemaining)
                }
            }
            Add-ReportLine ""

            Add-ReportLine "Letzte Windows-Updates"
            Add-ReportLine "----------------------"
            $updateLines = New-Object System.Collections.Generic.List[string]
            $seenUpdates = @{}
            try {
                $session = New-Object -ComObject Microsoft.Update.Session
                $searcher = $session.CreateUpdateSearcher()
                $historyCount = [Math]::Min($searcher.GetTotalHistoryCount(), 250)
                if ($historyCount -gt 0) {
                    $history = @($searcher.QueryHistory(0, $historyCount) | Where-Object {
                        $_.Operation -eq 1 -and $_.ResultCode -eq 2 -and
                        $_.Title -match "Security|Sicherheits|Cumulative|Kumulativ|Feature|Funktions|Update for Microsoft Windows|Windows"
                    } | Sort-Object Date -Descending)

                    foreach ($entry in $history) {
                        $kbId = Get-ReportKbId $entry.Title
                        $key = if ($kbId) { $kbId } else { ($entry.Title -replace "\s+", " ").Trim() }
                        if (-not $key -or $seenUpdates.ContainsKey($key)) { continue }

                        $seenUpdates[$key] = $true
                        $kbText = if ($kbId) { " | $kbId" } else { "" }
                        $updateLines.Add(("{0} | {1}{2}" -f (Format-ReportDate $entry.Date), $entry.Title, $kbText)) | Out-Null
                        if ($updateLines.Count -ge 10) { break }
                    }
                }
            } catch {}

            if ($updateLines.Count -eq 0) {
                try {
                    $hotfixes = @(Get-HotFix -ErrorAction SilentlyContinue |
                        Where-Object { $_.Description -match "Security|Update|Hotfix" -or $_.HotFixID -match "^KB" } |
                        Sort-Object InstalledOn -Descending)
                    foreach ($hotfix in $hotfixes) {
                        $key = if ($hotfix.HotFixID) { [string]$hotfix.HotFixID } else { [string]$hotfix.Description }
                        if (-not $key -or $seenUpdates.ContainsKey($key)) { continue }

                        $seenUpdates[$key] = $true
                        $installed = if ($hotfix.InstalledOn) { Format-ReportDate $hotfix.InstalledOn } else { "-" }
                        $updateLines.Add(("{0} | {1} | {2}" -f $installed, $hotfix.HotFixID, $hotfix.Description)) | Out-Null
                        if ($updateLines.Count -ge 10) { break }
                    }
                } catch {}
            }

            if ($updateLines.Count -eq 0) {
                Add-ReportLine "Keine installierten Windows-Updates ermittelt."
            } else {
                foreach ($line in $updateLines) { Add-ReportLine $line }
            }
            Add-ReportLine ""

            Add-ReportLine "Treiberfehler"
            Add-ReportLine "-------------"
            $problemDevices = @()
            if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
                $problemDevices = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Problem -ne $null -and [int]$_.Problem -ne 0 })
            }
            if ($problemDevices.Count -eq 0) {
                Add-ReportLine "Keine vorhandenen Geräte mit Problemcode erkannt."
            } else {
                foreach ($dev in $problemDevices) {
                    Add-ReportLine ("{0} | Code {1} | {2}" -f $dev.FriendlyName, $dev.Problem, $dev.InstanceId)
                }
                $warnings.Add("Treiber-/Geräteprobleme erkannt: $($problemDevices.Count)") | Out-Null
            }
            Add-ReportLine ""

            Add-ReportLine "Netzwerk"
            Add-ReportLine "--------"
            $configs = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq "Up" })
            if ($configs.Count -eq 0) {
                Add-ReportLine "Kein aktiver Netzwerkadapter gefunden."
                $warnings.Add("Kein aktiver Netzwerkadapter gefunden.") | Out-Null
            } else {
                foreach ($cfg in ($configs | Select-Object -First 4)) {
                    $adapter = Get-NetAdapter -InterfaceIndex $cfg.InterfaceIndex -ErrorAction SilentlyContinue
                    $ipv4 = $cfg.IPv4Address | Select-Object -First 1
                    $mode = "-"
                    if ($ipv4) {
                        if ($ipv4.PrefixOrigin -eq "Dhcp") { $mode = "DHCP" }
                        elseif ($ipv4.PrefixOrigin -eq "Manual") { $mode = "Statisch" }
                    }
                    $ipText = if ($ipv4) { "{0} ({1})" -f $ipv4.IPAddress, $mode } else { "Keine IPv4" }
                    $gwText = if ($cfg.IPv4DefaultGateway) { (($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop) } else { "-" }
                    $dnsText = if ($cfg.DNSServer.ServerAddresses) { (@($cfg.DNSServer.ServerAddresses) -join ", ") } else { "-" }
                    $speedText = if ($adapter) { $adapter.LinkSpeed } else { "-" }
                    Add-ReportLine ("Adapter: {0} | {1} | {2}" -f $cfg.InterfaceAlias, $ipText, $speedText)
                    Add-ReportLine ("  Gateway: {0}" -f $gwText)
                    Add-ReportLine ("  DNS: {0}" -f $dnsText)
                }
            }
            try {
                Resolve-DnsName "www.microsoft.com" -ErrorAction Stop | Out-Null
                Add-ReportLine "DNS-Test: OK"
            } catch {
                Add-ReportLine "DNS-Test: Fehlgeschlagen"
                $warnings.Add("DNS-Auflösung fehlgeschlagen.") | Out-Null
            }
            try {
                Invoke-WebRequest -Uri "https://www.microsoft.com" -UseBasicParsing -Method Head -TimeoutSec 10 -ErrorAction Stop | Out-Null
                Add-ReportLine "HTTPS-Test: OK"
            } catch {
                Add-ReportLine "HTTPS-Test: Fehlgeschlagen"
                $warnings.Add("HTTPS-Verbindung fehlgeschlagen.") | Out-Null
            }
            $winHttpProxy = (netsh winhttp show proxy) -join " "
            if ($winHttpProxy -match "Direkter Zugriff|Direct access|DirectAccess|kein Proxyserver") {
                Add-ReportLine "WinHTTP-Proxy: Nicht konfiguriert"
            } else {
                Add-ReportLine "WinHTTP-Proxy: Konfiguriert"
                $warnings.Add("WinHTTP-Proxy ist konfiguriert.") | Out-Null
            }
            Add-ReportLine ""

            Add-ReportLine "Sicherheitsstatus"
            Add-ReportLine "-----------------"
            if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
                $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
                if ($mp) {
                    if ($mp.RealTimeProtectionEnabled) {
                        Add-ReportLine "Defender Echtzeitschutz: Aktiv"
                    } else {
                        Add-ReportLine "Defender Echtzeitschutz: Nicht aktiv"
                        $warnings.Add("Defender Echtzeitschutz ist nicht aktiv.") | Out-Null
                    }
                    if ($mp.AntivirusSignatureLastUpdated) {
                        Add-ReportLine ("Defender Signaturen: {0}" -f (Format-ReportDate $mp.AntivirusSignatureLastUpdated))
                    }
                }
            } else {
                Add-ReportLine "Defender: Cmdlets nicht verfügbar."
            }
            $profiles = @(Get-NetFirewallProfile -ErrorAction SilentlyContinue)
            if ($profiles.Count -gt 0) {
                $disabled = @($profiles | Where-Object { -not $_.Enabled })
                if ($disabled.Count -eq 0) {
                    Add-ReportLine "Firewall: In allen Profilen aktiv"
                } else {
                    Add-ReportLine ("Firewall: Deaktiviert für {0}" -f (($disabled | ForEach-Object Name) -join ", "))
                    $warnings.Add("Firewall ist in mindestens einem Profil deaktiviert.") | Out-Null
                }
            }
            if (Get-Command Get-Tpm -ErrorAction SilentlyContinue) {
                $tpm = Get-Tpm -ErrorAction SilentlyContinue
                if ($tpm -and $tpm.TpmPresent -and $tpm.TpmReady) { Add-ReportLine "TPM: Vorhanden und bereit" }
                elseif ($tpm -and $tpm.TpmPresent) {
                    Add-ReportLine "TPM: Vorhanden, aber nicht bereit"
                    $warnings.Add("TPM vorhanden, aber nicht bereit.") | Out-Null
                } else { Add-ReportLine "TPM: Nicht vorhanden oder nicht verfügbar" }
            }
            if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
                $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
                if ($bl) { Add-ReportLine ("BitLocker C: {0}" -f $bl.ProtectionStatus) }
            }
            $uac = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction SilentlyContinue
            if ($uac -and $uac.EnableLUA -eq 1) { Add-ReportLine "UAC: Aktiv" }
            else {
                Add-ReportLine "UAC: Deaktiviert"
                $warnings.Add("UAC ist deaktiviert.") | Out-Null
            }
            $rdp = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -ErrorAction SilentlyContinue
            if ($rdp -and $rdp.fDenyTSConnections -eq 0) { Add-ReportLine "Remote Desktop: Aktiviert" }
            else { Add-ReportLine "Remote Desktop: Deaktiviert" }
            Add-ReportLine ""

            $start = (Get-Date).AddDays(-14)

            Add-ReportLine "Kritische Ereignisse (14 Tage)"
            Add-ReportLine "-----------------------------"
            $criticalEvents = @()
            $criticalEvents += @(Get-WinEvent -FilterHashtable @{ LogName = "System"; StartTime = $start; Level = 1 } -ErrorAction SilentlyContinue)
            $criticalEvents += @(Get-WinEvent -FilterHashtable @{ LogName = "Application"; StartTime = $start; Level = 1 } -ErrorAction SilentlyContinue)
            $criticalGroups = $criticalEvents | Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 15
            if ($criticalGroups.Count -eq 0) {
                Add-ReportLine "Keine kritischen System-/Anwendungsereignisse der letzten 14 Tage gefunden."
            } else {
                foreach ($group in $criticalGroups) {
                    $sample = $group.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1
                    Add-ReportLine ("{0} x {1}, Event-ID {2}, letztes: {3}" -f $group.Count, $sample.ProviderName, $sample.Id, $sample.TimeCreated)
                }
                $warnings.Add("Kritische Ereignisse der letzten 14 Tage gefunden.") | Out-Null
            }
            Add-ReportLine ""

            Add-ReportLine "Kritischer Zuverlässigkeitsverlauf (14 Tage)"
            Add-ReportLine "-------------------------------------------"
            $reliabilityItems = @()
            try {
                $reliabilityItems = @(Get-CimInstance Win32_ReliabilityRecords -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.TimeGenerated -and ([datetime]$_.TimeGenerated) -ge $start -and
                        $_.EventType -in 1,2,3 -and
                        ($_.SourceName -or $_.ProductName)
                    })
            } catch {
                $reliabilityItems = @()
            }
            $reliabilityGroups = $reliabilityItems |
                Group-Object SourceName, ProductName, EventIdentifier |
                Sort-Object Count -Descending |
                Select-Object -First 15
            if ($reliabilityGroups.Count -eq 0) {
                Add-ReportLine "Keine kritischen Einträge im Zuverlässigkeitsverlauf der letzten 14 Tage gefunden."
            } else {
                foreach ($group in $reliabilityGroups) {
                    $sample = $group.Group | Sort-Object TimeGenerated -Descending | Select-Object -First 1
                    $name = if ($sample.ProductName) { $sample.ProductName } elseif ($sample.SourceName) { $sample.SourceName } else { "Unbekannt" }
                    $message = if ($sample.Message) { ($sample.Message -replace "`r|`n", " ") } else { "" }
                    if ($message.Length -gt 120) { $message = $message.Substring(0, 120) + "..." }
                    Add-ReportLine ("{0} x {1}, Event-ID {2}, letztes: {3}" -f $group.Count, $name, $sample.EventIdentifier, (Format-ReportDate $sample.TimeGenerated))
                    if ($message) { Add-ReportLine ("  {0}" -f $message) }
                }
                $warnings.Add("Kritische Einträge im Zuverlässigkeitsverlauf der letzten 14 Tage gefunden.") | Out-Null
            }
            Add-ReportLine ""

            Add-ReportLine "Autostart"
            Add-ReportLine "---------"
            $startupEntries = New-Object System.Collections.Generic.List[object]
            $runKeys = @(
                @{
                    Source = "HKLM Run"
                    Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
                    Approved = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
                },
                @{
                    Source = "HKCU Run"
                    Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                    Approved = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
                }
            )
            foreach ($key in $runKeys) {
                $props = Get-ItemProperty -Path $key.Path -ErrorAction SilentlyContinue
                if ($props) {
                    foreach ($prop in $props.PSObject.Properties) {
                        if ($prop.Name -notmatch "^PS" -and (Test-ReportStartupEnabled $key.Approved $prop.Name)) {
                            $startupEntries.Add([PSCustomObject]@{ Source = $key.Source; Name = $prop.Name; Command = [string]$prop.Value }) | Out-Null
                        }
                    }
                }
            }
            $startupFolders = @(
                @{ Source = "Benutzer-Autostart"; Path = [Environment]::GetFolderPath("Startup") },
                @{ Source = "System-Autostart"; Path = [Environment]::GetFolderPath("CommonStartup") }
            )
            foreach ($folder in $startupFolders) {
                if ($folder.Path -and (Test-Path $folder.Path)) {
                    Get-ChildItem -Path $folder.Path -File -ErrorAction SilentlyContinue | ForEach-Object {
                        $startupEntries.Add([PSCustomObject]@{ Source = $folder.Source; Name = $_.Name; Command = $_.FullName }) | Out-Null
                    }
                }
            }
            $logonTasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
                $_.State -ne "Disabled" -and ($_.Triggers | Where-Object { $_.CimClass.CimClassName -match "LogonTrigger" })
            } | Select-Object -First 20)
            foreach ($task in $logonTasks) {
                $startupEntries.Add([PSCustomObject]@{ Source = "Geplante Aufgabe"; Name = $task.TaskName; Command = $task.TaskPath }) | Out-Null
            }
            if ($startupEntries.Count -eq 0) {
                Add-ReportLine "Keine Autostarteinträge gefunden."
            } else {
                Add-ReportLine ("Autostarteinträge: {0}" -f $startupEntries.Count)
                $startupEntries | Select-Object -First 25 | ForEach-Object {
                    Add-ReportLine ("{0} | {1}" -f $_.Source, $_.Name)
                }
                if ($startupEntries.Count -gt 25) { Add-ReportLine ("... weitere {0} Einträge" -f ($startupEntries.Count - 25)) }
            }
            Add-ReportLine ""

            Add-ReportLine "Dienste"
            Add-ReportLine "-------"
            $autoStopped = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {
                $_.StartMode -eq "Auto" -and $_.State -ne "Running"
            } | Select-Object -First 25)
            if ($autoStopped.Count -eq 0) {
                Add-ReportLine "Keine auffälligen gestoppten Auto-Dienste gefunden."
            } else {
                Add-ReportLine ("Gestoppte Auto-Dienste: {0}" -f $autoStopped.Count)
                foreach ($svc in $autoStopped) {
                    Add-ReportLine ("{0} ({1}) - {2}" -f $svc.Name, $svc.State, $svc.DisplayName)
                }
                $warnings.Add("Automatisch gestartete Dienste sind aktuell nicht aktiv.") | Out-Null
            }
            $svcEvents = @(Get-WinEvent -FilterHashtable @{ LogName = "System"; ProviderName = "Service Control Manager"; StartTime = $start; Level = 2 } -ErrorAction SilentlyContinue)
            if ($svcEvents.Count -gt 0) {
                Add-ReportLine ("Service-Control-Manager-Fehler: {0}" -f $svcEvents.Count)
                $serviceEventItems = @($svcEvents | ForEach-Object {
                    [PSCustomObject]@{
                        Service = Get-ReportServiceNameFromEvent $_
                        Text = Get-ReportServiceEventText $_
                        TimeCreated = $_.TimeCreated
                    }
                })
                $serviceEventItems | Group-Object Service, Text | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
                    $sample = $_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1
                    Add-ReportLine ("{0} x {1} - {2}, letztes: {3}" -f $_.Count, $sample.Service, $sample.Text, $sample.TimeCreated)
                }
                $warnings.Add("Service-Control-Manager-Fehler der letzten 14 Tage gefunden.") | Out-Null
            } else {
                Add-ReportLine "Keine Service-Control-Manager-Fehler der letzten 14 Tage gefunden."
            }
            Add-ReportLine ""

            Add-ReportLine "Abschlussbewertung"
            Add-ReportLine "------------------"
            if ($warnings.Count -eq 0) {
                Add-ReportLine "[OK] Keine groben Auffälligkeiten in der Erstanalyse erkannt."
            } else {
                Add-ReportLine ("[WARNUNG] {0} Auffälligkeit(en) erkannt:" -f $warnings.Count)
                foreach ($warning in $warnings) {
                    Add-ReportLine ("- {0}" -f $warning)
                }
            }

            Set-Content -Path $path -Encoding UTF8 -Value $lines
            Write-ToolStatus "OK" "Bericht wurde erstellt."
            Write-Output ("Pfad: {0}" -f $path)
            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Bericht konnte nicht erstellt werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }

    # -------------------------------------------------------------------------
    # Secure Boot CA 2023 installieren / erneuern
    # -------------------------------------------------------------------------
    "secureboot_ca_install" {
        Write-Output "Secure Boot CA 2023 - Zertifikat-Installation"
        Write-Output "================================================"
        Write-Output ""

        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator
            )
            if (-not $isAdmin) {
                Write-ToolStatus "FEHLER" "Dieses Tool muss als Administrator ausgeführt werden."
                exit 1
            }

            $sbState = $false
            try {
                $sbState = Confirm-SecureBootUEFI -ErrorAction Stop
            }
            catch {
                $sbState = $false
            }

            if ($sbState -ne $true) {
                Write-ToolStatus "INFO" "Secure Boot ist nicht aktiv oder nicht verfügbar."
                Write-Output "Das CA 2023-Zertifikat wird nur bei aktivem UEFI Secure Boot benÖ."
                exit 0
            }

            Write-Output "Prüfe ob Windows UEFI CA 2023 bereits installiert ist ..."
            $ca2023Found = $false
            try {
                $dbVar = Get-SecureBootUEFI -Name db -ErrorAction Stop
                if ($dbVar -and $dbVar.Bytes) {
                    $dbStr = [System.Text.Encoding]::ASCII.GetString($dbVar.Bytes)
                    if ($dbStr -match "Windows UEFI CA 2023") { $ca2023Found = $true }
                    if ($dbStr -match "Microsoft UEFI CA 2023") { $ca2023Found = $true }
                }
            }
            catch {
                Write-ToolStatus "WARNUNG" "Secure-Boot-Datenbank konnte nicht vollständig gelesen werden."
                Write-Output $_.Exception.Message
            }

            if ($ca2023Found) {
                Write-ToolStatus "OK" "Windows UEFI CA 2023 ist bereits aktiv. Keine Installation erforderlich."
                exit 0
            }

            Write-ToolStatus "WARNUNG" "CA 2023 wurde nicht gefunden. Windows Update wird angestoßen."
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            Start-Service -Name cryptsvc -ErrorAction SilentlyContinue
            Start-Service -Name bits -ErrorAction SilentlyContinue

            Start-Process -FilePath "USOClient.exe" -ArgumentList "StartScan" -NoNewWindow -Wait -ErrorAction SilentlyContinue
            Start-Process -FilePath "USOClient.exe" -ArgumentList "StartInstall" -NoNewWindow -Wait -ErrorAction SilentlyContinue

            Write-ToolStatus "INFO" "Windows Update Scan und Installation wurden angestoßen."
            Write-Output "Bitte danach Windows Update prüfen, alle Updates installieren und neu starten."
            exit 0
        }
        catch {
            Write-ToolStatus "FEHLER" "Secure Boot CA 2023 Aktion konnte nicht abgeschlossen werden."
            Write-Output $_.Exception.Message
            exit 1
        }
    }
}
