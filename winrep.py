from __future__ import annotations

import locale
import os
import socket
import subprocess
import sys
import threading
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List
import webbrowser
from tkinter import messagebox

import tkinter as tk
import customtkinter as ctk
from PIL import Image

# =============================================================================
# Basis-Konfiguration
# =============================================================================

APP_TITLE = "SD TechTools – Windows Repair Toolbox"
WINDOW_SIZE = "1120x620"

BG_WINDOW = "#F3F4F6"
BG_CARD = "#FFFFFF"
BG_CARD_SELECTED = "#E7F1FF"
BORDER_CARD = "#E5E7EB"
BORDER_CARD_SELECTED = "#3B82F6"
BG_RIGHT_PANEL = "#EFF4FF"
TEXT_MUTED = "#6B7280"
ACCENT = "#3B82F6"

CMD_ENCODING = "cp850"   # kannst du für andere Dinge behalten
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
class WinRepAction:
    key: str
    title: str
    description: str
    category: str
    ps_command: str | None = None  # nur informativ, Logik liegt in PS1


ACTIONS: Dict[str, WinRepAction] = {
    "dism_scanhealth": WinRepAction(
        "dism_scanhealth",
        "Windows Komponentenspeicher auf Fehler prüfen [ScanHealth]",
        "Prüft den Komponentenstore auf Beschädigungen.",
        "Systemdateien / DISM",
        ps_command="DISM /Online /Cleanup-Image /ScanHealth",
    ),
    "dism_checkhealth": WinRepAction(
        "dism_checkhealth",
        "Prüfen, ob Windows als beschädigt markiert ist [CheckHealth]",
        "Zeigt an, ob Windows als beschädigt markiert wurde.",
        "Systemdateien / DISM",
        ps_command="DISM /Online /Cleanup-Image /CheckHealth",
    ),
    "dism_restorehealth": WinRepAction(
        "dism_restorehealth",
        "Automatische Reparaturvorgänge durchführen [RestoreHealth]",
        "Versucht, beschädigte Dateien zu reparieren.",
        "Systemdateien / DISM",
        ps_command="DISM /Online /Cleanup-Image /RestoreHealth",
    ),
    "dism_componentcleanup": WinRepAction(
        "dism_componentcleanup",
        "Abgelöste Startkomponenten bereinigen [ComponentCleanup]",
        "Bereinigt den Komponentenstore und entfernt veraltete Komponenten.",
        "Systemdateien / DISM",
        ps_command="DISM /Online /Cleanup-Image /StartComponentCleanup",
    ),
    "sfc_scannow": WinRepAction(
        "sfc_scannow",
        "Systemdateien prüfen & reparieren [sfc /scannow]",
        "Prüft Systemdateien und stellt Originale wieder her.",
        "Systemdateien / DISM",
        ps_command="sfc /scannow",
    ),
    "net_reset": WinRepAction(
        "net_reset",
        "Netzwerkeinstellungen zurücksetzen [FlushDNS usw.]",
        "Setzt DNS-Cache, Winsock und wichtige Netzwerk-Stacks zurück.",
        "Netzwerk",
    ),
    "wu_reset": WinRepAction(
        "wu_reset",
        "Windows Updates zurücksetzen / Cache bereinigen",
        "Bereinigt den Update-Cache und setzt Windows Update Komponenten zurück.",
        "Cleanup / Updates",
    ),
    "temp_cleanup": WinRepAction(
        "temp_cleanup",
        "Temporäre Dateien bereinigen",
        "Löscht TEMP-Ordner & unnötige Dateien.",
        "Cleanup / Updates",
    ),
    "upgrade_pro": WinRepAction(
        "upgrade_pro",
        "Upgrade von Windows Home auf Windows Pro",
        "Setzt den Product Key für das Upgrade auf Windows Pro.",
        "Leistung / Tuning",
    ),
    "power_high": WinRepAction(
        "power_high",
        "Windows Höchstleistungsmodus aktivieren",
        "Aktiviert den Windows-Höchstleistungsmodus, sofern verfügbar.",
        "Leistung / Tuning",
    ),
    "sysinfo": WinRepAction(
        "sysinfo",
        "Systeminformationen anzeigen",
        "Zeigt ausführliche Systeminformationen an.",
        "Info & Tools",
        ps_command="systeminfo",
    ),
    "chkdsk_c": WinRepAction(
        "chkdsk_c",
        "Dateisystem von C: prüfen [chkdsk]",
        "Führt eine Dateisystemprüfung von Laufwerk C: (online /scan) durch.",
        "Systemdateien / DISM",
    ),
    "bitlocker_disable": WinRepAction(
        "bitlocker_disable",
        "BitLocker auf Laufwerk C: deaktivieren",
        "Deaktiviert BitLocker auf C:. Achtung: Entschlüsselung kann lange dauern!",
        "Info & Tools",
    ),
    "battery_info": WinRepAction(
        "battery_info",
        "Akkuinformationen anzeigen",
        "Zeigt Informationen zum Akku (Ladestand, Status usw.), falls vorhanden.",
        "Info & Tools",
    ),
    "sysinfo": WinRepAction(
        "sysinfo",
        "Systeminformationen anzeigen",
        "Zeigt ausführliche Systeminformationen an.",
        "Info & Tools",
        ps_command="systeminfo",
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
    def __init__(self, master, action_key: str, on_click, width: int = 540, height: int = 80):
        super().__init__(
            master,
            fg_color=BG_CARD,
            corner_radius=14,
            width=width,
            height=height,
        )
        self.grid_propagate(False)

        self.action_key = action_key
        self.on_click = on_click
        self.selected = False

        self.configure(border_width=1, border_color=BORDER_CARD)
        self.grid_columnconfigure(0, weight=1)

        action = ACTIONS[action_key]

        self.title_lbl = ctk.CTkLabel(
            self,
            text=action.title,
            font=ctk.CTkFont(size=12, weight="bold"),
            anchor="w",
        )
        self.title_lbl.grid(row=0, column=0, sticky="w", padx=12, pady=(8, 0))

        self.desc_lbl = ctk.CTkLabel(
            self,
            text=action.description,
            font=ctk.CTkFont(size=10),
            text_color=TEXT_MUTED,
            anchor="w",
            justify="left",
            wraplength=width - 40,
        )
        self.desc_lbl.grid(row=1, column=0, sticky="w", padx=12, pady=(0, 8))

        for w in (self, self.title_lbl, self.desc_lbl):
            w.bind("<Button-1>", self._on_click_internal)

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
        self.desc_lbl.configure(wraplength=max(180, width - 40))


# =============================================================================
# Main-App
# =============================================================================

class WinRepApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        ctk.set_appearance_mode("light")
        ctk.set_default_color_theme("blue")

        self.title(APP_TITLE)
        self.geometry(WINDOW_SIZE)
        self.minsize(1120, 620)
        self.resizable(False, False)  # bewusst fix
        self.configure(fg_color=BG_WINDOW)

        self._set_window_icon()

        self.category_var = tk.StringVar(value="Alle")
        self.selected_action: str | None = None

        self.rows: Dict[str, ActionRow] = {}
        self._list_resize_after_id: str | None = None

        self.sys_computer = tk.StringVar(value="-")
        self.sys_os = tk.StringVar(value="-")
        self.sys_ip = tk.StringVar(value="-")
        self.sys_cpu = tk.StringVar(value="-")
        self.sys_boot = tk.StringVar(value="-")
        self.sys_bitlocker = tk.StringVar(value="-")
        self.sys_disk = tk.StringVar(value="-")

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
        candidates = ["winrep.ico", "WinRep.ico", "icon.ico"]
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
        left = ctk.CTkFrame(self, fg_color=BG_WINDOW, width=LEFT_PANEL_WIDTH)
        left.grid(row=0, column=0, rowspan=2, sticky="nsw", padx=(16, 8), pady=8)
        left.grid_propagate(False)
        left.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(
            left,
            text="Kategorien",
            font=ctk.CTkFont(size=13, weight="bold"),
        ).grid(row=0, column=0, sticky="w", padx=4, pady=(4, 6))

        cats = ["Alle"] + sorted({a.category for a in ACTIONS.values()})
        self.cat_buttons: List[ctk.CTkButton] = []

        for i, cat in enumerate(cats, start=1):
            btn = ctk.CTkButton(
                left,
                text=cat,
                width=170,
                height=34,
                fg_color=BG_CARD_SELECTED if cat == "Alle" else BG_CARD,
                border_width=1,
                border_color=(BORDER_CARD_SELECTED if cat == "Alle" else BORDER_CARD),
                text_color="#111827",
                hover_color="#E5E7EB",
                command=lambda c=cat: self._set_category(c),
            )
            btn.grid(row=i, column=0, sticky="ew", padx=4, pady=4)
            self.cat_buttons.append(btn)

        spacer_row = len(cats) + 1
        left.grid_rowconfigure(spacer_row, weight=1)

        logo_box = ctk.CTkFrame(
            left,
            fg_color=BG_CARD,
            corner_radius=18,
            border_width=1,
            border_color=BORDER_CARD,
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
        main.grid(row=0, column=1, sticky="nsew", padx=(0, 16), pady=(8, 0))
        main.grid_rowconfigure(0, weight=1)
        main.grid_columnconfigure(0, weight=1)  # Mitte
        main.grid_columnconfigure(1, weight=0)  # Rechts

        # Mitte: Aktionen
        mid = ctk.CTkFrame(main, fg_color=BG_WINDOW, width=540)
        mid.grid(row=0, column=0, sticky="nsw", padx=(8, 4), pady=(0, 8))
        mid.grid_propagate(False)
        mid.grid_columnconfigure(0, weight=1)
        mid.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(
            mid,
            text="Aktionen auswählen",
            font=ctk.CTkFont(size=17, weight="bold"),
        ).grid(row=0, column=0, sticky="w", padx=4, pady=(4, 8))

        list_wrapper = ctk.CTkFrame(mid, fg_color=BG_WINDOW)
        list_wrapper.grid(row=1, column=0, sticky="nsew", padx=4, pady=(0, 4))
        list_wrapper.grid_columnconfigure(0, weight=1)
        list_wrapper.grid_rowconfigure(0, weight=1)

        self.list_scroll = ctk.CTkScrollableFrame(
            list_wrapper,
            fg_color=BG_WINDOW,
            corner_radius=0,
        )
        self.list_scroll.grid(row=0, column=0, sticky="nsew")
        self.list_scroll.grid_columnconfigure(0, weight=1)

        canvas = getattr(self.list_scroll, "_parent_canvas", None)
        if canvas is not None:
            canvas.bind("<Configure>", self._on_list_canvas_configure)

        # Rechts: Systeminfos + Log
        right = ctk.CTkFrame(main, fg_color=BG_WINDOW, width=400)
        right.grid(row=0, column=1, sticky="nse", padx=(1, 0), pady=(0, 8))
        right.grid_propagate(False)
        right.grid_columnconfigure(0, weight=1)
        right.grid_rowconfigure(3, weight=1)

        header = ctk.CTkFrame(right, fg_color="transparent")
        header.grid(row=0, column=0, sticky="ew", padx=6, pady=(4, 6))
        header.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(
            header,
            text="SD - TechTools",
            font=ctk.CTkFont(size=18, weight="bold"),
        ).grid(row=0, column=0, sticky="w")

        sys_box = ctk.CTkFrame(
            right,
            fg_color=BG_RIGHT_PANEL,
            corner_radius=18,
            border_width=1,
            border_color=BORDER_CARD,
        )
        sys_box.grid(row=1, column=0, sticky="ew", padx=4, pady=(4, 6))
        sys_box.grid_columnconfigure(0, weight=0)
        sys_box.grid_columnconfigure(1, weight=1)

        def add_row(r: int, label: str, var: ctk.StringVar):
            ctk.CTkLabel(
                sys_box,
                text=label,
                text_color=TEXT_MUTED,
                anchor="w",
                font=ctk.CTkFont(size=10),
            ).grid(row=r, column=0, sticky="w", padx=12, pady=(1, 1))

            ctk.CTkLabel(
                sys_box,
                textvariable=var,
                anchor="w",
                justify="left",
                wraplength=230,
                font=ctk.CTkFont(size=11),
            ).grid(row=r, column=1, sticky="w", padx=12, pady=(1, 1))

        add_row(0, "Betriebssystem:", self.sys_os)
        add_row(1, "Boot:", self.sys_boot)
        add_row(2, "BitLocker:", self.sys_bitlocker)
        add_row(3, "Netzwerk-IP:", self.sys_ip)
        add_row(4, "Systemlaufwerk C:\\", self.sys_disk)
        add_row(5, "Prozessor:", self.sys_cpu)

        ctk.CTkLabel(
            right,
            text="Aktuelles Log:",
            font=ctk.CTkFont(size=11, weight="bold"),
        ).grid(row=2, column=0, sticky="w", padx=6, pady=(6, 2))

        self.log_text = ctk.CTkTextbox(
            right,
            height=260,
            fg_color=BG_CARD,
            text_color="#111827",
            wrap="word",
            font=ctk.CTkFont(size=10),
        )
        self.log_text.grid(row=3, column=0, sticky="nsew", padx=6, pady=(0, 8))
        self.log_text.insert("end", "Hier erscheinen Ausgaben von WinRep-Aktionen …")
        self.log_text.configure(state="disabled")

        # ------------------------------ Footer -------------------------------
        footer = ctk.CTkFrame(self, corner_radius=0, fg_color=BG_WINDOW)
        footer.grid(row=1, column=1, sticky="ew", padx=(0, 16), pady=(4, 8))
        footer.grid_columnconfigure(0, weight=1)
        footer.grid_columnconfigure(1, weight=0)
        footer.grid_columnconfigure(2, weight=0)
        footer.grid_columnconfigure(3, weight=0)

        self.progress = ctk.CTkProgressBar(
            footer,
            progress_color=ACCENT,
            fg_color="#E5E7EB",
            height=10,
            corner_radius=999,
        )
        self.progress.grid(row=0, column=0, columnspan=4, sticky="ew", padx=(8, 0), pady=(4, 8))
        self.progress.set(0.0)

        self.status_lbl = ctk.CTkLabel(
            footer,
            text="Bereit.",
            text_color=TEXT_MUTED,
            font=ctk.CTkFont(size=10),
        )
        self.status_lbl.grid(row=1, column=0, sticky="w", padx=8, pady=(0, 8))

        self.footer_brand = ctk.CTkLabel(
            footer,
            text="© 2026 SD-ITLab – MIT licensed",
            font=ctk.CTkFont(size=10),
            text_color=TEXT_MUTED,
            cursor="hand2",
        )
        self.footer_brand.grid(row=1, column=1, sticky="e", padx=(0, 10), pady=(0, 8))
        self.footer_brand.bind("<Button-1>", lambda e: self._open_url(BRAND_URL))
        self.footer_brand.bind("<Enter>", lambda e: self.footer_brand.configure(text_color=ACCENT))
        self.footer_brand.bind("<Leave>", lambda e: self.footer_brand.configure(text_color=TEXT_MUTED))


        self.btn_readme = ctk.CTkButton(
            footer,
            text="Readme",
            width=100,
            command=lambda: self._open_url(README_URL),
        )
        self.btn_readme.grid(row=1, column=2, padx=6, pady=(0, 8))

        self.btn_run = ctk.CTkButton(
            footer,
            text="Aktion ausführen",
            width=130,
            command=self._run_selected_action,
        )
        self.btn_run.grid(row=1, column=3, padx=6, pady=(0, 8))

        self.btn_close = ctk.CTkButton(
            footer,
            text="Schließen",
            width=110,
            command=self.destroy,
        )
        self.btn_close.grid(row=1, column=4, padx=(6, 0), pady=(0, 8))



    # -------------------------------------------------------------------------
    # Logo
    # -------------------------------------------------------------------------

    def _load_bottom_logo(self):
        try:
            logo_path = resource_path("logo1.png")
            img = Image.open(logo_path).convert("RGBA")
        except Exception:
            self.logo_label.configure(
                text="SD-ITLAB",
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
        for b in self.cat_buttons:
            if b.cget("text") == cat:
                b.configure(fg_color=BG_CARD_SELECTED, border_color=BORDER_CARD_SELECTED)
            else:
                b.configure(fg_color=BG_CARD, border_color=BORDER_CARD)
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
            r.grid(row=i, column=0, sticky="ew", padx=4, pady=4)
            self.rows[k] = r

    def _on_action_clicked(self, action_key: str):
        self.selected_action = action_key
        for k, row in self.rows.items():
            row.set_selected(k == action_key)

    # -------------------------------------------------------------------------
    # PowerShell Helper
    # -------------------------------------------------------------------------

    def _run_ps1_action(self, action: WinRepAction):
        """
        Führt eine Aktion über die externe winrep_actions.ps1 aus.
        Die PS1 bekommt den Parameter -Action <action_key>.
        Ausgabe-Kodierung: CP850 (damit Umlaute von DISM/SFC korrekt sind).
        """
        script_path = Path(resource_path("winrep_actions.ps1"))

        if not script_path.exists():
            self._append_log(
                "winrep_actions.ps1 wurde nicht gefunden.\n"
                "Bitte die Datei im gleichen Verzeichnis wie WinRep ablegen.\n"
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
                encoding=PS_ENCODING,  # cp850
                errors="replace",
                startupinfo=startupinfo,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
        except Exception as exc:
            self._append_log(f"[Fehler beim Start von PowerShell] {exc}\n")
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
    # Aktionen ausführen – alles über winrep_actions.ps1
    # -------------------------------------------------------------------------

    def _run_selected_action(self):
        if not self.selected_action:
            self._append_log("Bitte zuerst eine Aktion auswählen.\n")
            return

        action = ACTIONS[self.selected_action]

        if action.key == "upgrade_pro":
            from tkinter import messagebox

            if not messagebox.askyesno(
                "Windows-Edition upgraden",
                "Diese Aktion versucht, ein Windows Home auf Windows Pro zu upgraden.\n"
                "Nur auf Systemen ausführen, auf denen du das wirklich möchtest.\n\n"
                "Fortfahren?",
            ):
                return

        self.status_lbl.configure(text=f"Führe Aktion aus: {action.title}")
        self.progress.set(0.1)

        def worker():
            try:
                self._run_ps1_action(action)
            except Exception as exc:
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

    def _clear_log(self):
        self.log_text.configure(state="normal")
        self.log_text.delete("1.0", "end")
        self.log_text.configure(state="disabled")

    def _append_log(self, text: str):
        self.log_text.configure(state="normal")
        self.log_text.insert("end", text)
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
                encoding=PS_ENCODING,  # cp850
                errors="replace",
                stderr=subprocess.STDOUT,
                startupinfo=startupinfo,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            return (out or "").strip()
        except Exception:
            return ""

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

        # IP-Adresse (primäre IPv4)
        $ipv4 = '-'
        try {
            $adapters = Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp,Manual -ErrorAction SilentlyContinue |
                        Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' } |
                        Sort-Object -Property InterfaceMetric, AddressFamily
            if ($adapters) {
                $ipv4 = $adapters[0].IPAddress
            }
        } catch {}

        # CPU
        $cpuName = '-'
        try {
            $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
            if ($cpu -and $cpu.Name) { $cpuName = $cpu.Name.Trim() }
        } catch {}

        # Systemlaufwerk C:
        $diskStr = 'Nicht verfügbar'
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
                $usedStr = Format-Size $used
                $sizeStr = Format-Size $size
                $diskStr = "Disk C:\ $usedStr genutzt von $sizeStr"
            }
        } catch {}

        $obj = [PSCustomObject]@{
            OS        = $osStr
            Boot      = $bootStr
            BitLocker = $blStr
            IPv4      = $ipv4
            CPU       = $cpuName
            Disk      = $diskStr
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
            cpu = info.get("CPU", "-")
            disk = info.get("Disk", "-")

            self.sys_computer.set(name)
            self.sys_os.set(os_str)
            self.sys_ip.set(ip)
            self.sys_cpu.set(cpu)
            self.sys_boot.set(boot)
            self.sys_bitlocker.set(bitlocker)
            self.sys_disk.set(disk)

        threading.Thread(target=worker, daemon=True).start()

# =============================================================================
# Main
# =============================================================================

def main():
    app = WinRepApp()
    app.mainloop()


if __name__ == "__main__":
    main()
