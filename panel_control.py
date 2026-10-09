#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Panel de Control y Switch Maestro - Ecosistema Gemelo Vending GROG
Permite encender/apagar el sistema completo, controlar contenedores individualmente y monitorear logs en tiempo real.
"""

import os
import sys
import time
import subprocess
import threading
import webbrowser
from pathlib import Path

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango

BASE_DIR = Path("/home/ar/Escritorio/Maquina-expendedora")
BACKEND_DIR = BASE_DIR / "backend"
PROXY_DIR = BASE_DIR / "gateway-proxy"
LOGS_DIR = BASE_DIR / "logs"
NGROK_BIN = Path("/home/ar/.local/bin/ngrok")
PUBLIC_URL = "https://passivism-sighing-condense.ngrok-free.dev"

SERVICES_INFO = [
    {"name": "backend-payment-gateway-frontend-1", "label": "SimuPay Web UI", "port": "5174", "type": "docker", "desc": "Frontend Web de billetera y login"},
    {"name": "backend-auth-service-1", "label": "Auth Service", "port": "8030", "type": "docker", "desc": "Autenticación y usuarios"},
    {"name": "backend-simupay-service-1", "label": "SimuPay Service", "port": "8020", "type": "docker", "desc": "Billetera y transferencias"},
    {"name": "backend-orchestrator-service-1", "label": "Orchestrator Service", "port": "8010", "type": "docker", "desc": "Orquestador de compras"},
    {"name": "backend-vending-service-1", "label": "Vending Service", "port": "8040", "type": "docker", "desc": "Inventario y máquinas"},
    {"name": "backend-payment-gateway-1", "label": "Payment Gateway API", "port": "8001", "type": "docker", "desc": "Pasarela de cobro"},
    {"name": "backend-iot-service-1", "label": "IoT Service", "port": "8050", "type": "docker", "desc": "Telemetría y sensores"},
    {"name": "backend-notification-service-1", "label": "Notification Service", "port": "8070", "type": "docker", "desc": "WebSockets y avisos"},
    {"name": "backend-audit-service-1", "label": "Audit Service", "port": "8080", "type": "docker", "desc": "Registro de auditoría"},
    {"name": "grog-postgres", "label": "PostgreSQL DB", "port": "5433", "type": "docker", "desc": "Base de datos principal"},
    {"name": "grog-mosquitto", "label": "MQTT Mosquitto", "port": "1883", "type": "docker", "desc": "Broker IoT"},
    {"name": "gateway.py", "label": "API Gateway Proxy", "port": "8090", "type": "process", "desc": "Gateway unificador multihilo"},
    {"name": "ngrok", "label": "Túnel Público Ngrok", "port": "443", "type": "process", "desc": "Dominio permanente seguro"},
]

CSS = b"""
window {
    background-color: #1e1e2e;
    color: #cdd6f4;
}

headerbar, headerbar.default-decoration {
    background: #181825;
    background-color: #181825;
    border-bottom: 1px solid #313244;
    color: #ffffff;
}

headerbar .title {
    color: #cdd6f4;
    font-weight: bold;
    font-size: 15px;
}

headerbar .subtitle {
    color: #89b4fa;
    font-size: 12px;
}

headerbar label {
    color: #cdd6f4;
}

.status-card {
    background-color: #181825;
    border: 1px solid #313244;
    border-radius: 12px;
    padding: 14px 18px;
    margin: 10px 14px;
}

.badge-online {
    background-color: #a6e3a1;
    color: #11111b;
    font-weight: bold;
    border-radius: 14px;
    padding: 6px 14px;
    font-size: 13px;
}

.badge-offline {
    background-color: #f38ba8;
    color: #11111b;
    font-weight: bold;
    border-radius: 14px;
    padding: 6px 14px;
    font-size: 13px;
}

.badge-busy {
    background-color: #f9e2af;
    color: #11111b;
    font-weight: bold;
    border-radius: 14px;
    padding: 6px 14px;
    font-size: 13px;
}

.url-box {
    background-color: #11111b;
    border: 1px solid #45475a;
    border-radius: 8px;
    padding: 6px 12px;
    font-family: monospace;
    font-size: 13px;
    color: #89b4fa;
}

button.btn-start {
    background: #a6e3a1;
    color: #11111b;
    font-weight: bold;
    border-radius: 8px;
    padding: 7px 16px;
    border: none;
    font-size: 13px;
}
button.btn-start:hover {
    background: #94e2d5;
}

button.btn-stop {
    background: #f38ba8;
    color: #11111b;
    font-weight: bold;
    border-radius: 8px;
    padding: 7px 16px;
    border: none;
    font-size: 13px;
}
button.btn-stop:hover {
    background: #eba0ac;
}

button.primary-btn {
    background: #89b4fa;
    color: #11111b;
    font-weight: bold;
    border-radius: 8px;
    padding: 7px 14px;
    border: none;
}
button.primary-btn:hover {
    background: #b4befe;
}

button.action-btn {
    background: #313244;
    color: #cdd6f4;
    border-radius: 8px;
    padding: 6px 12px;
    border: 1px solid #45475a;
}
button.action-btn:hover {
    background: #45475a;
}

textview.log-terminal,
textview.log-terminal text,
.log-terminal,
.log-terminal text {
    background-color: #0d0e15;
    color: #cdd6f4;
    font-family: 'JetBrains Mono', 'Fira Code', 'DejaVu Sans Mono', monospace;
    font-size: 12px;
    padding: 8px;
}

textview.log-terminal text:selected,
textview.log-terminal selection {
    background-color: #45475a;
    color: #ffffff;
}

scrolledwindow.log-scrolled,
scrolledwindow.log-scrolled viewport {
    background-color: #0d0e15;
    border: 1px solid #313244;
    border-radius: 8px;
}

treeview {
    background-color: #181825;
    color: #cdd6f4;
}
treeview:selected {
    background-color: #45475a;
    color: #ffffff;
}

notebook header {
    background-color: #181825;
    border-bottom: 1px solid #313244;
}
notebook tab {
    padding: 8px 16px;
    color: #a6adc8;
    font-weight: bold;
}
notebook tab:checked {
    color: #89b4fa;
    border-bottom: 3px solid #89b4fa;
}
"""

class VendingControlPanel(Gtk.Window):
    def __init__(self):
        super().__init__(title="Control Maestro - Gemelo Vending")
        self.set_default_size(1020, 740)
        self.set_position(Gtk.WindowPosition.CENTER)

        LOGS_DIR.mkdir(parents=True, exist_ok=True)

        # Estados internos
        self.is_busy = False
        self.system_online = False
        self.log_process = None
        self.log_thread = None
        self.log_paused = False
        self.auto_scroll = True
        self.current_log_target = "all"
        self.filter_keyword = ""
        self._updating_switch = False

        # Configurar Estilos CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self._build_ui()
        self._start_status_checker()

        # Iniciar streaming inicial de logs
        self._switch_log_source("all")

    def _build_ui(self):
        # HeaderBar moderna
        header = Gtk.HeaderBar()
        header.set_show_close_button(True)
        header.props.title = "Gemelo Vending - GROG"
        header.props.subtitle = "Switch Maestro y Monitoreo en Vivo"
        self.set_titlebar(header)

        # Spinner de actividad
        self.spinner = Gtk.Spinner()
        header.pack_start(self.spinner)

        # Botón de recarga en header
        refresh_btn = Gtk.Button.new_from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON)
        refresh_btn.set_tooltip_text("Actualizar estado")
        refresh_btn.connect("clicked", lambda _: self._update_system_status())
        header.pack_start(refresh_btn)

        # Switch en el HeaderBar
        switch_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.switch_label = Gtk.Label(label="ESTADO:")
        self.power_switch = Gtk.Switch()
        self.power_switch.connect("notify::active", self._on_switch_activated)

        switch_box.pack_start(self.switch_label, False, False, 0)
        switch_box.pack_start(self.power_switch, False, False, 0)
        header.pack_end(switch_box)

        # Contenedor principal
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(main_box)

        # Tarjeta Superior de Estado
        main_box.pack_start(self._build_status_card(), False, False, 0)

        # Pestañas
        self.notebook = Gtk.Notebook()
        main_box.pack_start(self.notebook, True, True, 0)

        # Pestaña 1: Contenedores y Servicios (Ahora primera para visibilidad directa)
        self.notebook.append_page(self._build_services_tab(), Gtk.Label(label="🐳 Contenedores y Servicios"))

        # Pestaña 2: Logs en Vivo
        self.notebook.append_page(self._build_logs_tab(), Gtk.Label(label="📜 Logs en Tiempo Real"))

    def _build_status_card(self):
        card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        card.get_style_context().add_class("status-card")

        # Indicador de Encendido
        status_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        status_title = Gtk.Label(label="ESTADO DEL SISTEMA", xalign=0)
        status_title.get_style_context().add_class("dim-label")
        self.status_badge = Gtk.Label(label="VERIFICANDO...")
        self.status_badge.get_style_context().add_class("badge-busy")
        status_box.pack_start(status_title, False, False, 0)
        status_box.pack_start(self.status_badge, False, False, 0)
        card.pack_start(status_box, False, False, 0)

        # Separador vertical
        card.pack_start(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL), False, False, 4)

        # Botones Principales de Encendido / Apagado
        power_buttons_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        
        self.btn_start = Gtk.Button(label="🟢 Encender Todo")
        self.btn_start.get_style_context().add_class("btn-start")
        self.btn_start.connect("clicked", lambda _: self._trigger_start())
        power_buttons_box.pack_start(self.btn_start, False, False, 0)

        self.btn_stop = Gtk.Button(label="🔴 Apagar Todo")
        self.btn_stop.get_style_context().add_class("btn-stop")
        self.btn_stop.connect("clicked", lambda _: self._trigger_stop())
        power_buttons_box.pack_start(self.btn_stop, False, False, 0)

        self.btn_restart = Gtk.Button(label="🔄 Reiniciar")
        self.btn_restart.get_style_context().add_class("action-btn")
        self.btn_restart.connect("clicked", lambda _: self._on_restart_all_clicked())
        power_buttons_box.pack_start(self.btn_restart, False, False, 0)

        card.pack_start(power_buttons_box, False, False, 0)

        # Separador vertical
        card.pack_start(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL), False, False, 4)

        # URL Pública Permanente
        url_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        url_title = Gtk.Label(label="DIRECCIÓN PÚBLICA FIJA", xalign=0)
        url_title.get_style_context().add_class("dim-label")
        self.url_display = Gtk.Label(label=PUBLIC_URL, xalign=0)
        self.url_display.get_style_context().add_class("url-box")
        self.url_display.set_selectable(True)
        url_box.pack_start(url_title, False, False, 0)
        url_box.pack_start(self.url_display, False, False, 0)
        card.pack_start(url_box, True, True, 0)

        # Botones de Acceso Rápido Web y Copiar
        links_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        
        copy_btn = Gtk.Button(label="📋 Copiar")
        copy_btn.get_style_context().add_class("action-btn")
        copy_btn.connect("clicked", self._on_copy_url_clicked)
        links_box.pack_start(copy_btn, False, False, 0)

        web_btn = Gtk.Button(label="🌐 Abrir SimuPay Web")
        web_btn.get_style_context().add_class("primary-btn")
        web_btn.connect("clicked", lambda _: webbrowser.open(f"{PUBLIC_URL}/login"))
        links_box.pack_start(web_btn, False, False, 0)

        card.pack_start(links_box, False, False, 0)
        return card

    def _build_services_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        vbox.set_margin_top(10)
        vbox.set_margin_bottom(10)
        vbox.set_margin_start(14)
        vbox.set_margin_end(14)

        # Barra de Acciones para el Contenedor Seleccionado
        toolbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        lbl_sel = Gtk.Label(label="Acciones para el contenedor seleccionado:")
        lbl_sel.get_style_context().add_class("dim-label")
        toolbar.pack_start(lbl_sel, False, False, 0)

        btn_c_start = Gtk.Button(label="▶️ Iniciar")
        btn_c_start.get_style_context().add_class("action-btn")
        btn_c_start.connect("clicked", lambda _: self._action_selected_container("start"))
        toolbar.pack_start(btn_c_start, False, False, 0)

        btn_c_stop = Gtk.Button(label="⏹️ Detener")
        btn_c_stop.get_style_context().add_class("action-btn")
        btn_c_stop.connect("clicked", lambda _: self._action_selected_container("stop"))
        toolbar.pack_start(btn_c_stop, False, False, 0)

        btn_c_restart = Gtk.Button(label="🔄 Reiniciar")
        btn_c_restart.get_style_context().add_class("action-btn")
        btn_c_restart.connect("clicked", lambda _: self._action_selected_container("restart"))
        toolbar.pack_start(btn_c_restart, False, False, 0)

        btn_c_logs = Gtk.Button(label="📜 Ver Logs de este contenedor")
        btn_c_logs.get_style_context().add_class("action-btn")
        btn_c_logs.connect("clicked", lambda _: self._action_selected_container("view_logs"))
        toolbar.pack_start(btn_c_logs, False, False, 0)

        vbox.pack_start(toolbar, False, False, 0)

        # Lista de Servicios
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)

        # Model: [Nombre, Etiqueta, Puerto, Estado, Descripcion, Color_Badge]
        self.services_store = Gtk.ListStore(str, str, str, str, str, str)
        self.services_tree = Gtk.TreeView(model=self.services_store)

        cols = [
            ("Servicio / Contenedor", 1, 220),
            ("Puerto", 2, 80),
            ("Estado", 3, 130),
            ("Descripción", 4, 320),
        ]

        for title, idx, width in cols:
            renderer = Gtk.CellRendererText()
            col = Gtk.TreeViewColumn(title, renderer, text=idx)
            if idx == 3:
                col.add_attribute(renderer, "cell-background", 5)
                renderer.set_property("foreground", "#11111b")
                renderer.set_property("weight", 700)
            col.set_min_width(width)
            self.services_tree.append_column(col)

        self.services_tree.connect("row-activated", lambda t, p, c: self._action_selected_container("restart"))

        scrolled.add(self.services_tree)
        vbox.pack_start(scrolled, True, True, 0)

        return vbox

    def _build_logs_tab(self):
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        vbox.set_margin_top(10)
        vbox.set_margin_bottom(10)
        vbox.set_margin_start(14)
        vbox.set_margin_end(14)

        # Barra de Controles de Logs
        controls_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        
        # Selector de Fuente de Logs
        lbl_source = Gtk.Label(label="Servicio:")
        controls_box.pack_start(lbl_source, False, False, 0)

        self.log_combo = Gtk.ComboBoxText()
        self.log_combo.append("all", "📋 Todos los Contenedores (Compose)")
        for s in SERVICES_INFO:
            self.log_combo.append(s["name"], f"{s['label']} ({s['port']})")
        self.log_combo.set_active_id("all")
        self.log_combo.connect("changed", self._on_log_source_changed)
        controls_box.pack_start(self.log_combo, False, False, 0)

        # Buscador / Filtro
        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_placeholder_text("Filtrar logs en tiempo real...")
        self.search_entry.connect("search-changed", self._on_search_changed)
        controls_box.pack_start(self.search_entry, True, True, 0)

        # Auto-scroll Switch
        self.autoscroll_check = Gtk.CheckButton(label="Auto-scroll")
        self.autoscroll_check.set_active(True)
        self.autoscroll_check.connect("toggled", lambda w: setattr(self, 'auto_scroll', w.get_active()))
        controls_box.pack_start(self.autoscroll_check, False, False, 0)

        # Botón Pausar
        self.pause_btn = Gtk.Button(label="⏸️ Pausar")
        self.pause_btn.get_style_context().add_class("action-btn")
        self.pause_btn.connect("clicked", self._on_pause_logs_clicked)
        controls_box.pack_start(self.pause_btn, False, False, 0)

        # Botón Copiar Logs
        self.copy_btn = Gtk.Button(label="📋 Copiar")
        self.copy_btn.get_style_context().add_class("action-btn")
        self.copy_btn.connect("clicked", self._on_copy_logs_clicked)
        controls_box.pack_start(self.copy_btn, False, False, 0)

        # Botón Limpiar
        clear_btn = Gtk.Button(label="🗑️ Limpiar")
        clear_btn.get_style_context().add_class("action-btn")
        clear_btn.connect("clicked", lambda _: self.log_buffer.set_text(""))
        controls_box.pack_start(clear_btn, False, False, 0)

        vbox.pack_start(controls_box, False, False, 0)

        # Visor de Texto de Terminal
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scrolled.get_style_context().add_class("log-scrolled")
        self.log_scrolled = scrolled

        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_cursor_visible(True)
        self.log_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.log_view.get_style_context().add_class("log-terminal")
        self.log_buffer = self.log_view.get_buffer()

        # Tags para colores
        self.tag_error = self.log_buffer.create_tag("error", foreground="#f38ba8")
        self.tag_warn = self.log_buffer.create_tag("warn", foreground="#f9e2af")
        self.tag_info = self.log_buffer.create_tag("info", foreground="#89b4fa")
        self.tag_success = self.log_buffer.create_tag("success", foreground="#a6e3a1")

        scrolled.add(self.log_view)
        vbox.pack_start(scrolled, True, True, 0)

        return vbox

    # ================= LOGICA DE ESTADO =================

    def _start_status_checker(self):
        self._update_system_status()
        GLib.timeout_add_seconds(3, self._periodic_check)

    def _periodic_check(self):
        if not self.is_busy:
            threading.Thread(target=self._query_status_thread, daemon=True).start()
        return True

    def _query_status_thread(self):
        status_map = {}
        # Consultar docker
        try:
            res = subprocess.run(
                ["docker", "ps", "--format", "{{.Names}}:::{{.Status}}"],
                capture_output=True, text=True, timeout=4
            )
            for line in res.stdout.strip().splitlines():
                if ":::" in line:
                    cname, cstatus = line.split(":::", 1)
                    status_map[cname] = cstatus
        except Exception:
            pass

        # Consultar gateway.py
        try:
            gw_run = subprocess.run(["pgrep", "-f", "gateway.py"], capture_output=True).returncode == 0
            status_map["gateway.py"] = "En ejecución (Puerto 8090)" if gw_run else "Detenido"
        except Exception:
            status_map["gateway.py"] = "Detenido"

        # Consultar ngrok
        try:
            ng_run = subprocess.run(["pgrep", "-f", "ngrok"], capture_output=True).returncode == 0
            status_map["ngrok"] = "Túnel Activo (443)" if ng_run else "Detenido"
        except Exception:
            status_map["ngrok"] = "Detenido"

        GLib.idle_add(self._apply_status_results, status_map)

    def _apply_status_results(self, status_map):
        if self.is_busy:
            return

        # Calcular si el sistema está encendido
        docker_active_count = sum(1 for s in SERVICES_INFO if s["type"] == "docker" and s["name"] in status_map)
        gw_active = "gateway.py" in status_map and "En ejecución" in status_map["gateway.py"]
        ng_active = "ngrok" in status_map and "Activo" in status_map["ngrok"]

        is_online = (docker_active_count >= 8) and gw_active and ng_active
        self.system_online = is_online

        # Actualizar switch de manera segura
        self._updating_switch = True
        self.power_switch.set_active(is_online)
        self.power_switch.set_state(is_online)
        self._updating_switch = False

        # Actualizar badge
        if is_online:
            self.status_badge.set_text("🟢 SISTEMA ENCENDIDO")
            self.status_badge.get_style_context().remove_class("badge-offline")
            self.status_badge.get_style_context().remove_class("badge-busy")
            self.status_badge.get_style_context().add_class("badge-online")
        else:
            self.status_badge.set_text("🔴 SISTEMA APAGADO")
            self.status_badge.get_style_context().remove_class("badge-online")
            self.status_badge.get_style_context().remove_class("badge-busy")
            self.status_badge.get_style_context().add_class("badge-offline")

        # Actualizar lista de servicios
        # Guardar selección actual
        selection = self.services_tree.get_selection()
        model, tree_iter = selection.get_selected()
        selected_name = model[tree_iter][0] if tree_iter else None

        self.services_store.clear()
        iter_to_select = None
        for s in SERVICES_INFO:
            s_name = s["name"]
            status_text = status_map.get(s_name, "Detenido")
            is_up = ("Up" in status_text or "En ejecución" in status_text or "Activo" in status_text)
            color_bg = "#a6e3a1" if is_up else "#f38ba8"
            display_status = "ACTIVO" if is_up else "DETENIDO"
            cur_iter = self.services_store.append([
                s_name,
                s["label"],
                s["port"],
                display_status,
                s["desc"],
                color_bg
            ])
            if selected_name and s_name == selected_name:
                iter_to_select = cur_iter

        if iter_to_select:
            selection.select_iter(iter_to_select)

    def _update_system_status(self):
        threading.Thread(target=self._query_status_thread, daemon=True).start()

    # ================= CONTROL MAESTRO =================

    def _on_switch_activated(self, switch, gparam):
        if self._updating_switch or self.is_busy:
            return
        if switch.get_active():
            self._trigger_start()
        else:
            self._trigger_stop()

    def _set_busy(self, busy, status_msg):
        self.is_busy = busy
        self.btn_start.set_sensitive(not busy)
        self.btn_stop.set_sensitive(not busy)
        self.btn_restart.set_sensitive(not busy)
        self.power_switch.set_sensitive(not busy)

        if busy:
            self.spinner.start()
            self.status_badge.set_text(status_msg)
            self.status_badge.get_style_context().remove_class("badge-online")
            self.status_badge.get_style_context().remove_class("badge-offline")
            self.status_badge.get_style_context().add_class("badge-busy")
        else:
            self.spinner.stop()

    def _trigger_start(self):
        if self.is_busy:
            return
        self._set_busy(True, "⏳ ENCENDIENDO...")
        self._append_log_line("\n==========================================================\n")
        self._append_log_line(">>> [SISTEMA] Iniciando ecosistema GROG Smart Vending...\n")
        threading.Thread(target=self._run_start_job, daemon=True).start()

    def _run_start_job(self):
        try:
            self._append_log_line("[1/4] Limpiando procesos previos...\n")
            subprocess.run(["pkill", "-f", "gateway.py"], capture_output=True)
            subprocess.run(["pkill", "-f", "ngrok"], capture_output=True)
            subprocess.run(["pkill", "-f", "cloudflared"], capture_output=True)
            time.sleep(1)

            self._append_log_line("[2/4] Levantando contenedores Docker compose...\n")
            c_res = subprocess.run(
                ["docker", "compose", "-f", str(BACKEND_DIR / "docker-compose.yml"), "up", "-d"],
                capture_output=True, text=True, timeout=60
            )
            if c_res.stdout:
                self._append_log_line(c_res.stdout + "\n")
            if c_res.stderr:
                self._append_log_line(c_res.stderr + "\n")

            self._append_log_line("[3/4] Iniciando API Gateway Proxy Multihilo (8090)...\n")
            with open(LOGS_DIR / "gateway.log", "a") as gw_log:
                subprocess.Popen(
                    [sys.executable, str(PROXY_DIR / "gateway.py")],
                    stdout=gw_log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                    start_new_session=True
                )
            time.sleep(1)

            self._append_log_line("[4/4] Conectando túnel público Ngrok permanente...\n")
            with open(LOGS_DIR / "ngrok.log", "a") as ng_log:
                subprocess.Popen(
                    [str(NGROK_BIN), "http", "8090", "--url=passivism-sighing-condense.ngrok-free.dev"],
                    stdout=ng_log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                    start_new_session=True
                )
            time.sleep(2)

            # Asegurar puerto serie virtual para Gemelo Digital Unity (/tmp/ttyUNITY)
            if not os.path.exists("/tmp/ttyUNITY"):
                subprocess.Popen(
                    ["socat", "-d", "-d", "pty,raw,echo=0,link=/tmp/ttyUNITY", "pty,raw,echo=0,link=/tmp/ttyCLI"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL,
                    start_new_session=True
                )

            self._append_log_line(">>> ✅ SISTEMA COMPLETAMENTE ENCENDIDO Y EN LÍNEA.\n")
            self._append_log_line(f">>> 🌐 SimuPay Web: {PUBLIC_URL}/login\n")
            self._append_log_line("==========================================================\n")
        except Exception as e:
            self._append_log_line(f">>> ❌ Error al iniciar: {e}\n")
        finally:
            GLib.idle_add(lambda: self._set_busy(False, ""))
            GLib.idle_add(self._update_system_status)

    def _trigger_stop(self):
        if self.is_busy:
            return
        self._set_busy(True, "⏳ APAGANDO...")
        self._append_log_line("\n==========================================================\n")
        self._append_log_line(">>> [SISTEMA] Apagando ecosistema GROG Smart Vending...\n")
        threading.Thread(target=self._run_stop_job, daemon=True).start()

    def _run_stop_job(self):
        try:
            self._append_log_line("[1/3] Deteniendo API Gateway y túneles...\n")
            subprocess.run(["pkill", "-f", "gateway.py"], capture_output=True)
            subprocess.run(["pkill", "-f", "ngrok"], capture_output=True)
            subprocess.run(["pkill", "-f", "cloudflared"], capture_output=True)

            self._append_log_line("[2/3] Deteniendo contenedores Docker...\n")
            c_res = subprocess.run(
                ["docker", "compose", "-f", str(BACKEND_DIR / "docker-compose.yml"), "stop"],
                capture_output=True, text=True, timeout=30
            )
            if c_res.stdout:
                self._append_log_line(c_res.stdout + "\n")

            self._append_log_line("[3/3] >>> 🔴 SISTEMA APAGADO CORRECTAMENTE.\n")
            self._append_log_line("==========================================================\n")
        except Exception as e:
            self._append_log_line(f">>> ❌ Error al detener: {e}\n")
        finally:
            GLib.idle_add(lambda: self._set_busy(False, ""))
            GLib.idle_add(self._update_system_status)

    def _on_restart_all_clicked(self):
        if self.is_busy:
            return
        self._set_busy(True, "⏳ REINICIANDO...")
        self._append_log_line("\n>>> [SISTEMA] Reiniciando todo el ecosistema...\n")

        def _job():
            self._run_stop_job()
            time.sleep(1)
            self._run_start_job()

        threading.Thread(target=_job, daemon=True).start()

    # ================= ACCIONES POR CONTENEDOR =================

    def _action_selected_container(self, action):
        selection = self.services_tree.get_selection()
        model, tree_iter = selection.get_selected()
        if not tree_iter:
            self._append_log_line(">>> Selecciona primero un contenedor de la lista.\n")
            return

        c_name = model[tree_iter][0]
        c_label = model[tree_iter][1]

        if action == "view_logs":
            self.log_combo.set_active_id(c_name)
            self.notebook.set_current_page(1)
            return

        def _container_worker():
            self._append_log_line(f"\n>>> [{action.upper()}] Ejecutando en {c_label} ({c_name})...\n")
            if c_name == "gateway.py":
                subprocess.run(["pkill", "-f", "gateway.py"])
                if action in ("start", "restart"):
                    time.sleep(1)
                    with open(LOGS_DIR / "gateway.log", "a") as gw_log:
                        subprocess.Popen(
                            [sys.executable, str(PROXY_DIR / "gateway.py")],
                            stdout=gw_log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                            start_new_session=True
                        )
            elif c_name == "ngrok":
                subprocess.run(["pkill", "-f", "ngrok"])
                if action in ("start", "restart"):
                    time.sleep(1)
                    with open(LOGS_DIR / "ngrok.log", "a") as ng_log:
                        subprocess.Popen(
                            [str(NGROK_BIN), "http", "8090", "--url=passivism-sighing-condense.ngrok-free.dev"],
                            stdout=ng_log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                            start_new_session=True
                        )
            else:
                subprocess.run(["docker", action, c_name], capture_output=True, text=True)

            self._append_log_line(f">>> [{action.upper()}] Completado para {c_label}.\n")
            GLib.idle_add(self._update_system_status)

        threading.Thread(target=_container_worker, daemon=True).start()

    def _on_copy_url_clicked(self, _):
        clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        clipboard.set_text(PUBLIC_URL, -1)
        self._append_log_line(f">>> URL copiada al portapapeles: {PUBLIC_URL}\n")

    # ================= GESTOR DE LOGS STREAMING =================

    def _on_log_source_changed(self, combo):
        target = combo.get_active_id()
        if target:
            self._switch_log_source(target)

    def _switch_log_source(self, target):
        self.current_log_target = target
        if self.log_process:
            try:
                self.log_process.terminate()
            except Exception:
                pass
            self.log_process = None

        self.log_buffer.set_text(f"--- Visualizando logs de: {target} ---\n")
        self.log_thread = threading.Thread(target=self._tail_logs_thread, args=(target,), daemon=True)
        self.log_thread.start()

    def _tail_logs_thread(self, target):
        cmd = []
        if target == "all":
            cmd = ["docker", "compose", "-f", str(BACKEND_DIR / "docker-compose.yml"), "logs", "-f", "--tail=100"]
        elif target == "gateway.py":
            cmd = ["tail", "-n", "100", "-f", str(LOGS_DIR / "gateway.log")]
        elif target == "ngrok":
            cmd = ["tail", "-n", "100", "-f", str(LOGS_DIR / "ngrok.log")]
        else:
            cmd = ["docker", "logs", "-f", "--tail=100", target]

        try:
            self.log_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )
            for line in self.log_process.stdout:
                if self.log_paused:
                    continue
                if self.filter_keyword and self.filter_keyword.lower() not in line.lower():
                    continue
                GLib.idle_add(self._append_log_line, line)
        except Exception as e:
            GLib.idle_add(self._append_log_line, f"[Error de logs]: {e}\n")

    def _append_log_line(self, line):
        tag = None
        lower = line.lower()
        if "error" in lower or "fail" in lower or "fatal" in lower or "❌" in lower:
            tag = self.tag_error
        elif "warn" in lower:
            tag = self.tag_warn
        elif "success" in lower or "ok" in lower or "listos" in lower or "✅" in lower or "encendido" in lower:
            tag = self.tag_success
        elif "info" in lower or ">>>" in lower:
            tag = self.tag_info

        end_iter = self.log_buffer.get_end_iter()
        if tag:
            self.log_buffer.insert_with_tags(end_iter, line, tag)
        else:
            self.log_buffer.insert(end_iter, line)

        # Limitar buffer a 2500 líneas de forma segura
        if self.log_buffer.get_line_count() > 2500:
            start = self.log_buffer.get_start_iter()
            cut = self.log_buffer.get_iter_at_line(500)
            self.log_buffer.delete(start, cut)

        if self.auto_scroll:
            end_iter = self.log_buffer.get_end_iter()
            self.log_buffer.place_cursor(end_iter)
            insert_mark = self.log_buffer.get_insert()
            self.log_view.scroll_to_mark(insert_mark, 0.0, True, 0.0, 1.0)
        return False

    def _on_pause_logs_clicked(self, btn):
        self.log_paused = not self.log_paused
        btn.set_label("▶️ Reanudar" if self.log_paused else "⏸️ Pausar")

    def _on_copy_logs_clicked(self, btn):
        clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        bounds = self.log_buffer.get_selection_bounds()
        if bounds:
            start, end = bounds
            text = self.log_buffer.get_text(start, end, True)
        else:
            start = self.log_buffer.get_start_iter()
            end = self.log_buffer.get_end_iter()
            text = self.log_buffer.get_text(start, end, True)

        if text:
            clipboard.set_text(text, -1)
            clipboard.store()
            old_label = btn.get_label()
            btn.set_label("✅ ¡Copiado!")
            GLib.timeout_add(1500, lambda: btn.set_label(old_label))

    def _on_search_changed(self, entry):
        self.filter_keyword = entry.get_text().strip()


def main():
    app = VendingControlPanel()
    app.connect("destroy", Gtk.main_quit)
    app.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
