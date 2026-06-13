<img width="1282" height="792" alt="image" src="https://github.com/user-attachments/assets/7cef267a-259e-472e-bd29-abe2e44983d3" />

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://badgen.net/github/license/SD-ITLab/WinRep)

# 🛠️ SD TechTools - Windows Repair Toolbox

**Version 5.0.0**

SD TechTools ist ein Diagnose-, Wartungs- und Reparaturtool für Windows-Systeme.  
Es wurde für den Werkstatt- und Serviceeinsatz entwickelt und bündelt häufig benötigte Windows-Prüfungen in einer modernen Python-Oberfläche.

Die grafische Oberfläche läuft in Python, die eigentlichen Diagnose- und Reparaturaktionen werden über PowerShell und Windows-Bordmittel ausgeführt.

---

## 📌 Überblick

SD TechTools hilft dabei, typische Windows-Probleme schnell und nachvollziehbar zu prüfen:

- Windows-Komponentenspeicher und Systemdateien
- Netzwerk, DNS, Proxy und Internetverbindung
- Datenträgerzustand und Speicherplatz
- Treiber- und Geräteprobleme
- Sicherheitsstatus
- Windows Update und installierte Updates
- Akkuinformationen bei Notebooks
- Drucker und Druckwarteschlangen
- Zeit-/Zeitsynchronisierung
- Autostart- und Dienstediagnose
- kompakter Diagnosebericht für die Erstaufnahme

Ziel ist eine schnelle, reproduzierbare Erstdiagnose ohne manuelles Zusammensuchen einzelner Befehle.

---

## 🖥️ Benutzeroberfläche

Die Oberfläche ist für den täglichen Werkstattbetrieb aufgebaut:

- Kategorien links
- Aktionsliste in der Mitte
- Live-Systemübersicht rechts
- Logkonsole mit farbigen Statuszeilen
- Fortschritts- und Statusanzeige
- separater Button zum Erstellen eines Diagnoseberichts

Die Live-Systemübersicht zeigt unter anderem:

- Windows-Version und Edition
- Boot-Modus inklusive GPT/MBR
- SecureBoot / CA-2023-Status
- Netzwerk-IP der primären LAN-/Internetroute
- Systemlaufwerk C: inklusive Füllstandsbewertung
- BitLocker-Status
- CPU-Modell

---

## Diagnosebericht in Version 5.0.0

Der Bericht wurde in Version 5.0.0 als kompakte Erstaufnahme neu aufgebaut.

Der Button **Bericht erstellen** erzeugt eine TXT-Datei auf dem Desktop, zum Beispiel:

```text
SD-ITLab-TechTools-Bericht_20260613_021500.txt
```

Der Bericht enthält:

- Datum und Computername
- Windows-Version, Build und Aktivierungsstatus
- Boot-Modus, SecureBoot, Schnellstart und DISM CheckHealth
- Hardware: Hersteller/Modell, Mainboard, CPU, RAM, GPU/VRAM, BIOS
- Datenträgerübersicht
- Akkuinformationen, falls vorhanden
- letzte Windows Updates, dedupliziert nach KB, maximal 10 Einträge
- Gerätemanager-Probleme
- Netzwerkdiagnose mit aktiven Adaptern, IP, Gateway, DNS, DNS-Test, HTTPS-Test und Proxy
- Sicherheitsstatus mit Defender, Firewall, TPM, BitLocker, UAC und Remote Desktop
- kritische System-/Anwendungsereignisse der letzten 14 Tage
- kritische Einträge aus dem Zuverlässigkeitsverlauf der letzten 14 Tage
- aktive Autostarteinträge
- Dienstediagnose mit betroffenen Diensten und Service-Control-Manager-Fehlern
- Abschlussbewertung

---

## 🛠️ Funktionen

### 🧩 Systemdateien / DISM

- Windows-Komponentenspeicher prüfen: `ScanHealth`
- Prüfen, ob Windows als beschädigt markiert ist: `CheckHealth`
- Reparatur des Komponentenstores: `RestoreHealth`
- Komponentenstore bereinigen: `StartComponentCleanup`
- Systemdateien prüfen und reparieren: `sfc /scannow`
- Dateisystemprüfung von Laufwerk C:

### Diagnose

- Geräte- und Treiberprobleme prüfen
- Speicherplatz aller Laufwerke prüfen
- ausstehenden Neustart erkennen
- Datenträgerzustand prüfen
- Datenträgerereignisse auswerten
- Netzwerkdiagnose
- Windows-Update-Diagnose
- kompakte Ereignisdiagnose
- Sicherheitsstatus anzeigen
- Bluescreen- und Absturzdateien finden
- Autostartübersicht anzeigen
- Dienstediagnose anzeigen
- Druckerdiagnose anzeigen
- Zeit- und Zeitzonendiagnose anzeigen

### 🌐 Netzwerk

- DNS-Cache leeren
- Winsock zurücksetzen
- TCP/IP-Stack zurücksetzen
- IP erneuern
- Proxy zurücksetzen
- Firewall-Regeln auf Standard zurücksetzen

### 🧹 Cleanup / Updates

- Windows-Update-Komponenten zurücksetzen
- temporäre Dateien bereinigen
- Druckwarteschlange leeren und Spooler neu starten
- Windows-Zeit neu synchronisieren

### ⚡ Leistung / Tuning

- Windows-Höchstleistungsmodus aktivieren (Feintuned)
- Windows Home auf Windows Pro vorbereiten

### 🔍 Info & Tools

- ausführliche Systeminformationen
- BitLocker-Status anzeigen / BitLocker auf C: deaktivieren
- Akkuinformationen und Windows-Batteriereport
- Drucker-Testseite auslösen
- Diagnosebericht erstellen

### SecureBoot CA 2023

- SecureBoot / UEFI-CA-2023-Status prüfen
- Windows-Update-Vorgang für CA-2023-Aktualisierung anstoßen

---

## 🚀 Verwendung

1. `SD TechTools.exe` oder das Python-Skript als Administrator starten.
2. Kategorie und Aktion auswählen.
3. Auf **Aktion ausführen** klicken.
4. Ausgabe im Log verfolgen.
5. Bei Bedarf über **Bericht erstellen** eine TXT-Erstanalyse erzeugen.

⚠️ Einige Aktionen benötigen Administratorrechte, zum Beispiel DISM, SFC, BitLocker, CHKDSK, Windows Update Reset und Spooler-Reparaturen.

---

## Dateien

Wichtige Projektdateien:

```text
techtools.py              Python-GUI
techtools_actions.ps1     PowerShell-Aktionen
README.md                 Projektdokumentation
logo.png                  Logo für die Oberfläche
icon.ico                  Windows-Icon
```

## Voraussetzungen

- Windows 10 oder Windows 11
- PowerShell 5.1
- Administratorrechte für Reparaturfunktionen
- Python nur beim Start aus dem Quellcode erforderlich

Das Tool nutzt überwiegend Windows-Bordmittel:

- DISM
- SFC
- CHKDSK
- powercfg
- w32tm
- Get-CimInstance / Get-WinEvent
- Windows Update COM API
- NetTCPIP-PowerShell-Cmdlets

---

## Hinweise

- Reparaturaktionen können Systemzustand, Netzwerk, Update-Komponenten oder Druckwarteschlangen verändern.
- Die Aktion zum Leeren der Druckwarteschlange löscht offene Druckaufträge.
- CHKDSK-Reparaturen können einen Neustart erfordern.
- Der Diagnosebericht ist für die Erstaufnahme gedacht und ersetzt keine vollständige Fehleranalyse.

---

## Versionshistorie

### Version 5.0.0

- Umbenennung und Projektumbau von **WinRep** zu **TechTools**
- Überarbeitung des Overlays und der Live-Systemübersicht
- größere und besser lesbare Logkonsole
- farbliche Statusbewertung für Betriebssystem, Boot-Modus, SecureBoot, Netzwerk, BitLocker und Systemlaufwerk
- Einbindung der Prüfung für **SecureBoot CA 2023**
- neue und erweiterte Diagnosefunktionen, unter anderem:
  - Geräte- und Treiberprobleme
  - Datenträgerzustand und Datenträgerereignisse
  - Netzwerkdiagnose
  - Windows-Update-Diagnose
  - Sicherheitsstatus
  - Autostartübersicht
  - Dienstediagnose
  - Druckerdiagnose
  - Zeit- und Zeitzonendiagnose
- neuer Bericht für die schnelle Erstaufnahme eines Systems
- Bericht enthält unter anderem System, Hardware, Windows-Aktivierung, DISM CheckHealth, Schnellstart, SecureBoot, Netzwerk, Sicherheitsstatus, Updates, Treiberfehler, kritische Ereignisse, Autostart und Dienste
- Bericht ohne dauerhafte Aktionshistorie, damit keine zusätzliche Protokolldatei auf Geräten zurückbleibt
- RAM- und VRAM-Ausgabe im Bericht auf typische nominelle Größen verbessert

### Version 4.1.0

- erweiterte Akku-Diagnose
- automatischer Battery Report auf dem Desktop
- Akkugesundheit und Bewertung im Log

### Version 4.0.0

- kompletter Umbau auf Python-GUI
- modernisierte Oberfläche
- zentrale Systeminformationsanzeige
- Trennung von GUI in Python und Aktionen in PowerShell

### Version 3.8.1

- erweiterter Netzwerk-Reset inklusive Proxy-Reset
- zusätzliche Systeminformationen

### Version 3.6.x - 3.0.0

- Stabilitäts- und Performance-Optimierungen
- Erweiterung der Wiederherstellungsoptionen
- Integration zusätzlicher Diagnosefunktionen

---

## Lizenz

MIT License  
Copyright (c) 2026 SD-ITLab

Dieses Tool wurde für den Werkstatt- und Serviceeinsatz entwickelt und kann frei angepasst und erweitert werden.

---

# English

# SD TechTools - Windows Repair Toolbox

**Version 5.0.0**

SD TechTools is a Windows diagnostics, maintenance and repair toolbox designed for workshop and service environments.

The application uses a Python GUI while the diagnostic and repair actions are executed through PowerShell and native Windows tools.

## Key Features

- modern graphical interface
- live system overview
- DISM, SFC and CHKDSK actions
- network, update, security, printer and time diagnostics
- disk, battery, driver and event checks
- compact TXT diagnostic report for first analysis
- critical event and reliability history summary
- active startup entry and service diagnostics

## Version 5.0.0 Highlights

- project renamed and reworked from WinRep to TechTools
- refreshed overlay and live system overview
- improved log console readability
- SecureBoot CA 2023 check added
- expanded diagnostics for drivers, disks, network, Windows Update, security, startup entries, services, printers and time synchronization
- new first-analysis report for quick workshop intake
- report includes system, hardware, Windows activation, DISM CheckHealth, Fast Startup, SecureBoot, network, security, updates, driver issues, critical events, startup entries and services
- no persistent action history on customer systems
- improved RAM and VRAM display
- live overlay now prefers the LAN/default internet route over VPN addresses

## License

MIT License  
Copyright (c) 2026 SD-ITLa
