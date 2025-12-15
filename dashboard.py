#!/usr/bin/env python3
"""
Dashboard AUTO-RESIZE - S'adapte en temps réel
"""

import json
import requests
import subprocess
import time
import sys
import re
import os
import signal
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.layout import Layout
    from rich.live import Live
    from rich.text import Text
    from rich import box
    RICH_AVAILABLE = True
except ImportError:
    print("pip install rich requests")
    sys.exit(1)

console = Console()

class AutoResizeMonitor:
    def __init__(self, config_file="sites.json"):
        self.config = self.load_config(config_file)
        self.cycle = 0
        self.executor = ThreadPoolExecutor(max_workers=5)
        self.last_width = 0
        self.resized = False
        
        # Capturer le signal de resize (SIGWINCH)
        signal.signal(signal.SIGWINCH, self.handle_resize)
    
    def handle_resize(self, signum, frame):
        """Détecte le redimensionnement du terminal"""
        self.resized = True
    
    def get_terminal_size(self):
        """Récupère la taille actuelle du terminal"""
        try:
            size = os.get_terminal_size()
            return size.columns, size.lines
        except:
            return 100, 30  # Valeurs par défaut
    
    def load_config(self, config_file):
        """Charge la configuration"""
        try:
            with open(config_file, 'r') as f:
                return json.load(f)
        except:
            return {
                "refresh_interval": 30,
                "sites": [
                    {"name": "Google", "url": "https://google.com"},
                    {"name": "GitHub", "url": "https://github.com"},
                    {"name": "Cloudflare", "url": "https://cloudflare.com"},
                    {"name": "Wikipedia", "url": "https://wikipedia.org"},
                    {"name": "Reddit", "url": "https://reddit.com"},
                    {"name": "StackOverflow", "url": "https://stackoverflow.com"}
                ]
            }
    
    def get_ssl_expiry(self, hostname):
        """SSL expiry check"""
        try:
            cmd = f"openssl s_client -connect {hostname}:443 -servername {hostname} 2>/dev/null < /dev/null"
            cmd += " | openssl x509 -noout -enddate 2>/dev/null"
            
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
            
            if result.returncode == 0 and result.stdout:
                match = re.search(r'notAfter=(.+)', result.stdout.strip())
                if match:
                    expiry_str = match.group(1).replace(' GMT', '')
                    try:
                        expiry_date = datetime.strptime(expiry_str, '%b %d %H:%M:%S %Y')
                        days_left = (expiry_date - datetime.now()).days
                        return {
                            'success': True,
                            'days_left': days_left,
                            'expiry_str': expiry_date.strftime('%d/%m/%y')
                        }
                    except:
                        pass
            
            return {'success': False}
            
        except Exception:
            return {'success': False}
    
    def check_site(self, site):
        """Check a single site"""
        result = {
            'name': site.get('name', 'Unknown'),
            'url': site.get('url', ''),
            'timestamp': datetime.now(),
            'http_status': 'UNKNOWN',
            'response_time': 0,
            'ssl_info': {'success': False}
        }
        
        # HTTP check
        start_time = time.time()
        try:
            response = requests.get(result['url'], timeout=5, verify=True)
            result['response_time'] = time.time() - start_time
            result['http_status'] = response.status_code
        except Exception:
            result['http_status'] = 'ERROR'
        
        # SSL check
        if result['url'].startswith('https://'):
            try:
                hostname = result['url'].replace('https://', '').split('/')[0]
                result['ssl_info'] = self.get_ssl_expiry(hostname)
            except:
                pass
        
        return result
    
    def calculate_column_widths(self, width):
        """Calcule les largeurs de colonnes dynamiquement"""
        if width >= 150:
            # Très large
            return {
                'name': 30,
                'status': 15,
                'ssl': 15,
                'expiry': 20,
                'time': 12,
                'check': 15
            }
        elif width >= 120:
            # Large
            return {
                'name': 25,
                'status': 12,
                'ssl': 12,
                'expiry': 15,
                'time': 10,
                'check': 12
            }
        elif width >= 90:
            # Moyen
            return {
                'name': 20,
                'status': 10,
                'ssl': 10,
                'expiry': 12,
                'time': 8,
                'check': 10
            }
        elif width >= 70:
            # Petit
            return {
                'name': 15,
                'status': 8,
                'ssl': 8,
                'expiry': 10,
                'time': 7,
                'check': 8
            }
        else:
            # Très petit
            return {
                'name': 12,
                'status': 6,
                'ssl': 6,
                'expiry': 8,
                'time': 6,
                'check': 6
            }
    
    def create_full_width_table(self, results, width):
        """Crée un tableau qui utilise 100% de la largeur"""
        cols = self.calculate_column_widths(width)
        
        # Ajuster pour utiliser toute la largeur
        total_cols = sum(cols.values())
        extra_space = width - total_cols - 7  # 7 pour les bordures
        
        if extra_space > 0:
            # Distribuer l'espace supplémentaire proportionnellement
            cols['name'] += int(extra_space * 0.4)
            cols['expiry'] += int(extra_space * 0.3)
            cols['status'] += int(extra_space * 0.15)
            cols['ssl'] += int(extra_space * 0.15)
        
        # Créer le tableau
        table = Table(
            box=box.ROUNDED,
            show_header=True,
            header_style="bold blue",
            expand=True,
            width=None  # None pour s'adapter au conteneur
        )
        
        # Ajouter les colonnes
        table.add_column("Site", style="cyan", width=cols['name'], no_wrap=False)
        table.add_column("Statut", justify="center", width=cols['status'])
        table.add_column("SSL", justify="center", width=cols['ssl'])
        table.add_column("Expiration", width=cols['expiry'])
        table.add_column("Temps", justify="right", width=cols['time'])
        table.add_column("Vérifié", width=cols['check'])
        
        # Remplir
        for site in results:
            name = site['name']
            status = site['http_status']
            
            # Status
            if status == 200:
                status_text = "[bold green]✓ 200[/bold green]"
            elif isinstance(status, int) and status < 400:
                status_text = f"[green]{status}[/green]"
            elif isinstance(status, int):
                status_text = f"[red]{status}[/red]"
            else:
                status_text = f"[yellow]{status}[/yellow]"
            
            # SSL
            ssl_info = site['ssl_info']
            if ssl_info.get('success'):
                days = ssl_info.get('days_left', 0)
                if days > 30:
                    ssl_text = f"[green]🔒 {days}j[/green]"
                elif days > 7:
                    ssl_text = f"[yellow]⚠ {days}j[/yellow]"
                elif days > 0:
                    ssl_text = f"[red]🚨 {days}j[/red]"
                else:
                    ssl_text = "[bold red]🔓 EXP[/bold red]"
                expiry_text = ssl_info.get('expiry_str', 'N/A')
            else:
                ssl_text = "[grey]—[/grey]"
                expiry_text = "N/A"
            
            # Time
            rt = site['response_time']
            if rt > 0:
                if rt < 0.5:
                    time_text = f"[green]{rt:.2f}s[/green]"
                elif rt < 2:
                    time_text = f"[yellow]{rt:.2f}s[/yellow]"
                else:
                    time_text = f"[red]{rt:.2f}s[/red]"
            else:
                time_text = "[grey]N/A[/grey]"
            
            # Check time
            check_time = site['timestamp'].strftime("%H:%M")
            
            table.add_row(name, status_text, ssl_text, expiry_text, time_text, check_time)
        
        return table
    
    def create_minimal_table(self, results, width):
        """Tableau minimal pour petits terminaux"""
        table = Table(box=box.SIMPLE, show_header=True, expand=True)
        
        if width >= 60:
            table.add_column("Site", style="cyan", min_width=15, max_width=25)
            table.add_column("S", width=3)
            table.add_column("SSL", width=4)
            table.add_column("T", width=6)
            table.add_column("Check", width=6)
        else:
            table.add_column("Site", style="cyan", width=12)
            table.add_column("S", width=2)
            table.add_column("SSL", width=3)
            table.add_column("T", width=5)
        
        for site in results:
            name = site['name'][:12] if len(site['name']) > 12 else site['name']
            status = site['http_status']
            
            # Status icon
            if status == 200:
                status_icon = "[green]✓[/green]"
            elif isinstance(status, int) and status < 400:
                status_icon = "[yellow]~[/yellow]"
            else:
                status_icon = "[red]✗[/red]"
            
            # SSL icon
            ssl_info = site['ssl_info']
            if ssl_info.get('success'):
                days = ssl_info.get('days_left', 0)
                if days > 30:
                    ssl_icon = "[green]✓[/green]"
                elif days > 0:
                    ssl_icon = "[yellow]![/yellow]"
                else:
                    ssl_icon = "[red]✗[/red]"
            else:
                ssl_icon = "[grey]-[/grey]"
            
            # Time
            rt = site['response_time']
            if rt > 0:
                time_text = f"{rt:.1f}s"
            else:
                time_text = "N/A"
            
            # Check time
            check_time = site['timestamp'].strftime("%H:%M")
            
            if width >= 60:
                table.add_row(name, status_icon, ssl_icon, time_text, check_time)
            else:
                table.add_row(name, status_icon, ssl_icon, time_text)
        
        return table
    
    def create_dashboard(self, results):
        """Crée le dashboard adaptatif"""
        width, height = self.get_terminal_size()
        
        # Vérifier si resize détecté
        if self.resized or width != self.last_width:
            console.clear()
            self.resized = False
            self.last_width = width
        
        # Header avec info taille
        current_time = datetime.now().strftime("%H:%M:%S")
        size_info = f"{width}×{height}"
        
        header_text = f"[bold cyan]🌐 MONITORING [{size_info}][/bold cyan] | C:{self.cycle} | {current_time}"
        header = Panel(header_text, border_style="cyan")
        
        # Choisir le type de tableau
        if width >= 70:
            table = self.create_full_width_table(results, width)
            table_title = "📋 Sites monitorés (100% largeur)"
        else:
            table = self.create_minimal_table(results, width)
            table_title = "📋 Monitoring"
        
        table_panel = Panel(table, border_style="green", title=table_title)
        
        # Statistiques adaptatives
        total = len(results)
        http_ok = sum(1 for r in results if r['http_status'] == 200)
        ssl_ok = sum(1 for r in results if r['ssl_info'].get('success') and r['ssl_info'].get('days_left', 0) > 0)
        
        if width >= 100:
            stats_text = f"""
[bold]📊 STATISTIQUES[/bold]

Sites: [white]{total}[/white]
✅ HTTP: [green]{http_ok}[/green]
🔒 SSL: [green]{ssl_ok}[/green]

[dim]Largeur: {width} cols | Hauteur: {height} lines[/dim]
"""
            stats_panel = Panel(stats_text, border_style="yellow")
            
            # Layout pour grand écran
            layout = Layout()
            layout.split(
                Layout(header, size=3),
                Layout(table_panel, name="main"),
                Layout(stats_panel, size=8)
            )
            
        elif width >= 70:
            stats_text = f"""
Sites: {total} | ✅: {http_ok} | 🔒: {ssl_ok}
Width: {width} | Refresh: {self.config.get('refresh_interval', 30)}s
"""
            stats_panel = Panel(stats_text, border_style="yellow")
            
            layout = Layout()
            layout.split(
                Layout(header, size=2),
                Layout(table_panel, name="main"),
                Layout(stats_panel, size=4)
            )
            
        else:
            # Très petit: pas de stats panel
            layout = Layout()
            layout.split(
                Layout(header, size=2),
                Layout(table_panel, name="main")
            )
        
        return layout
    
    def run_checks(self):
        """Exécute les vérifications"""
        self.cycle += 1
        
        futures = [self.executor.submit(self.check_site, site) for site in self.config['sites']]
        results = []
        
        for future in as_completed(futures):
            try:
                results.append(future.result(timeout=10))
            except:
                pass
        
        return sorted(results, key=lambda x: x['name'])
    
    def run(self):
        """Lance le dashboard"""
        console.clear()
        console.print("[green]🚀 Dashboard Auto-Resize[/green]")
        console.print("[yellow]Redimensionnez la fenêtre pour voir l'adaptation en direct![/yellow]")
        console.print("[dim]Ctrl+C pour quitter[/dim]")
        time.sleep(2)
        
        try:
            with Live(refresh_per_second=3, screen=True) as live:
                while True:
                    # Vérifier le redimensionnement
                    current_width, _ = self.get_terminal_size()
                    
                    # Exécuter les checks
                    results = self.run_checks()
                    
                    # Mettre à jour l'affichage
                    dashboard = self.create_dashboard(results)
                    live.update(dashboard)
                    
                    # Pause plus courte pour réactivité au resize
                    for _ in range(self.config.get('refresh_interval', 30)):
                        if self.resized:
                            break  # Redessiner immédiatement si resize
                        time.sleep(1)
                        
        except KeyboardInterrupt:
            console.print("\n[yellow]👋 Arrêt[/yellow]")

def main():
    monitor = AutoResizeMonitor()
    monitor.run()

if __name__ == "__main__":
    main()
