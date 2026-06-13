from __future__ import annotations

import locale
import json
import os
import socket
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List
import webbrowser
from tkinter import messagebox

import tkinter as tk
import customtkinter as ctk
try:
    from PIL import Image  # type: ignore[import]
    PIL_AVAILABLE = True
except Exception:
    Image = None  # type: ignore[assignment]
    PIL_AVAILABLE = False

# =============================================================================
# Basis-Konfiguration
# =============================================================================

APP_TITLE = "SD-ITLab TechTools"
WINDOW_SIZE = "1280x760"

BG_WINDOW = "#F1F5F9"         # Slate 100 - Base window background (grayish)
BG_PANEL = "#FFFFFF"          # Pure white for main panels
BG_CARD = "#FFFFFF"           # White for cards
BG_CARD_SELECTED = "#F0F9FF"  # Very light blue for selection
BORDER_CARD = "#E2E8F0"       # Subtle border
BORDER_CARD_SELECTED = "#0EA5E9" # Modern vibrant blue accent
BG_RIGHT_PANEL = "#F8FAFC"    # Distinct right panel
TEXT_MAIN = "#0F172A"         # High contrast main text
TEXT_MUTED = "#64748B"        # Sleek slate gray for muted text
ACCENT = "#0EA5E9"            # Main accent color

CAT_COLORS = {
    "Alle": "#0EA5E9",
    "Systemdateien / DISM": "#3B82F6",   # Blue
    "Diagnose": "#06B6D4",                # Cyan
    "Netzwerk": "#10B981",               # Emerald
    "Cleanup / Updates": "#F59E0B",      # Amber
    "Leistung / Tuning": "#8B5CF6",      # Purple
    "Info & Tools": "#64748B",           # Slate
    "Secureboot CA 2023": "#14B8A6"      # Teal
}

CMD_ENCODING = "cp850"
PS_ENCODING = "cp850"

README_URL = "https://github.com/SD-ITLab/SD-TechTools"
LOGO_URL   = "https://sd-itlab.de"
BRAND_URL  = "https://sd-itlab.de"


def resource_path(rel: str) -> str:
    """Pfad-Helfer (PyInstaller-kompatibel)."""
    base = getattr(sys, "_MEIPASS", str(Path(__file__).resolve().parent))
    return str(Path(base) / rel)


# =============================================================================
# Aktionen
# =============================================================================

@dataclass(frozen=True)
class TechToolsAction:
    key: str
    title: str
    description: str
    category: str
    ps_command: str | None = None  # nur informativ, Logik liegt in PS1


ACTIONS: Dict[str, TechToolsAction] = {
    "dism_scanhealth": TechToolsAction(
        "dism_scanhealth",
        "Windows Komponentenspeicher auf Fehler prüfen [ScanHealth]",
        "Prüft den Komponentenstore auf Beschädigungen.",
        "Systemdateien / DISM",
        ps_command="DISM /Online /Cleanup-Image /ScanHealth",
    ),
    "dism_checkhealth": TechToolsAction(
        "dism_checkhealth",
        "Prüfen, ob Windows als beschädigt markiert ist [CheckHealth]",
        "Zeigt an, ob Windows als beschädigt markiert wurde.",
        "Systemdateien / DISM",
        ps_command="DISM /Online /Cleanup-Image /CheckHealth",
    ),
    "dism_restorehealth": TechToolsAction(
        "dism_restorehealth",
        "Automatische Reparaturvorgänge durchführen [RestoreHealth]",
        "Versucht, beschädigte Dateien zu reparieren.",
        "Systemdateien / DISM",
        ps_command="DISM /Online /Cleanup-Image /RestoreHealth",
    ),
    "dism_componentcleanup": TechToolsAction(
        "dism_componentcleanup",
        "Abgelöste Startkomponenten bereinigen [ComponentCleanup]",
        "Bereinigt den Komponentenstore und entfernt veraltete Komponenten.",
        "Systemdateien / DISM",
        ps_command="DISM /Online /Cleanup-Image /StartComponentCleanup",
    ),
    "sfc_scannow": TechToolsAction(
        "sfc_scannow",
        "Systemdateien prüfen & reparieren [sfc /scannow]",
        "Prüft Systemdateien und stellt Originale wieder her.",
        "Systemdateien / DISM",
        ps_command="sfc /scannow",
    ),
    "net_reset": TechToolsAction(
        "net_reset",
        "Netzwerkeinstellungen zurücksetzen [FlushDNS usw.]",
        "Setzt DNS-Cache, Winsock und wichtige Netzwerk-Stacks zurück.",
        "Netzwerk",
    ),
    "wu_reset": TechToolsAction(
        "wu_reset",
        "Windows Updates zurücksetzen / Cache bereinigen",
        "Bereinigt den Update-Cache und setzt Windows Update Komponenten zurück.",
        "Cleanup / Updates",
    ),
    "temp_cleanup": TechToolsAction(
        "temp_cleanup",
        "Temporäre Dateien bereinigen",
        "Löscht TEMP-Ordner & unnötige Dateien.",
        "Cleanup / Updates",
    ),
    "upgrade_pro": TechToolsAction(
        "upgrade_pro",
        "Upgrade von Windows Home auf Windows Pro",
        "Setzt den Product Key für das Upgrade auf Windows Pro.",
        "Leistung / Tuning",
    ),
    "power_high": TechToolsAction(
        "power_high",
        "Windows Höchstleistungsmodus aktivieren",
        "Aktiviert den Windows-Höchstleistungsmodus, sofern verfügbar.",
        "Leistung / Tuning",
    ),
    "sysinfo": TechToolsAction(
        "sysinfo",
        "Systeminformationen anzeigen",
        "Zeigt ausführliche Systeminformationen an.",
        "Info & Tools",
        ps_command="systeminfo",
    ),
    "chkdsk_c": TechToolsAction(
        "chkdsk_c",
        "Dateisystem von C: prüfen [chkdsk]",
        "Führt eine Dateisystemprüfung von Laufwerk C: (online /scan) durch.",
        "Systemdateien / DISM",
    ),
    "bitlocker_disable": TechToolsAction(
        "bitlocker_disable",
        "BitLocker auf Laufwerk C: deaktivieren",
        "Deaktiviert BitLocker auf C:. Achtung: Entschlüsselung kann lange dauern!",
        "Info & Tools",
    ),
    "battery_info": TechToolsAction(
        "battery_info",
        "Akkuinformationen anzeigen",
        "Zeigt Informationen zum Akku (Ladestand, Status usw.), falls vorhanden.",
        "Info & Tools",
    ),
    "device_driver_check": TechToolsAction(
        "device_driver_check",
        "Geräte- und Treiberprobleme prüfen",
        "Prüft vorhandene Geräte auf Windows-Problemcodes (read-only).",
        "Diagnose",
    ),
    "disk_space_check": TechToolsAction(
        "disk_space_check",
        "Speicherplatz aller Laufwerke prüfen",
        "Bewertet lokale Dateisystemlaufwerke nach freiem Speicher.",
        "Diagnose",
    ),
    "pending_reboot_check": TechToolsAction(
        "pending_reboot_check",
        "Ausstehenden Neustart erkennen",
        "Prüft Windows Update, CBS und weitere Neustart-Marker (read-only).",
        "Diagnose",
    ),
    "disk_health_check": TechToolsAction(
        "disk_health_check",
        "Datenträgerzustand prüfen",
        "Prüft Windows-Zustandsdaten, SMART-Hinweise und Fehlerzähler.",
        "Diagnose",
    ),
    "disk_event_check": TechToolsAction(
        "disk_event_check",
        "Datenträgerereignisse auswerten",
        "Sucht relevante Speicher- und Dateisystemereignisse der letzten 30 Tage.",
        "Diagnose",
    ),
    "network_diag": TechToolsAction(
        "network_diag",
        "Netzwerkdiagnose ausführen",
        "Prüft Adapter, IP-Konfiguration, DNS, Gateway, Proxy und HTTPS.",
        "Diagnose",
    ),
    "wu_diag": TechToolsAction(
        "wu_diag",
        "Windows-Update-Diagnose anzeigen",
        "Prüft Update-Dienste, Updatefehler und ausstehenden Neustart.",
        "Diagnose",
    ),
    "event_diag": TechToolsAction(
        "event_diag",
        "Kompakte Ereignisdiagnose anzeigen",
        "Fasst relevante System- und Anwendungsereignisse der letzten 7 Tage zusammen.",
        "Diagnose",
    ),
    "security_status": TechToolsAction(
        "security_status",
        "Sicherheitsstatus anzeigen",
        "Prüft Defender, Firewall, Secure Boot, TPM, BitLocker und weitere Basisfunktionen.",
        "Diagnose",
    ),
    "dump_check": TechToolsAction(
        "dump_check",
        "Bluescreen- und Absturzdateien finden",
        "Sucht Minidumps, MEMORY.DMP und LiveKernelReports (read-only).",
        "Diagnose",
    ),
    "startup_overview": TechToolsAction(
        "startup_overview",
        "Autostartübersicht anzeigen",
        "Listet Registry-, Ordner- und Aufgaben-Autostarts ohne Änderungen auf.",
        "Diagnose",
    ),
    "service_diag": TechToolsAction(
        "service_diag",
        "Dienstediagnose anzeigen",
        "Prüft auffällige Dienste und Service-Control-Manager-Ereignisse.",
        "Diagnose",
    ),
    "printer_diag": TechToolsAction(
        "printer_diag",
        "Druckerdiagnose anzeigen",
        "Zeigt Drucker, Standarddrucker, Warteschlangen, Ports und Spoolerstatus.",
        "Diagnose",
    ),
    "printer_queue_clear": TechToolsAction(
        "printer_queue_clear",
        "Druckwarteschlange leeren / Spooler neu starten",
        "Löscht offene Druckaufträge und startet den Druckspooler neu.",
        "Cleanup / Updates",
    ),
    "printer_test_page": TechToolsAction(
        "printer_test_page",
        "Drucker-Testseite drucken",
        "Druckt eine Windows-Testseite auf dem Standarddrucker.",
        "Info & Tools",
    ),
    "time_diag": TechToolsAction(
        "time_diag",
        "Zeit- und Zeitzonendiagnose anzeigen",
        "Zeigt Zeitzone, Zeitdienst, Zeitquelle und Synchronisierungsstatus.",
        "Diagnose",
    ),
    "time_resync": TechToolsAction(
        "time_resync",
        "Windows-Zeit neu synchronisieren",
        "Stößt eine Zeitsynchronisierung mit w32tm /resync an.",
        "Cleanup / Updates",
    ),
    "report_export": TechToolsAction(
        "report_export",
        "Bericht erstellen",
        "Exportiert eine kompakte TXT-Erstanalyse auf den Desktop.",
        "Info & Tools",
    ),
    "secureboot_ca_install": TechToolsAction(
        "secureboot_ca_install",
        "Secure Boot CA 2023 Zertifikat installieren / erneuern",
        "Installiert das neue Microsoft UEFI CA 2023 Zertifikat über Windows Update (KB5036210). Empfohlen wenn CA 2023 fehlt.",
        "Secureboot CA 2023",
    ),
}

ACTION_ORDER: List[str] = [
    "dism_scanhealth",
    "dism_checkhealth",
    "dism_restorehealth",
    "dism_componentcleanup",
    "sfc_scannow",
    "chkdsk_c",
    "net_reset",
    "wu_reset",
    "temp_cleanup",
    "upgrade_pro",
    "power_high",
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
    "secureboot_ca_install",
    "bitlocker_disable",
    "battery_info",
    "sysinfo",
]


def sorted_action_keys(keys: List[str]) -> List[str]:
    def order_index(k: str) -> int:
        try:
            return ACTION_ORDER.index(k)
        except ValueError:
            return len(ACTION_ORDER) + 1

    return sorted(keys, key=order_index)


# =============================================================================
# UI: ActionRow
# =============================================================================

class ActionRow(ctk.CTkFrame):
    def __init__(self, master, action_key: str, on_click, width: int = 540):
        super().__init__(
            master,
            fg_color=BG_CARD,
            corner_radius=12,
        )

        self.action_key = action_key
        self.on_click = on_click
        self.selected = False

        self.configure(border_width=1, border_color=BORDER_CARD)
        self.grid_columnconfigure(0, weight=1)

        action = ACTIONS[action_key]

        self.title_lbl = ctk.CTkLabel(
            self,
            text=action.title,
            font=ctk.CTkFont(size=13, weight="bold"),
            text_color=TEXT_MAIN,
            anchor="w",
        )
        self.title_lbl.grid(row=0, column=0, sticky="w", padx=16, pady=(12, 2))

        self.desc_lbl = ctk.CTkLabel(
            self,
            text=action.description,
            font=ctk.CTkFont(size=11),
            text_color=TEXT_MUTED,
            anchor="w",
            justify="left",
            wraplength=width - 48,
        )
        self.desc_lbl.grid(row=1, column=0, sticky="w", padx=16, pady=(0, 12))

        cat_color = CAT_COLORS.get(action.category, ACCENT)
        self.color_tag = ctk.CTkFrame(
            self,
            fg_color=cat_color,
            width=6,
            height=0,
            corner_radius=3
        )
        self.color_tag.grid(row=0, rowspan=2, column=1, sticky="ns", padx=(0, 12), pady=12)
        
        self.dummy = ctk.CTkFrame(self, height=0, width=width, fg_color="transparent")
        self.dummy.grid(row=2, column=0, columnspan=2, sticky="ew")

        for w in (self, self.title_lbl, self.desc_lbl, self.color_tag):
            w.bind("<Button-1>", self._on_click_internal)
            w.bind("<Enter>", self._on_hover)
            w.bind("<Leave>", self._on_leave)

    def _on_hover(self, _event=None):
        if not self.selected:
            self.configure(border_color="#CBD5E1")
            
    def _on_leave(self, _event=None):
        if not self.selected:
            self.configure(border_color=BORDER_CARD)

    def _on_click_internal(self, _event=None):
        if callable(self.on_click):
            self.on_click(self.action_key)

    def set_selected(self, selected: bool):
        self.selected = selected
        try:
            if selected:
                self.configure(fg_color=BG_CARD_SELECTED, border_color=BORDER_CARD_SELECTED)
            else:
                self.configure(fg_color=BG_CARD, border_color=BORDER_CARD)
        except tk.TclError:
            pass

    def set_width(self, width: int):
        self.configure(width=width)
        self.dummy.configure(width=width)
        self.desc_lbl.configure(wraplength=max(180, width - 48))


# =============================================================================
# Main-App
# =============================================================================

class TechToolsApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        ctk.set_appearance_mode("light")
        ctk.set_default_color_theme("blue")

        self.title(APP_TITLE)
        self.geometry(WINDOW_SIZE)
        self.minsize(1120, 620)
        self.resizable(True, True)
        self.protocol("WM_DELETE_WINDOW", self._close_app)
        self.configure(fg_color=BG_WINDOW)

        self._set_window_icon()

        self.category_var = tk.StringVar(value="Alle")
        self.selected_action: str | None = None
        self.session_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        self._delete_action_history()

        self.rows: Dict[str, ActionRow] = {}
        self._list_resize_after_id: str | None = None

        self.sys_computer = tk.StringVar(value="-")
        self.sys_os = tk.StringVar(value="-")
        self.sys_ip = tk.StringVar(value="-")
        self.sys_cpu = tk.StringVar(value="-")
        self.sys_boot = tk.StringVar(value="-")
        self.sys_bitlocker = tk.StringVar(value="-")
        self.sys_disk = tk.StringVar(value="-")
        self.sys_disk_free_percent: float | None = None
        self.sys_has_internet: bool | None = None
        self.sys_secureboot = tk.StringVar(value="-")

        self.bottom_logo = None  # Referenz für CTkImage

        self._build_layout()

        self.after(0, self._initial_render)
        self.after(200, self._load_system_info_async)

    def _open_url(self, url: str):
        try:
            webbrowser.open(url, new=2)
        except Exception as exc:
            messagebox.showinfo(
                "Info",
                f"Link konnte nicht geöffnet werden:\n{exc}"
            )
    # -------------------------------------------------------------------------
    # Icon
    # -------------------------------------------------------------------------

    def _set_window_icon(self):
        candidates = ["techtools.ico", "TechTools.ico", "icon.ico", "winrep.ico", "WinRep.ico"]
        for name in candidates:
            path = Path(resource_path(name))
            if path.exists():
                try:
                    self.iconbitmap(str(path))
                except Exception:
                    pass
                break

    # -------------------------------------------------------------------------
    # Layout
    # -------------------------------------------------------------------------

    def _build_layout(self):
        # Root: 2 Zeilen (Hauptbereich + Footer), 2 Spalten (links + Hauptbereich)
        self.grid_rowconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=0)
        self.grid_columnconfigure(0, weight=0)  # linke Spalte
        self.grid_columnconfigure(1, weight=1)  # Mitte + Rechts + Footer

        # --------------------------- Linke Spalte -----------------------------
        LEFT_PANEL_WIDTH = 190
        left = ctk.CTkFrame(self, fg_color=BG_PANEL, border_width=1, border_color=BORDER_CARD, corner_radius=12, width=LEFT_PANEL_WIDTH)
        left.grid(row=0, column=0, rowspan=2, sticky="nsew", padx=(16, 8), pady=16)
        left.grid_propagate(False)
        left.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(
            left,
            text="Kategorien",
            font=ctk.CTkFont(size=14, weight="bold"),
            text_color=TEXT_MAIN,
        ).grid(row=0, column=0, sticky="w", padx=12, pady=(8, 12))

        cats = ["Alle"] + sorted({a.category for a in ACTIONS.values()})
        self.cat_buttons: List[tuple[str, ctk.CTkButton, ctk.CTkFrame]] = []

        for i, cat in enumerate(cats, start=1):
            cat_color = CAT_COLORS.get(cat, ACCENT)
            
            row_frame = ctk.CTkFrame(left, fg_color="transparent")
            row_frame.grid(row=i, column=0, sticky="ew", padx=10, pady=2)
            row_frame.grid_columnconfigure(0, weight=1)

            btn = ctk.CTkButton(
                row_frame,
                text=f"   {cat}",
                height=34,
                fg_color=BG_CARD_SELECTED if cat == "Alle" else BG_CARD,
                border_width=1,
                border_color=(BORDER_CARD_SELECTED if cat == "Alle" else BG_CARD),
                text_color=TEXT_MAIN,
                hover_color="#E2E8F0",
                font=ctk.CTkFont(size=12, weight="bold" if cat == "Alle" else "normal"),
                anchor="w",
                command=lambda c=cat: self._set_category(c),
            )
            btn.grid(row=0, column=0, sticky="ew")

            color_bar = ctk.CTkFrame(
                row_frame,
                fg_color=cat_color,
                width=4,
                height=0,
                corner_radius=2
            )
            color_bar.place(relx=0, rely=0.15, relheight=0.7, x=4)

            self.cat_buttons.append((cat, btn, color_bar))

        spacer_row = len(cats) + 1
        left.grid_rowconfigure(spacer_row, weight=1)

        logo_box = ctk.CTkFrame(
            left,
            fg_color=BG_PANEL,
            corner_radius=12,
            border_width=0,
            width=LEFT_PANEL_WIDTH,
            height=120,
        )
        logo_box.grid(row=spacer_row + 1, column=0, sticky="sew", padx=4, pady=(0, 4))
        logo_box.grid_propagate(False)

        self.logo_label = ctk.CTkLabel(logo_box, text="")
        self.logo_label.place(relx=0.5, rely=0.5, anchor="center")
        self.logo_label.configure(cursor="hand2")
        self.logo_label.bind("<Button-1>", lambda e: self._open_url(LOGO_URL))
        self._load_bottom_logo()

        # -------------------------- Hauptbereich ------------------------------
        main = ctk.CTkFrame(self, fg_color=BG_WINDOW)
        main.grid(row=0, column=1, sticky="nsew", padx=0, pady=0)
        main.grid_rowconfigure(0, weight=1)
        main.grid_columnconfigure(0, weight=1)  # Mitte
        main.grid_columnconfigure(1, weight=0)  # Rechts

        # Mitte: Aktionen
        mid = ctk.CTkFrame(main, fg_color=BG_PANEL, border_width=1, border_color=BORDER_CARD, corner_radius=12, width=540)
        mid.grid(row=0, column=0, sticky="nsew", padx=(8, 8), pady=(16, 8))
        mid.grid_propagate(False)
        mid.grid_columnconfigure(0, weight=1)
        mid.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(
            mid,
            text="Aktionen auswählen",
            font=ctk.CTkFont(size=18, weight="bold"),
            text_color=TEXT_MAIN,
        ).grid(row=0, column=0, sticky="w", padx=12, pady=(8, 12))

        list_wrapper = ctk.CTkFrame(mid, fg_color=BG_PANEL)
        list_wrapper.grid(row=1, column=0, sticky="nsew", padx=4, pady=(0, 4))
        list_wrapper.grid_columnconfigure(0, weight=1)
        list_wrapper.grid_rowconfigure(0, weight=1)

        self.list_scroll = ctk.CTkScrollableFrame(
            list_wrapper,
            fg_color=BG_PANEL,
            corner_radius=0,
        )
        self.list_scroll.grid(row=0, column=0, sticky="nsew")
        self.list_scroll.grid_columnconfigure(0, weight=1)

        canvas = getattr(self.list_scroll, "_parent_canvas", None)
        if canvas is not None:
            canvas.bind("<Configure>", self._on_list_canvas_configure)

        # Rechts: Systeminfos + Log
        right = ctk.CTkFrame(main, fg_color=BG_PANEL, border_width=1, border_color=BORDER_CARD, corner_radius=12, width=500)
        right.grid(row=0, column=1, sticky="nsew", padx=(8, 16), pady=(16, 8))
        right.grid_propagate(False)
        right.grid_columnconfigure(0, weight=1)
        right.grid_rowconfigure(3, weight=1)

        header = ctk.CTkFrame(right, fg_color="transparent")
        header.grid(row=0, column=0, sticky="ew", padx=6, pady=(10, 8))
        header.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(
            header,
            text="SD-ITLab - TechTools",
            font=ctk.CTkFont(size=18, weight="bold"),
            text_color=TEXT_MAIN,
        ).grid(row=0, column=0, sticky="w")

        sys_box = ctk.CTkFrame(
            right,
            fg_color=BG_RIGHT_PANEL,
            corner_radius=12,
            border_width=1,
            border_color=BORDER_CARD,
        )
        sys_box.grid(row=1, column=0, sticky="ew", padx=4, pady=(4, 6))
        sys_box.grid_columnconfigure(0, weight=0)
        sys_box.grid_columnconfigure(1, weight=1)

        def add_row(r: int, label: str, var: ctk.StringVar, bottom_pad: int = 3):
            top_pad = 8 if r == 0 else 3
            ctk.CTkLabel(
                sys_box,
                text=label,
                text_color=TEXT_MUTED,
                anchor="nw",
                font=ctk.CTkFont(size=11),
            ).grid(row=r, column=0, sticky="nw", padx=14, pady=(top_pad, bottom_pad))

            value_label = ctk.CTkLabel(
                sys_box,
                textvariable=var,
                text_color=TEXT_MAIN,
                anchor="nw",
                justify="left",
                wraplength=230,
                font=ctk.CTkFont(size=11, weight="bold"),
            )
            value_label.grid(row=r, column=1, sticky="nw", padx=14, pady=(top_pad, bottom_pad))
            return value_label

        self._os_value_label = add_row(0, "Betriebssystem:", self.sys_os)
        add_row(1, "Prozessor:", self.sys_cpu)
        self._boot_value_label = add_row(2, "Boot:", self.sys_boot)

        # SecureBoot CA – direkte Label-Referenz für spätere Färbung
        ctk.CTkLabel(
            sys_box,
            text="SecureBoot CA:",
            text_color=TEXT_MUTED,
            anchor="nw",
            font=ctk.CTkFont(size=11),
        ).grid(row=3, column=0, sticky="nw", padx=14, pady=(3, 3))

        self._secureboot_value_label = ctk.CTkLabel(
            sys_box,
            textvariable=self.sys_secureboot,
            text_color=TEXT_MAIN,
            anchor="nw",
            justify="left",
            wraplength=230,
            font=ctk.CTkFont(size=11, weight="bold"),
        )
        self._secureboot_value_label.grid(row=3, column=1, sticky="nw", padx=14, pady=(3, 3))

        self._ip_value_label = add_row(4, "Netzwerk-IP:", self.sys_ip)
        self._disk_value_label = add_row(5, "Systemlaufwerk C:\\", self.sys_disk)
        self._bitlocker_value_label = add_row(6, "BitLocker:", self.sys_bitlocker, bottom_pad=8)

        ctk.CTkLabel(
            right,
            text="Aktuelles Log:",
            font=ctk.CTkFont(size=12, weight="bold"),
            text_color=TEXT_MAIN,
        ).grid(row=2, column=0, sticky="w", padx=6, pady=(6, 2))

        self.log_text = ctk.CTkTextbox(
            right,
            height=360,
            fg_color=BG_CARD,
            text_color=TEXT_MAIN,
            border_width=1,
            border_color=BORDER_CARD,
            corner_radius=8,
            wrap="word",
            font=ctk.CTkFont(family="Consolas", size=11),
        )
        self.log_text.grid(row=3, column=0, sticky="nsew", padx=6, pady=(0, 8))
        self._configure_log_text_style()
        self._append_log("Hier erscheinen Ausgaben von TechTools-Aktionen …\n")
        self.log_text.configure(state="disabled")

        # ------------------------------ Footer -------------------------------
        footer = ctk.CTkFrame(self, corner_radius=12, fg_color=BG_PANEL, border_width=1, border_color=BORDER_CARD)
        footer.grid(row=1, column=1, sticky="ew", padx=(8, 16), pady=(8, 16))
        footer.grid_columnconfigure(0, weight=1)
        footer.grid_columnconfigure(1, weight=0)
        footer.grid_columnconfigure(2, weight=0)
        footer.grid_columnconfigure(3, weight=0)
        footer.grid_columnconfigure(4, weight=0)
        footer.grid_columnconfigure(5, weight=0)

        self.progress = ctk.CTkProgressBar(
            footer,
            progress_color=ACCENT,
            fg_color="#E5E7EB",
            height=10,
            corner_radius=999,
        )
        self.progress.grid(row=0, column=0, columnspan=5, sticky="ew", padx=(16, 16), pady=(8, 8))
        self.progress.set(0.0)

        self.status_lbl = ctk.CTkLabel(
            footer,
            text="Bereit.",
            text_color=TEXT_MUTED,
            font=ctk.CTkFont(size=10),
        )
        self.status_lbl.grid(row=1, column=0, sticky="w", padx=16, pady=(0, 12))

        self.footer_brand = ctk.CTkLabel(
            footer,
            text="© 2026 SD-ITLab – MIT licensed",
            font=ctk.CTkFont(size=10),
            text_color=TEXT_MUTED,
            cursor="hand2",
        )
        self.footer_brand.grid(row=1, column=1, sticky="e", padx=(0, 12), pady=(0, 12))
        self.footer_brand.bind("<Button-1>", lambda e: self._open_url(BRAND_URL))
        self.footer_brand.bind("<Enter>", lambda e: self.footer_brand.configure(text_color=ACCENT))
        self.footer_brand.bind("<Leave>", lambda e: self.footer_brand.configure(text_color=TEXT_MUTED))


        self.btn_readme = ctk.CTkButton(
            footer,
            text="Readme",
            width=100,
            command=lambda: self._open_url(README_URL),
        )
        self.btn_readme.grid(row=1, column=2, padx=6, pady=(0, 12))

        self.btn_report = ctk.CTkButton(
            footer,
            text="Bericht erstellen",
            width=135,
            command=self._run_report_action,
        )
        self.btn_report.grid(row=1, column=3, padx=6, pady=(0, 12))

        self.btn_run = ctk.CTkButton(
            footer,
            text="Aktion ausführen",
            width=130,
            command=self._run_selected_action,
        )
        self.btn_run.grid(row=1, column=4, padx=6, pady=(0, 12))

        self.btn_close = ctk.CTkButton(
            footer,
            text="Schließen",
            width=110,
            command=self._close_app,
        )
        self.btn_close.grid(row=1, column=5, padx=(6, 16), pady=(0, 12))



    # -------------------------------------------------------------------------
    # Logo
    # -------------------------------------------------------------------------

    def _load_bottom_logo(self):
        # Falls Pillow nicht geladen werden konnte (z. B. durch WDAC/Smart App Control),
        # einfach Text anzeigen und gar nicht erst versuchen, ein Bild zu laden.
        if not PIL_AVAILABLE:
            self.logo_label.configure(
                text="SD-ITLab TechTools\nby SD-ITLab",
                text_color=TEXT_MUTED,
                font=ctk.CTkFont(size=11, weight="bold"),
            )
            return

        try:
            logo_path = resource_path("logo.png")
            img = Image.open(logo_path).convert("RGBA")
        except Exception:
            # Fallback, wenn logo.png fehlt oder erneut etwas mit Pillow schiefgeht
            self.logo_label.configure(
                text="SD-ITLab TechTools\nby SD-ITLab",
                text_color=TEXT_MUTED,
                font=ctk.CTkFont(size=11, weight="bold"),
            )
            return

        max_width, max_height = 190, 100
        ratio = img.width / img.height

        if ratio > (max_width / max_height):
            new_w = max_width
            new_h = int(max_width / ratio)
        else:
            new_h = max_height
            new_w = int(max_height * ratio)

        img = img.resize((new_w, new_h), Image.LANCZOS)

        self.bottom_logo = ctk.CTkImage(
            light_image=img,
            dark_image=img,
            size=(new_w, new_h),
        )
        self.logo_label.configure(image=self.bottom_logo, text="")


    # -------------------------------------------------------------------------
    # Rendering / Filter
    # -------------------------------------------------------------------------

    def _get_row_width(self) -> int:
        try:
            canvas = getattr(self.list_scroll, "_parent_canvas", None)
            if canvas is not None:
                w = int(canvas.winfo_width() or 0)
                if w > 50:
                    return max(1, w - 28)
        except Exception:
            pass
        return 520 - 24

    def _on_list_canvas_configure(self, _event=None):
        if self._list_resize_after_id is not None:
            try:
                self.after_cancel(self._list_resize_after_id)
            except Exception:
                pass
        self._list_resize_after_id = self.after(50, self._resize_rows_to_canvas)

    def _resize_rows_to_canvas(self):
        self._list_resize_after_id = None
        if not self.rows:
            return
        new_w = self._get_row_width()
        if not new_w:
            return
        for r in self.rows.values():
            r.set_width(new_w)

    def _initial_render(self):
        self._render_action_list()
        self.after(80, self._resize_rows_to_canvas)

    def _set_category(self, cat: str):
        self.category_var.set(cat)
        for b_cat, btn, color_bar in self.cat_buttons:
            if b_cat == cat:
                btn.configure(
                    fg_color=BG_CARD_SELECTED, 
                    border_color=BORDER_CARD_SELECTED, 
                    text_color=TEXT_MAIN, 
                    font=ctk.CTkFont(size=12, weight="bold")
                )
            else:
                btn.configure(
                    fg_color=BG_CARD, 
                    border_color=BG_CARD, 
                    text_color=TEXT_MAIN, 
                    font=ctk.CTkFont(size=12, weight="normal")
                )
        self._render_action_list()

    def _filtered_keys(self) -> List[str]:
        cat = self.category_var.get()
        keys = list(ACTIONS.keys())
        if cat and cat != "Alle":
            keys = [k for k in keys if ACTIONS[k].category == cat]
        return sorted_action_keys(keys)

    def _render_action_list(self):
        for child in self.list_scroll.winfo_children():
            child.destroy()
        self.rows.clear()

        keys = self._filtered_keys()
        row_width = self._get_row_width()

        for i, k in enumerate(keys):
            r = ActionRow(self.list_scroll, k, on_click=self._on_action_clicked, width=row_width)
            r.grid(row=i, column=0, sticky="ew", padx=(4, 0), pady=4)
            self.rows[k] = r

    def _on_action_clicked(self, action_key: str):
        self.selected_action = action_key
        for k, row in self.rows.items():
            row.set_selected(k == action_key)

    # -------------------------------------------------------------------------
    # Persistent action history
    # -------------------------------------------------------------------------

    def _action_history_path(self) -> Path:
        candidates = [
            os.environ.get("PROGRAMDATA"),
            os.environ.get("LOCALAPPDATA"),
        ]

        for root in candidates:
            if not root:
                continue
            try:
                folder = Path(root) / "SD-ITLab-TechTools"
                folder.mkdir(parents=True, exist_ok=True)
                return folder / "action_history.jsonl"
            except Exception:
                pass

        return Path(resource_path("action_history.jsonl"))

    def _record_action_event(
        self,
        action: TechToolsAction,
        event: str,
        status: str = "",
        return_code: int | None = None,
        duration_seconds: float | None = None,
        note: str = "",
    ):
        return
        try:
            record = {
                "timestamp": datetime.now().isoformat(timespec="seconds"),
                "computer": socket.gethostname(),
                "session_id": self.session_id,
                "event": event,
                "status": status,
                "action_key": action.key,
                "title": action.title,
                "category": action.category,
                "return_code": return_code,
                "duration_seconds": duration_seconds,
                "note": note,
            }

            path = self._action_history_path()
            with path.open("a", encoding="utf-8") as fh:
                fh.write(json.dumps(record, ensure_ascii=False) + "\n")
        except Exception:
            pass

    def _cleanup_old_action_history(self, max_age_days: int = 14):
        try:
            path = self._action_history_path()
            if not path.exists():
                return

            cutoff = datetime.now() - timedelta(days=max_age_days)
            kept: list[str] = []
            for line in path.read_text(encoding="utf-8").splitlines():
                try:
                    record = json.loads(line)
                    timestamp = datetime.fromisoformat(record.get("timestamp", ""))
                    if timestamp >= cutoff:
                        kept.append(line)
                except Exception:
                    continue

            if kept:
                path.write_text("\n".join(kept) + "\n", encoding="utf-8")
            else:
                path.unlink(missing_ok=True)
        except Exception:
            pass

    def _has_action_history(self) -> bool:
        try:
            path = self._action_history_path()
            return path.exists() and path.stat().st_size > 0
        except Exception:
            return False

    def _delete_action_history(self):
        candidates: list[Path] = []
        program_data = os.environ.get("ProgramData")
        local_app_data = os.environ.get("LOCALAPPDATA")
        if program_data:
            candidates.append(Path(program_data) / "SD-ITLab-TechTools" / "action_history.jsonl")
        if local_app_data:
            candidates.append(Path(local_app_data) / "SD-ITLab-TechTools" / "action_history.jsonl")
        candidates.append(Path(resource_path("action_history.jsonl")))

        for path in candidates:
            try:
                path.unlink(missing_ok=True)
            except Exception:
                pass

    def _close_app(self):
        self._delete_action_history()
        self.destroy()

    # -------------------------------------------------------------------------
    # PowerShell Helper
    # -------------------------------------------------------------------------

    def _run_ps1_action(self, action: TechToolsAction):
        """
        Führt eine Aktion über die externe techtools_actions.ps1 aus.
        Die PS1 bekommt den Parameter -Action <action_key>.
        Ausgabe-Kodierung: CP850 (damit Umlaute von DISM/SFC korrekt sind).
        """
        started_at = time.monotonic()
        log_action_history = False
        if log_action_history:
            self._record_action_event(action, "started", status="started")
        script_path = Path(resource_path("techtools_actions.ps1"))

        if not script_path.exists():
            self._append_log(
                "techtools_actions.ps1 wurde nicht gefunden.\n"
                "Bitte die Datei im gleichen Verzeichnis wie SD-ITLab TechTools ablegen.\n"
            )
            if log_action_history:
                self._record_action_event(
                    action,
                    "finished",
                    status="failed",
                    return_code=1,
                    duration_seconds=round(time.monotonic() - started_at, 1),
                    note="techtools_actions.ps1 fehlt",
                )
            self.after(
                0,
                self.status_lbl.configure,
                {"text": f"Aktion fehlgeschlagen: {action.title} (PS1 fehlt)"},
            )
            self.after(1200, lambda: self.progress.set(0.0))
            return

        self._clear_log()
        self._append_log(f"Starte Aktion: {action.title}\n")
        self._append_log(f"Script: {script_path.name}\n\n")

        ps_cmd = (
            "[Console]::OutputEncoding=[System.Text.Encoding]::GetEncoding(850); "
            "$OutputEncoding=[System.Text.Encoding]::GetEncoding(850); "
            f"& '{script_path}' -Action '{action.key}'"
        )

        cmd = [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-WindowStyle", "Hidden",
            "-ExecutionPolicy", "Bypass",
            "-Command", ps_cmd,
        ]

        # PowerShell-Fenster verstecken (auch bei PyInstaller-Onefile)
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = subprocess.SW_HIDE

        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding=PS_ENCODING,
                errors="replace",
                startupinfo=startupinfo,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
        except Exception as exc:
            self._append_log(f"[Fehler beim Start von PowerShell] {exc}\n")
            if log_action_history:
                self._record_action_event(
                    action,
                    "finished",
                    status="failed",
                    return_code=1,
                    duration_seconds=round(time.monotonic() - started_at, 1),
                    note=f"PowerShell Startfehler: {exc}",
                )
            self.after(
                0,
                self.status_lbl.configure,
                {"text": f"Fehler bei Aktion: {action.title}"},
            )
            self.after(1200, lambda: self.progress.set(0.0))
            return

        self.progress.set(0.2)

        for line in proc.stdout:
            self._append_log(line)

        rc = proc.wait()
        duration_seconds = round(time.monotonic() - started_at, 1)
        if log_action_history:
            self._record_action_event(
                action,
                "finished",
                status=("ok" if rc == 0 else "failed"),
                return_code=rc,
                duration_seconds=duration_seconds,
            )

        self.after(0, self.progress.set, 1.0)
        if rc == 0:
            self.after(
                0,
                self.status_lbl.configure,
                {"text": f"Fertig: {action.title} (OK)"},
            )

            # Spezielles Verhalten für CHKDSK: Neustart anbieten
            if action.key == "chkdsk_c":
                def ask_restart():
                    from tkinter import messagebox

                    if messagebox.askyesno(
                        "Neustart für CHKDSK",
                        "Die Reparatur von Laufwerk C: wurde mit CHKDSK /F "
                        "für den nächsten Systemstart eingeplant.\n\n"
                        "Möchten Sie den Computer jetzt neu starten?",
                    ):
                        self._append_log(
                            "\nNeustart wird vorbereitet ...\n"
                            "Windows führt CHKDSK vor dem Hochfahren aus.\n"
                        )
                        try:
                            subprocess.Popen(
                                ["shutdown", "/r", "/t", "0"],
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL,
                            )
                        except Exception as exc:
                            self._append_log(
                                f"[Fehler beim Neustart] {exc}\n"
                            )
                    else:
                        self._append_log(
                            "\nNeustart wurde vom Benutzer abgebrochen. "
                            "CHKDSK wird beim nächsten manuellen Neustart "
                            "trotzdem ausgeführt.\n"
                        )

                # Dialog im GUI-Thread anzeigen
                self.after(0, ask_restart)

        else:
            self._append_log(f"\nScript Rückgabecode: {rc}\n")
            self.after(
                0,
                self.status_lbl.configure,
                {"text": f"Fertig: {action.title} (Fehlercode {rc})"},
            )

        self.after(1500, lambda: self.progress.set(0.0))

    # -------------------------------------------------------------------------
    # Aktionen ausführen – alles über techtools_actions.ps1
    # -------------------------------------------------------------------------

    def _run_selected_action(self):
        if not self.selected_action:
            self._append_log("Bitte zuerst eine Aktion auswählen.\n")
            return

        action = ACTIONS[self.selected_action]
        self._start_action(action)

    def _run_report_action(self):
        self._start_action(ACTIONS["report_export"])

    def _start_action(self, action: TechToolsAction):
        if action.key == "upgrade_pro":
            from tkinter import messagebox

            if not messagebox.askyesno(
                "Windows-Edition upgraden",
                "Diese Aktion versucht, ein Windows Home auf Windows Pro zu upgraden.\n"
                "Nur auf Systemen ausführen, auf denen du das wirklich möchtest.\n\n"
                "Fortfahren?",
            ):
                return

        if action.key == "printer_queue_clear":
            from tkinter import messagebox

            if not messagebox.askyesno(
                "Druckwarteschlange leeren",
                "Diese Aktion stoppt den Druckspooler, löscht alle offenen "
                "Druckaufträge und startet den Spooler neu.\n\n"
                "Offene Druckaufträge gehen dabei verloren.\n\n"
                "Fortfahren?",
            ):
                return

        if action.key == "time_resync":
            from tkinter import messagebox

            if not messagebox.askyesno(
                "Zeit synchronisieren",
                "Diese Aktion stößt eine Windows-Zeitsynchronisierung an.\n\n"
                "Fortfahren?",
            ):
                return

        if action.key == "printer_test_page":
            from tkinter import messagebox

            if not messagebox.askyesno(
                "Testseite drucken",
                "Es wird eine Windows-Testseite auf dem Standarddrucker gedruckt.\n\n"
                "Fortfahren?",
            ):
                return

        self.status_lbl.configure(text=f"Führe Aktion aus: {action.title}")
        self.progress.set(0.1)

        def worker():
            try:
                self._run_ps1_action(action)
            except Exception as exc:
                if action.key != "report_export":
                    self._record_action_event(
                        action,
                        "finished",
                        status="exception",
                        note=str(exc),
                    )
                self._append_log(f"\n[Fehler] {exc}\n")
                self.after(
                    0,
                    self.status_lbl.configure,
                    {"text": f"Fehler bei Aktion: {action.title}"},
                )
                self.after(1200, lambda: self.progress.set(0.0))

        threading.Thread(target=worker, daemon=True).start()

    # -------------------------------------------------------------------------
    # Log Helpers
    # -------------------------------------------------------------------------

    def _configure_log_text_style(self):
        try:
            textbox = getattr(self.log_text, "_textbox", self.log_text)
            textbox.configure(
                padx=8,
                pady=6,
                spacing1=1,
                spacing3=2,
            )

            textbox.tag_config("status_ok", foreground="#15803D")
            textbox.tag_config("status_info", foreground="#2563EB")
            textbox.tag_config("status_warn", foreground="#B45309")
            textbox.tag_config("status_critical", foreground="#B91C1C")
            textbox.tag_config("status_error", foreground="#DC2626")
            textbox.tag_config("section", foreground=TEXT_MAIN)
            textbox.tag_config("muted", foreground=TEXT_MUTED)
        except Exception:
            pass

    def _clear_log(self):
        self.log_text.configure(state="normal")
        self.log_text.delete("1.0", "end")
        self.log_text.configure(state="disabled")

    def _append_log(self, text: str):
        def tag_for_line(line: str) -> str | None:
            stripped = line.strip()
            if stripped.startswith("[OK]"):
                return "status_ok"
            if stripped.startswith("[INFO]"):
                return "status_info"
            if stripped.startswith("[WARNUNG]"):
                return "status_warn"
            if stripped.startswith("[KRITISCH]"):
                return "status_critical"
            if stripped.startswith("[FEHLER]") or stripped.startswith("[Fehler"):
                return "status_error"
            if stripped.startswith(("Datentraeger:", "Adapter:", "Drucker:", "Name:", "Minidumps", "MEMORY.DMP", "LiveKernelReports")):
                return "section"
            if stripped.startswith(("Action:", "Script:", "Grund:", "Hinweis:")):
                return "muted"
            return None

        self.log_text.configure(state="normal")
        textbox = getattr(self.log_text, "_textbox", self.log_text)
        for line in text.splitlines(True):
            tag = tag_for_line(line)
            if tag:
                textbox.insert("end", line, tag)
            else:
                textbox.insert("end", line)
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    # -------------------------------------------------------------------------
    # Systeminfo
    # -------------------------------------------------------------------------

    def _run_powershell(self, ps: str) -> str:
        prefixed = (
            "[Console]::OutputEncoding=[System.Text.Encoding]::GetEncoding(850); "
            "$OutputEncoding=[System.Text.Encoding]::GetEncoding(850); "
            + ps
        )
        try:
            # PowerShell-Fenster verstecken
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = subprocess.SW_HIDE

            out = subprocess.check_output(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-NonInteractive",
                    "-WindowStyle", "Hidden",
                    "-ExecutionPolicy", "Bypass",
                    "-Command", prefixed,
                ],
                text=True,
                encoding=PS_ENCODING,
                errors="replace",
                stderr=subprocess.STDOUT,
                startupinfo=startupinfo,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            return (out or "").strip()
        except Exception:
            return ""

    def _update_secureboot_label_color(self):
        """Färbt das SecureBoot-Label je nach Status grün/orange/grau."""
        val = self.sys_secureboot.get()
        try:
            label = getattr(self, "_secureboot_value_label", None)
            if label is None:
                return
            if "✔" in val:
                label.configure(text_color="#16A34A")  # grün
            elif "✘" in val:
                label.configure(text_color="#DC2626")  # rot
            elif "⚠" in val:
                label.configure(text_color="#EA580C")  # orange
            else:
                label.configure(text_color=TEXT_MAIN)
        except Exception:
            pass

    def _update_disk_label_color(self):
        try:
            label = getattr(self, "_disk_value_label", None)
            if label is None:
                return

            free_percent = self.sys_disk_free_percent
            if free_percent is None:
                label.configure(text_color=TEXT_MAIN)
            elif free_percent < 8:
                label.configure(text_color="#DC2626")
            elif free_percent < 15:
                label.configure(text_color="#D97706")
            else:
                label.configure(text_color="#15803D")
        except Exception:
            pass

    def _update_system_status_colors(self):
        def set_color(attr: str, color: str):
            label = getattr(self, attr, None)
            if label is not None:
                label.configure(text_color=color)

        try:
            os_val = self.sys_os.get()
            if "Windows 11" in os_val or "Windows 10" in os_val:
                set_color("_os_value_label", "#15803D")
            else:
                set_color("_os_value_label", TEXT_MAIN)

            boot_val = self.sys_boot.get()
            if "UEFI" in boot_val and "GPT" in boot_val:
                set_color("_boot_value_label", "#15803D")
            elif "MBR" in boot_val or "Legacy" in boot_val or "BIOS" in boot_val:
                set_color("_boot_value_label", "#DC2626")
            else:
                set_color("_boot_value_label", TEXT_MAIN)

            sb_val = self.sys_secureboot.get()
            if "CA 2023 fehlt" in sb_val:
                set_color("_secureboot_value_label", "#DC2626")
            elif "CA 2023 aktiv" in sb_val:
                set_color("_secureboot_value_label", "#15803D")
            elif "SecureBoot deaktiviert" in sb_val:
                set_color("_secureboot_value_label", "#D97706")
            elif "SecureBoot AN" in sb_val:
                set_color("_secureboot_value_label", "#15803D")
            elif "Kein UEFI" in sb_val:
                set_color("_secureboot_value_label", "#DC2626")
            else:
                set_color("_secureboot_value_label", TEXT_MAIN)

            ip_val = self.sys_ip.get()
            if ip_val == "-":
                set_color("_ip_value_label", "#DC2626")
            elif self.sys_has_internet is True:
                set_color("_ip_value_label", "#15803D")
            elif self.sys_has_internet is False:
                set_color("_ip_value_label", "#D97706")
            else:
                set_color("_ip_value_label", TEXT_MAIN)

            bl_val = self.sys_bitlocker.get()
            if "Aktiv" in bl_val:
                set_color("_bitlocker_value_label", "#D97706")
            elif "Aus" in bl_val or "Kein Volume" in bl_val:
                set_color("_bitlocker_value_label", TEXT_MAIN)
            else:
                set_color("_bitlocker_value_label", TEXT_MAIN)
        except Exception:
            pass

    def _get_system_info_bundle(self) -> dict[str, str]:
        ps = r"""
        $ErrorActionPreference = 'SilentlyContinue'

        # Betriebssystem
        $os = Get-CimInstance Win32_OperatingSystem
        $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
        $cap = $os.Caption
        $edition = $cap -replace '^Microsoft\s+', ''

        $arch = $os.OSArchitecture
        if ($arch) {
            $arch = $arch -replace 'bit','Bit'
            $arch = $arch -replace '-', ' '
        }

        $disp = $cv.DisplayVersion
        if (-not $disp -and $cv.ReleaseId) { $disp = $cv.ReleaseId }
        if (-not $disp) { $disp = $os.Version }

        if ($arch) {
            $osStr = "$edition - $arch ($disp)"
        } else {
            $osStr = "$edition ($disp)"
        }

        # Boot-Modus und Partitionsstil
        $boot = 'Unbekannt'
        try {
            $fw = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'PEFirmwareType' -ErrorAction SilentlyContinue).PEFirmwareType
            if ($fw) {
                $boot = switch ($fw) {
                    1 { 'Legacy / BIOS' }
                    2 { 'UEFI' }
                    Default { 'Unbekannt' }
                }
            }
        } catch {}

        if ($boot -eq 'Unbekannt') {
            try {
                if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State') {
                    $boot = 'UEFI'
                } else {
                    $boot = 'Legacy / BIOS'
                }
            } catch {}
        }

        $style = $null
        try {
            $diskObj = Get-Partition -DriveLetter C -ErrorAction SilentlyContinue | Get-Disk
            $style = $diskObj.PartitionStyle
        } catch {}

        if ($style) {
            $bootStr = "$boot ($style)"
        } else {
            $bootStr = $boot
        }

        # BitLocker-Status
        $blStr = 'BitLocker: Unbekannt'
        try {
            if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) {
                $vol = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction SilentlyContinue
                if ($vol) {
                    $prot = [int]$vol.ProtectionStatus
                    $protText = switch ($prot) {
                        0 { 'Aus' }
                        1 { 'Aktiv' }
                        2 { 'Ausgesetzt' }
                        default { "Unbekannt ($prot)" }
                    }
                    $vs = $vol.VolumeStatus
                    if ($vs) {
                        $blStr = "BitLocker: $protText – VolumeStatus: $vs"
                    } else {
                        $blStr = "BitLocker: $protText"
                    }
                } else {
                    $blStr = 'BitLocker: Kein Volume gefunden'
                }
            } else {
                $blStr = 'BitLocker-Cmdlets nicht vorhanden'
            }
        } catch {}

        # IP-Adresse (primaere IPv4): Fuer das Liveoverlay bevorzugen wir die LAN-/Internetroute
        # mit IPv4-Standardgateway. VPN-/virtuelle Adapter ohne Gateway bleiben Fallback.
        $ipv4 = '-'
        $ipv4Mode = '-'
        try {
            $configs = @()
            try {
                $configs = @(Get-NetIPConfiguration -ErrorAction Stop |
                    Where-Object {
                        $_.NetAdapter.Status -eq 'Up' -and
                        $_.IPv4Address -and
                        ($_.IPv4Address | Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' })
                    } |
                    Sort-Object @{
                        Expression = { if ($_.IPv4DefaultGateway) { 0 } else { 1 } }
                    }, @{
                        Expression = { if ($_.NetAdapter.InterfaceMetric -ne $null) { $_.NetAdapter.InterfaceMetric } else { 9999 } }
                    })
            } catch {}

            if ($configs.Count -gt 0) {
                $primaryCfg = $configs[0]
                $primaryIp = $primaryCfg.IPv4Address | Where-Object {
                    $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1'
                } | Select-Object -First 1
                $ipv4 = $primaryIp.IPAddress
                $ipv4Mode = switch ($primaryIp.PrefixOrigin) {
                    'Dhcp' { 'DHCP' }
                    'Manual' { 'Statisch' }
                    default { 'Unbekannt' }
                }
            }
            else {
                $defaultRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                    Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
                    Sort-Object RouteMetric, InterfaceMetric |
                    Select-Object -First 1
                if ($defaultRoute) {
                    $primaryIp = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $defaultRoute.InterfaceIndex -ErrorAction SilentlyContinue |
                        Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' } |
                        Select-Object -First 1
                    if ($primaryIp) {
                        $ipv4 = $primaryIp.IPAddress
                        $ipv4Mode = switch ($primaryIp.PrefixOrigin) {
                            'Dhcp' { 'DHCP' }
                            'Manual' { 'Statisch' }
                            default { 'Unbekannt' }
                        }
                    }
                }
            }
        } catch {}

        # Internetstatus (HTTPS statt Ping, da ICMP blockiert sein kann)
        $hasInternet = $false
        try {
            Invoke-WebRequest -Uri 'https://www.microsoft.com' -UseBasicParsing -Method Head -TimeoutSec 5 -ErrorAction Stop | Out-Null
            $hasInternet = $true
        } catch {}

        # CPU
        $cpuName = '-'
        try {
            $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
            if ($cpu -and $cpu.Name) { $cpuName = $cpu.Name.Trim() }
        } catch {}

        # Systemlaufwerk C:
        $diskStr = 'Nicht verfügbar'
        $diskFreePercent = $null
        try {
            $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
            if ($drive -and $drive.Size) {
                function Format-Size([double]$bytes) {
                    if ($bytes -ge 1TB) {
                        $tb = [math]::Round($bytes / 1TB, 0)
                        "{0} TB" -f $tb
                    }
                    elseif ($bytes -ge 1GB) {
                        $gb = [math]::Round($bytes / 1GB, 0)
                        "{0} GB" -f $gb
                    }
                    else {
                        $mb = [math]::Round($bytes / 1MB, 0)
                        "{0} MB" -f $mb
                    }
                }

                $size = [double]$drive.Size
                $free = [double]$drive.FreeSpace
                $used = $size - $free
                $diskFreePercent = [math]::Round(($free * 100.0 / $size), 1)
                $usedStr = Format-Size $used
                $sizeStr = Format-Size $size
                $diskStr = "Disk C:\ $usedStr genutzt von $sizeStr"
            }
        } catch {}

        # Secure Boot + UEFI CA 2023 Zertifikat prüfen
        # Schritt 1: UEFI und SB-Status vollständig über Registry ermitteln
        # (kein Admin nötig, kein Confirm-SecureBootUEFI nötig)
        $sbCaStr = 'Kein UEFI (Legacy BIOS)'

        $firmwareType = $env:firmware_type
        $sbParentKey  = Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot' `
                            -ErrorAction SilentlyContinue

        $isUEFI = ($firmwareType -eq 'UEFI') -or ($sbParentKey -ne $null)

        if ($isUEFI) {
            $sbStateKey = Get-ItemProperty `
                -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' `
                -ErrorAction SilentlyContinue

            $sbEnabled = ($sbStateKey -ne $null -and $sbStateKey.UEFISecureBootEnabled -eq 1)

            if ($sbEnabled) {
                # Secure Boot AN → CA 2023 prüfen (benötigt Admin; eigener try/catch)
                $sbCaStr = 'CA 2023 prüfen...'
                try {
                    $dbVar = Get-SecureBootUEFI db -ErrorAction Stop
                    $ca2023Found = $false
                    $debugInfo = " (0 B)"

                    if ($dbVar -and $dbVar.bytes) {
                        $debugInfo = " (" + $dbVar.bytes.Length + " B)"
                        $dbStr = [System.Text.Encoding]::ASCII.GetString($dbVar.bytes)
                        if ($dbStr -match 'Windows UEFI CA 2023' -or $dbStr -match 'Microsoft UEFI CA 2023') {
                            $ca2023Found = $true
                        }
                    }
                    $sbCaStr = if ($ca2023Found) { 'CA 2023 aktiv' } else { "CA 2023 fehlt" + $debugInfo }
                } catch {
                    $sbCaStr = 'SecureBoot AN (kein Admin)'
                }
            } else {
                # UEFI vorhanden, Secure Boot im BIOS/UEFI-Setup deaktiviert
                $sbCaStr = 'SecureBoot deaktiviert'
            }
        }
        # $isUEFI = $false → bleibt 'Kein UEFI (Legacy BIOS)'

        $obj = [PSCustomObject]@{
            OS          = $osStr
            Boot        = $bootStr
            BitLocker   = $blStr
            IPv4        = $ipv4
            IPv4Mode    = $ipv4Mode
            HasInternet = $hasInternet
            CPU         = $cpuName
            Disk        = $diskStr
            DiskFreePercent = $diskFreePercent
            SecureBootCA = $sbCaStr
        }

        $obj | ConvertTo-Json -Compress
        """
        raw = self._run_powershell(ps)
        if not raw:
            return {}
        try:
            import json
            return json.loads(raw)
        except Exception:
            return {}

    def _load_system_info_async(self):
        def worker():
            # Computername lokal holen, das ist instant
            try:
                name = socket.gethostname()
            except Exception:
                name = "-"

            info = self._get_system_info_bundle()

            # Fallbacks
            os_str = info.get("OS", "-")
            boot = info.get("Boot", "-")
            bitlocker = info.get("BitLocker", "-")
            ip = info.get("IPv4", "-")
            ip_mode = info.get("IPv4Mode", "-")
            has_internet = info.get("HasInternet")
            cpu = info.get("CPU", "-")
            disk = info.get("Disk", "-")
            disk_free_percent = info.get("DiskFreePercent")
            sb_ca_raw = info.get("SecureBootCA", "-")

            # Formatierung mit Icon
            if sb_ca_raw == "CA 2023 aktiv":
                sb_ca = "✔ CA 2023 aktiv"
            elif sb_ca_raw == "CA 2023 fehlt":
                sb_ca = "✘ CA 2023 fehlt"
            elif sb_ca_raw == "SecureBoot deaktiviert":
                sb_ca = "⚠ SecureBoot deaktiviert"
            else:
                sb_ca = sb_ca_raw

            if ip != "-" and ip_mode != "-":
                ip_val = f"✔ {ip} ({ip_mode})"
            elif ip != "-":
                ip_val = f"✔ {ip}"
            else:
                ip_val = ip
            os_val = f"✔ {os_str}" if os_str != "-" else os_str

            self.sys_computer.set(name)
            self.sys_os.set(os_val)
            self.sys_ip.set(ip_val)
            self.sys_has_internet = bool(has_internet) if has_internet is not None else None
            self.sys_cpu.set(cpu)
            self.sys_boot.set(boot)
            self.sys_bitlocker.set(bitlocker)
            self.sys_disk.set(disk)
            try:
                self.sys_disk_free_percent = float(disk_free_percent) if disk_free_percent is not None else None
            except (TypeError, ValueError):
                self.sys_disk_free_percent = None
            self.sys_secureboot.set(sb_ca)
            self.after(0, self._update_disk_label_color)
            self.after(0, self._update_system_status_colors)

        threading.Thread(target=worker, daemon=True).start()

# =============================================================================
# Main
# =============================================================================

def main():
    app = TechToolsApp()
    app.mainloop()


if __name__ == "__main__":
    main()
