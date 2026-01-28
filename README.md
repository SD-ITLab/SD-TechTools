<img width="1122" height="652" alt="image" src="https://github.com/user-attachments/assets/a1f7199f-f5c5-469f-95e3-dcf97134b21f" />

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://badgen.net/github/license/SD-ITLab/WinRep)

# 🛠️ SD TechTools – Windows Repair Toolbox

**SD TechTools – Windows Repair Toolbox** ist ein internes Diagnose- und Reparaturtool für Windows-Systeme,  
entwickelt für den **Werkstatt- und Serviceeinsatz** bei **SD-ITLab**.

Ab Version **4.0.0** wurde das ursprünglich rein PowerShell-basierte Tool vollständig auf eine **moderne Python-GUI** umgestellt.  
Die eigentlichen Reparatur- und Diagnoseaktionen werden weiterhin zuverlässig über PowerShell ausgeführt.

---

## 📌 Beschreibung

SD TechTools bündelt wichtige **Windows-Diagnose-, Reparatur- und Wartungsfunktionen** in einer übersichtlichen grafischen Oberfläche.

Ziel ist es, häufige Windows-Probleme **schnell, nachvollziehbar und reproduzierbar** zu analysieren und zu beheben –  
ohne manuelles Eintippen komplexer Befehle.

**Typische Einsatzbereiche:**
- PC- & Notebook-Reparatur
- Systemprüfung nach Hardwaretausch
- Windows-Fehlerdiagnose
- Kunden-Check & Werkstatt-Dokumentation

---

## 🖥️ Benutzeroberfläche (GUI)

Die Anwendung verfügt über eine **moderne, aufgeräumte Oberfläche**, optimiert für den täglichen Werkstattbetrieb:

- Kategorisierte Aktionen (links)
- Zentrale Aktionsauswahl
- **Live-Systemübersicht** (rechts)
- Ausführliches Log-Fenster
- Fortschrittsanzeige & Statusmeldungen

**Angezeigte Systeminformationen u. a.:**
- Windows-Version & Edition
- Boot-Modus (UEFI / BIOS + GPT/MBR)
- BitLocker-Status
- Primäre Netzwerk-IP
- Systemlaufwerk (Belegung)
- CPU-Modell

---

## 🚀 Verwendung

1. **SD TechTools.exe** (oder das Python-Skript) **als Administrator** starten  
2. Gewünschte Aktion aus der Liste auswählen  
3. Auf **„Aktion ausführen“** klicken  
4. Fortschritt & Ausgaben im Log verfolgen  
5. Nach Abschluss erscheint eine klare Statusmeldung

> ⚠️ Einige Aktionen (z. B. DISM, SFC, BitLocker, CHKDSK) erfordern Administratorrechte.

---

## 🛠️ Verfügbare Funktionen (Auszug)

### 🧩 Systemdateien / DISM
- Windows-Komponentenspeicher prüfen *(ScanHealth)*
- Prüfen, ob Windows als beschädigt markiert ist *(CheckHealth)*
- Automatische Reparaturvorgänge *(RestoreHealth)*
- Abgelöste Startkomponenten bereinigen *(ComponentCleanup)*
- Systemdateien prüfen & reparieren *(sfc /scannow)*
- Dateisystemprüfung von Laufwerk C: *(chkdsk)*

### 🌐 Netzwerk
- Netzwerk-Reset (DNS, Winsock, TCP/IP)

### 🧹 Cleanup / Updates
- Windows Update zurücksetzen
- Temporäre Dateien bereinigen

### ⚡ Leistung / Tuning
- Windows-Höchstleistungsmodus aktivieren
- Upgrade von Windows Home auf Windows Pro

### 🔍 Info & Tools
- Ausführliche Systeminformationen
- BitLocker-Status anzeigen / deaktivieren
- **Akku-Zustand analysieren (Notebooks)**

---

## 🔋 Akku-Zustand (ab Version 4.1.0)

Für Notebooks bietet SD TechTools eine **Akkuzustandsanalyse**:

- Erstellung eines **Windows-Batteriereports**
- Automatische Ablage auf dem **Desktop**
- Anzeige einer **Kurzbewertung im Log**, inkl.:
  - Designkapazität
  - Aktuelle volle Ladekapazität
  - Berechnete Akkugesundheit (%)
  - Bewertung (z. B. „gut“, „kritisch – Akkutausch empfohlen“)
  - Ladezyklen (falls vom Gerät unterstützt)

➡️ Ideal für **Kundenberatung & Kostenvoranschläge**.

---

## ℹ️ Hinweise

✔ Das Tool nutzt **ausschließlich Windows-Bordmittel** (DISM, SFC, powercfg, PowerShell)  
✔ Keine Installation erforderlich  
✔ Geeignet für **Windows 10 & Windows 11**  
✔ Desktop-PCs ohne Akku werden automatisch erkannt  
✔ Für internen Werkstatt- und Serviceeinsatz optimiert  

---

## 📝 Versionshistorie

### 🔹 Version 4.1.0
- Erweiterte Akku-Diagnose
- Automatischer Battery Report auf dem Desktop
- Akkugesundheit & Bewertung im Log

### 🔹 Version 4.0.0
- **Kompletter Umbau auf Python-GUI**
- Modernisierte Oberfläche
- Zentrale Systeminformationsanzeige
- Saubere Trennung von GUI (Python) & Aktionen (PowerShell)

### 🔹 Version 3.8.1
- Erweiterung Netzwerk-Reset (inkl. Proxy-Reset)
- Zusätzliche Systeminformationen

### 🔹 Version 3.6.x – 3.0.0
- Stabilitäts- & Performance-Optimierungen
- Erweiterung der Wiederherstellungsoptionen
- Integration zusätzlicher Diagnosefunktionen

---

## 📄 Lizenz

MIT License  
© 2026 **SD-ITLab**

Dieses Tool wurde für den internen Einsatz entwickelt, kann aber frei angepasst und erweitert werden.

---
# ENGLISH

# 🛠️ SD TechTools – Windows Repair Toolbox

**SD TechTools – Windows Repair Toolbox** is an internal Windows diagnostic and repair tool,  
developed for **workshop and service environments** at **SD-ITLab**.

Starting with version **4.0.0**, the tool was fully migrated from a pure PowerShell script to a **modern Python-based GUI**.  
All repair and diagnostic actions are still executed reliably via PowerShell in the background.

---

## 📌 Description

SD TechTools combines essential **Windows diagnostic, repair, and maintenance functions** in a clean and structured graphical interface.

The goal is to analyze and resolve common Windows issues **quickly, transparently, and reproducibly**,  
without manually entering complex commands.

**Typical use cases:**
- PC & notebook repair
- System checks after hardware replacement
- Windows troubleshooting
- Customer diagnostics & workshop documentation

---

## 🖥️ Graphical User Interface (GUI)

The application features a **modern and workshop-optimized UI**, designed for daily service use:

- Categorized actions (left panel)
- Central action selection
- **Live system overview** (right panel)
- Detailed log output
- Progress bar & status messages

**Displayed system information includes:**
- Windows version & edition
- Boot mode (UEFI / BIOS + GPT/MBR)
- BitLocker status
- Primary network IP
- System drive usage
- CPU model

---

## 🚀 Usage

1. Start **SD TechTools.exe** (or the Python script) **as Administrator**
2. Select the desired action from the list
3. Click **“Run action”**
4. Follow progress and output in the log window
5. A clear status message is shown when the task completes

> ⚠️ Some actions (e.g. DISM, SFC, BitLocker, CHKDSK) require administrator privileges.

---

## 🛠️ Available Features (Excerpt)

### 🧩 System Files / DISM
- Check Windows component store *(ScanHealth)*
- Check if Windows is marked as corrupted *(CheckHealth)*
- Automatic repair operations *(RestoreHealth)*
- Clean up superseded components *(ComponentCleanup)*
- Scan & repair system files *(sfc /scannow)*
- Check file system on drive C: *(chkdsk)*

### 🌐 Network
- Network reset (DNS, Winsock, TCP/IP)

### 🧹 Cleanup / Updates
- Reset Windows Update components
- Clean temporary files

### ⚡ Performance / Tuning
- Enable Windows High Performance power plan
- Upgrade Windows Home to Windows Pro

### 🔍 Info & Tools
- Detailed system information
- Display / disable BitLocker status
- **Battery health analysis (notebooks)**

---

## 🔋 Battery Health (since version 4.1.0)

For notebooks, SD TechTools includes a **battery health analysis** feature:

- Generates a **Windows battery report**
- Automatically saves it to the **desktop**
- Displays a **quick summary in the log**, including:
  - Design capacity
  - Full charge capacity
  - Calculated battery health (%)
  - Condition rating (e.g. *good*, *critical – battery replacement recommended*)
  - Charge cycles (if supported by the device)

➡️ Ideal for **customer consultation and service estimates**.

---

## ℹ️ Notes

✔ Uses **Windows built-in tools only** (DISM, SFC, powercfg, PowerShell)  
✔ No installation required  
✔ Compatible with **Windows 10 & Windows 11**  
✔ Desktop PCs without batteries are detected automatically  
✔ Optimized for internal workshop and service use  

---

## 📝 Version History

### 🔹 Version 4.1.0
- Extended battery diagnostics
- Automatic battery report saved to desktop
- Battery health calculation & rating in log output

### 🔹 Version 4.0.0
- **Complete migration to Python GUI**
- Modernized user interface
- Central system information overview
- Clean separation of GUI (Python) and actions (PowerShell)

### 🔹 Version 3.8.1
- Extended network reset (including proxy reset)
- Additional system information

### 🔹 Version 3.6.x – 3.0.0
- Stability and performance improvements
- Extended recovery options
- Integration of additional diagnostic functions

---

## 📄 License

MIT License  
© 2026 **SD-ITLab**

This tool was developed for internal use but may be freely modified and extended.
