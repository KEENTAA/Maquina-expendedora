#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Panel de Control y Switch Maestro - Ecosistema Gemelo Vending GROG (GUI Multiplataforma / Windows / Linux)
Permite encender/apagar el sistema completo, monitorear estado de servicios y abrir accesos directos.
"""

import os
import sys
import time
import subprocess
import threading
import webbrowser
from pathlib import Path
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext

BASE_DIR = Path(__file__).resolve().parent
BACKEND_DIR = BASE_DIR / "backend"
PROXY_DIR = BASE_DIR / "gateway-proxy"
LOGS_DIR = BASE_DIR / "logs"

SERVICES_INFO = [
    {"name": "backend-payment-gateway-frontend-1", "label": "SimuPay Web UI", "port": "5174", "type": "docker", "desc": "Frontend Web de billetera y login"},
    {"name": "backend-auth-service-1", "label": "Auth Service", "port": "8030", "type": "docker", "desc": "Autenticación y usuarios (JWT)"},
    {"name": "backend-simupay-service-1", "label": "SimuPay Service", "port": "8020", "type": "docker", "desc": "Billetera y transferencias"},
    {"name": "backend-orchestrator-service-1", "label": "Orchestrator Service", "port": "8010", "type": "docker", "desc": "Orquestador central de compras"},
    {"name": "backend-vending-service-1", "label": "Vending Service", "port": "8040", "type": "docker", "desc": "Inventario de slots y máquinas"},
    {"name": "backend-payment-gateway-1", "label": "Payment Gateway API", "port": "8001", "type": "docker", "desc": "Pasarela de cobro y wallets"},
    {"name": "backend-iot-service-1", "label": "IoT Bridge Service", "port": "8050", "type": "docker", "desc": "Telemetría y sensores"},
    {"name": "backend-notification-service-1", "label": "Notification Service", "port": "8070", "type": "docker", "desc": "WebSockets y avisos"},
    {"name": "backend-audit-service-1", "label": "Audit Service", "port": "8080", "type": "docker", "desc": "Registro de auditoría"},
    {"name": "grog-postgres", "label": "PostgreSQL DB", "port": "5433", "type": "docker", "desc": "Base de datos principal (grog)"},
    {"name": "grog-mosquitto", "label": "MQTT Mosquitto", "port": "1883", "type": "docker", "desc": "Broker IoT"},
    {"name": "backend-unity-webgl-1", "label": "Gemelo Digital WebGL", "port": "8060", "type": "docker", "desc": "Simulador 3D Unity"},
    {"name": "gateway.py", "label": "API Gateway Proxy", "port": "8090", "type": "process", "desc": "Gateway unificador multihilo"},
]

class GrogControlPanel:
    def __init__(self, root):
        self.root = root
        self.root.title("GROG Smart Vending - Panel de Control")
        self.root.geometry("980x720")
        self.root.configure(bg="#111827")
        self.root.minsize(800, 600)

        LOGS_DIR.mkdir(parents=True, exist_ok=True)

        self.service_cards = {}
        self.running_processes = {}
        self.is_monitoring = True

        self.setup_ui()
        self.start_monitoring_thread()

    def setup_ui(self):
        # Header Frame
        header = tk.Frame(self.root, bg="#1f2937", height=80, padx=20, pady=15)
        header.pack(fill="x")

        title_box = tk.Frame(header, bg="#1f2937")
        title_box.pack(side="left", fill="y")

        lbl_title = tk.Label(title_box, text="GROG SMART VENDING", font=("Segoe UI", 16, "bold"), fg="#38bdf8", bg="#1f2937")
        lbl_title.pack(anchor="w")

        lbl_sub = tk.Label(title_box, text="Panel de Monitoreo & Switch Maestro de Microservicios", font=("Segoe UI", 10), fg="#9ca3af", bg="#1f2937")
        lbl_sub.pack(anchor="w")

        # Global Control Buttons
        btn_box = tk.Frame(header, bg="#1f2937")
        btn_box.pack(side="right", fill="y")

        btn_start_all = tk.Button(btn_box, text="▶ INICIAR TODO", font=("Segoe UI", 10, "bold"), bg="#16a34a", fg="white", activebackground="#15803d", activeforeground="white", relief="flat", padx=12, pady=6, cursor="hand2", command=self.start_all_services)
        btn_start_all.pack(side="left", padx=6)

        btn_stop_all = tk.Button(btn_box, text="⏹ DETENER TODO", font=("Segoe UI", 10, "bold"), bg="#dc2626", fg="white", activebackground="#b91c1c", activeforeground="white", relief="flat", padx=12, pady=6, cursor="hand2", command=self.stop_all_services)
        btn_stop_all.pack(side="left", padx=6)

        # Quick Links Bar
        links_frame = tk.Frame(self.root, bg="#182234", padx=20, pady=8)
        links_frame.pack(fill="x")

        lbl_links = tk.Label(links_frame, text="Accesos directos:", font=("Segoe UI", 9, "bold"), fg="#60a5fa", bg="#182234")
        lbl_links.pack(side="left", padx=(0, 10))

        shortcuts = [
            ("💳 SimuPay Web (:5174)", "http://localhost:5174"),
            ("🌐 Gateway (:8090)", "http://localhost:8090"),
            ("🎮 Gemelo WebGL (:8060)", "http://localhost:8060"),
            ("📑 Swagger Orquestador", "http://localhost:8010/docs"),
            ("📑 Swagger Vending", "http://localhost:8040/docs"),
            ("📑 Swagger Auth", "http://localhost:8030/docs"),
        ]

        for text, url in shortcuts:
            btn = tk.Button(links_frame, text=text, font=("Segoe UI", 9), bg="#1e293b", fg="#e2e8f0", activebackground="#334155", activeforeground="white", relief="flat", padx=8, pady=3, cursor="hand2", command=lambda u=url: webbrowser.open(u))
            btn.pack(side="left", padx=4)

        # Botón para consola Pico WH NFC
        btn_pico = tk.Button(
            links_frame,
            text="📟 Consola Pico NFC",
            font=("Segoe UI", 9, "bold"),
            bg="#0284c7",
            fg="white",
            activebackground="#0369a1",
            activeforeground="white",
            relief="flat",
            padx=8,
            pady=3,
            cursor="hand2",
            command=self.open_pico_monitor
        )
        btn_pico.pack(side="left", padx=4)

        # Main Scrollable Services Container
        main_container = tk.Frame(self.root, bg="#111827", padx=20, pady=15)
        main_container.pack(fill="both", expand=True)

        canvas = tk.Canvas(main_container, bg="#111827", highlightthickness=0)
        scrollbar = ttk.Scrollbar(main_container, orient="vertical", command=canvas.yview)
        self.scrollable_frame = tk.Frame(canvas, bg="#111827")

        self.scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )

        canvas_window = canvas.create_window((0, 0), window=self.scrollable_frame, anchor="nw")

        def configure_canvas_width(event):
            canvas.itemconfig(canvas_window, width=event.width)
        canvas.bind("<Configure>", configure_canvas_width)

        canvas.configure(xscrollcommand=None, yscrollcommand=scrollbar.set)
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        # Mouse wheel support
        def on_mousewheel(event):
            canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
        canvas.bind_all("<MouseWheel>", on_mousewheel)

        # Build service cards
        self.create_service_cards()

        # Status Bar
        self.status_bar = tk.Label(self.root, text="Monitoreando servicios en tiempo real...", font=("Segoe UI", 9), fg="#9ca3af", bg="#0f172a", anchor="w", padx=15, pady=4)
        self.status_bar.pack(fill="x", side="bottom")

    def create_service_cards(self):
        for s in SERVICES_INFO:
            card = tk.Frame(self.scrollable_frame, bg="#1e293b", padx=15, pady=10, relief="solid", bd=1)
            card.pack(fill="x", pady=5)

            # Left: Info
            info_frame = tk.Frame(card, bg="#1e293b")
            info_frame.pack(side="left", fill="both", expand=True)

            title_row = tk.Frame(info_frame, bg="#1e293b")
            title_row.pack(anchor="w")

            lbl_name = tk.Label(title_row, text=s["label"], font=("Segoe UI", 11, "bold"), fg="#f8fafc", bg="#1e293b")
            lbl_name.pack(side="left")

            lbl_port = tk.Label(title_row, text=f" :{s['port']}", font=("Segoe UI", 10), fg="#38bdf8", bg="#1e293b")
            lbl_port.pack(side="left", padx=5)

            lbl_desc = tk.Label(info_frame, text=s["desc"], font=("Segoe UI", 9), fg="#94a3b8", bg="#1e293b")
            lbl_desc.pack(anchor="w")

            # Right: Status and Actions
            actions_frame = tk.Frame(card, bg="#1e293b")
            actions_frame.pack(side="right")

            badge = tk.Label(actions_frame, text="OFFLINE", font=("Segoe UI", 9, "bold"), fg="#ef4444", bg="#371b22", padx=10, pady=4)
            badge.pack(side="left", padx=8)

            btn_log = tk.Button(actions_frame, text="Logs", font=("Segoe UI", 8), bg="#334155", fg="#e2e8f0", relief="flat", padx=8, pady=3, cursor="hand2", command=lambda svc=s: self.view_logs(svc))
            btn_log.pack(side="left", padx=4)

            btn_open = tk.Button(actions_frame, text="Abrir", font=("Segoe UI", 8), bg="#2563eb", fg="white", relief="flat", padx=8, pady=3, cursor="hand2", command=lambda p=s["port"]: webbrowser.open(f"http://localhost:{p}"))
            btn_open.pack(side="left", padx=4)

            self.service_cards[s["name"]] = {
                "badge": badge,
                "info": s
            }

    def start_monitoring_thread(self):
        t = threading.Thread(target=self.monitor_loop, daemon=True)
        t.start()

    def monitor_loop(self):
        while self.is_monitoring:
            try:
                # 1. Check docker containers
                res = subprocess.run(["docker", "ps", "--format", "{{.Names}}"], capture_output=True, text=True, timeout=5)
                running_containers = set(res.stdout.splitlines()) if res.returncode == 0 else set()

                # 2. Check process gateway.py (port 8090)
                gateway_online = self.check_port_listening(8090)

                self.root.after(0, self.update_statuses, running_containers, gateway_online)
            except Exception as e:
                pass
            time.sleep(3)

    def check_port_listening(self, port):
        import socket
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(0.5)
                return s.connect_ex(('127.0.0.1', port)) == 0
        except:
            return False

    def update_statuses(self, running_containers, gateway_online):
        online_count = 0
        total_count = len(SERVICES_INFO)

        for s in SERVICES_INFO:
            name = s["name"]
            card = self.service_cards.get(name)
            if not card:
                continue

            is_online = False
            if s["type"] == "docker":
                is_online = any(name in c for c in running_containers)
            elif name == "gateway.py":
                is_online = gateway_online

            if is_online:
                card["badge"].config(text="ONLINE", fg="#22c55e", bg="#143224")
                online_count += 1
            else:
                card["badge"].config(text="OFFLINE", fg="#ef4444", bg="#371b22")

        self.status_bar.config(text=f"Estado del Sistema: {online_count}/{total_count} servicios en línea | Actualizado: {time.strftime('%H:%M:%S')}")

    def start_all_services(self):
        threading.Thread(target=self._run_start_all, daemon=True).start()

    def _run_start_all(self):
        self.status_bar.config(text="Iniciando todos los servicios, por favor espere...")
        try:
            # 1. Docker Compose
            subprocess.run(["docker", "compose", "up", "-d"], cwd=str(BACKEND_DIR), check=True)

            # 2. Gateway Proxy
            gateway_script = PROXY_DIR / "gateway.py"
            gateway_log = LOGS_DIR / "gateway.log"
            with open(gateway_log, "a") as logf:
                subprocess.Popen([sys.executable, str(gateway_script)], stdout=logf, stderr=logf)

            self.status_bar.config(text="Comando de inicio completado con éxito.")
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error al iniciar", str(e)))

    def stop_all_services(self):
        threading.Thread(target=self._run_stop_all, daemon=True).start()

    def _run_stop_all(self):
        self.status_bar.config(text="Deteniendo todos los servicios...")
        try:
            # 1. Stop Docker containers
            subprocess.run(["docker", "compose", "stop"], cwd=str(BACKEND_DIR))

            # 2. Stop gateway.py
            if sys.platform == "win32":
                subprocess.run(["powershell", "-Command", "Get-NetTCPConnection -State Listen -LocalPort 8090 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"])
            else:
                subprocess.run(["pkill", "-f", "gateway.py"])

            self.status_bar.config(text="Todos los servicios fueron detenidos.")
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error al detener", str(e)))

    def view_logs(self, svc):
        log_win = tk.Toplevel(self.root)
        log_win.title(f"Logs: {svc['label']}")
        log_win.geometry("750x500")
        log_win.configure(bg="#0f172a")

        txt = scrolledtext.ScrolledText(log_win, bg="#0f172a", fg="#e2e8f0", insertbackground="white", font=("Consolas", 9))
        txt.pack(fill="both", expand=True, padx=10, pady=10)

        def fetch_logs():
            if svc["type"] == "docker":
                res = subprocess.run(["docker", "logs", "--tail", "150", svc["name"]], capture_output=True, text=True)
                content = res.stdout + res.stderr
            else:
                log_file = LOGS_DIR / "gateway.log"
                content = log_file.read_text(encoding="utf-8", errors="ignore") if log_file.exists() else "No hay logs disponibles aún."

            txt.delete("1.0", tk.END)
            txt.insert(tk.END, content)
            txt.see(tk.END)

        fetch_logs()
        btn_refresh = tk.Button(log_win, text="↻ Actualizar Logs", bg="#2563eb", fg="white", relief="flat", command=fetch_logs)
        btn_refresh.pack(pady=5)

    def open_pico_monitor(self):
        monitor_script = BASE_DIR / "monitor_pico.py"
        if sys.platform == "win32":
            subprocess.Popen(["start", "cmd", "/k", sys.executable, str(monitor_script)], shell=True)
        else:
            subprocess.Popen(["x-terminal-emulator", "-e", f"{sys.executable} {monitor_script}"])


if __name__ == "__main__":
    root = tk.Tk()
    app = GrogControlPanel(root)
    root.mainloop()
