cat > dashboard.py << 'EOF'
#!/usr/bin/env python3
"""
Dashboard RESPONSIVE - Tableau 100% largeur terminal
"""

import json
import requests
import subprocess
import time
import sys
import re
import os
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
    from rich.columns import Columns
    RICH_AVAILABLE = True
except ImportError:
    print("Installez: pip install rich requests")
    sys.exit(1)

console = Console()

class ResponsiveMonitor:
    def __init__(self, config_file="sites.json"):
        self.config = self.load_config(config_file)
        self.cycle = 0
        self.executor = ThreadPoolExecutor(max_workers=5)
        self.terminal_width = self.get_terminal_width()
    
    def get_terminal_width(self):
        """Récupère la largeur actuelle du terminal"""
        try:
            columns = os.get_terminal_size().columns
            return max(80, columns)  # Minimum 80 colonnes
        except:
            return 100  # Valeur par défaut
    
    def load_config(self, config_file):
        """Charge la configuration"""
        default_config = {
            "refresh_interval": 30,
            "sites": [
                {"name": "Google", "url": "https://google.com"},
                {"name": "GitHub", "url": "https://github.com"},
                {"name": "Cloudflare", "url": "https://cloudflare.com"},
                {"name": "Python", "url": "https://python.org"},
                {"name": "Wikipedia", "url": "https://wikipedia.org"}
            ]
        }
        
        try:
            with open(config_file, 'r') as f:
                return json.load(f)
        except:
            return default_config
    
    def get_ssl_expiry(self, hostname):
        """Récupère la date d'expiration SSL"""
        try:
            cmd = f"openssl s_client -connect {hostname}:443 -servername {hostname} 2>/dev/null < /dev/null"
            cmd += " | openssl x509 -noout -enddate 2>/dev/null"
            
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0 and result.stdout:
                match = re.search(r'notAfter=(.+)', result.stdout.strip())
                if match:
                    expiry_str = match.group(1).replace(' GMT', '')
                    try:
                        expiry_date = datetime.strptime(expiry_str, '%b %d %H:%M:%S %Y')
                        days_left = (expiry_date - datetime.now()).days
                        
                        return {
                            'success': True,
                            'expiry_date': expiry_date,
                            'expiry_str': expiry_date.strftime('%d/%m/%y'),
                            'days_left': days_left,
                            'expired': days_left <= 0
                        }
                    except:
                        pass
            
            return {'success': False, 'error': 'Non trouvé'}
            
        except Exception:
            return {'success': False, 'error': 'Timeout'}
    
    def check_site(self, site):
        """Vérifie un site"""
        result = {
            'name': site.get('name', 'Unknown'),
            'url': site.get('url', ''),
            'timestamp': datetime.now(),
            'http_status': 'UNKNOWN',
            'response_time': 0,
            'ssl_info': {'success': False, 'error': 'Non vérifié'},
            'error': None
        }
        
        # HTTP check
        start_time = time.time()
        try:
            response = requests.get(
                result['url'],
                timeout=5,
                headers={'User-Agent': 'Dashboard'},
                verify=True
            )
            result['response_time'] = time.time() - start_time
            result['http_status'] = response.status_code
        except requests.exceptions.Timeout:
            result['http_status'] = 'TIMEOUT'
        except requests.exceptions.ConnectionError:
            result['http_status'] = 'CONN_ERR'
        except Exception as e:
            result['http_status'] = 'ERROR'
            result['error'] = str(e)[:20]
        
        # SSL check
        if result['url'].startswith('https://'):
            try:
                hostname = result['url'].replace('https://', '').replace('http://', '').split('/')[0]
                result['ssl_info'] = self.get_ssl_expiry(hostname)
            except:
                result['ssl_info'] = {'success': False, 'error': 'Erreur'}
        
        return result
    
    def create_responsive_table(self, results):
        """Crée un tableau qui s'adapte à la largeur"""
        # Mettre à jour la largeur du terminal
        self.terminal_width = self.get_terminal_width()
        
        # Calculer les largeurs dynamiques
        if self.terminal_width >= 120:
            # Grand terminal
            col_name = 25
            col_http = 12
            col_ssl = 15
            col_date = 15
            col_time = 12
            col_check = 12
        elif self.terminal_width >= 90:
            # Terminal moyen
            col_name = 20
            col_http = 10
            col_ssl = 12
            col_date = 12
            col_time = 10
            col_check = 10
        else:
            # Petit terminal
            col_name = 15
            col_http = 8
            col_ssl = 8
            col_date = 10
            col_time = 8
            col_check = 8
        
        # Ajuster pour utiliser 100% de la largeur
        total_cols = col_name + col_http + col_ssl + col_date + col_time + col_check
        padding = self.terminal_width - total_cols
        
        if padding > 0:
            # Distribuer l'espace supplémentaire
            col_name += padding // 6
            col_date += padding // 6
        
        # Créer le tableau
        table = Table(
            box=box.ROUNDED,
            show_header=True,
            header_style="bold blue",
            expand=True  # CRITIQUE: étendre à la largeur disponible
        )
        
        # Colonnes avec largeurs calculées
        table.add_column("Site", style="cyan", width=col_name, no_wrap=True)
        table.add_column("HTTP", justify="center", width=col_http)
        table.add_column("SSL", width=col_ssl)
        table.add_column("Expiration", width=col_date)
        table.add_column("Temps", justify="right", width=col_time)
        table.add_column("Check", width=col_check)
        
        # Remplir le tableau
        for site in results:
            name = site['name']
            
            # HTTP status
            status = site['http_status']
            if status == 200:
                http_text = "[green]✓ 200[/green]"
            elif isinstance(status, int) and 200 <= status < 300:
                http_text = f"[green]✓ {status}[/green]"
            elif isinstance(status, int) and 300 <= status < 400:
                http_text = f"[yellow]↪ {status}[/yellow]"
            elif isinstance(status, int):
                http_text = f"[red]✗ {status}[/red]"
            else:
                http_text = f"[red]{status}[/red]"
            
            # SSL info
            ssl_info = site['ssl_info']
            if ssl_info.get('success'):
                days = ssl_info.get('days_left', 0)
                if days > 30:
                    ssl_text = f"[green]🔒 {days}j[/green]"
                    expiry_text = ssl_info.get('expiry_str', 'N/A')
                elif days > 7:
                    ssl_text = f"[yellow]⚠ {days}j[/yellow]"
                    expiry_text = ssl_info.get('expiry_str', 'N/A')
                elif days > 0:
                    ssl_text = f"[red]🚨 {days}j[/red]"
                    expiry_text = ssl_info.get('expiry_str', 'N/A')
                else:
                    ssl_text = "[bold red]🔓 EXP[/bold red]"
                    expiry_text = "EXPIRÉ"
            else:
                ssl_text = "[grey]— N/A[/grey]"
                expiry_text = "N/A"
            
            # Response time
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
            check_time = site['timestamp'].strftime("%H:%M:%S")
            
            # Ajouter la ligne
            table.add_row(
                name,
                http_text,
                ssl_text,
                expiry_text,
                time_text,
                check_time
            )
        
        return table
    
    def create_compact_view(self, results):
        """Vue compacte pour petits terminaux"""
        table = Table(box=box.SIMPLE, show_header=True, expand=True)
        
        if self.terminal_width >= 80:
            table.add_column("Site", style="cyan", width=20)
            table.add_column("Status", width=10)
            table.add_column("SSL", width=8)
            table.add_column("Time", width=8)
        else:
            # Très petit terminal
            table.add_column("Site", style="cyan", width=15)
            table.add_column("S", width=4)  # Status
            table.add_column("SSL", width=6)
            table.add_column("T", width=6)  # Time
        
        for site in results:
            name = site['name'][:15] if len(site['name']) > 15 else site['name']
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
            
            if self.terminal_width >= 80:
                table.add_row(name, status_icon, ssl_icon, time_text)
            else:
                table.add_row(name, status_icon, ssl_icon, time_text)
        
        return table
    
    def create_stats_panel(self, results):
        """Panneau de statistiques"""
        total = len(results)
        http_ok = sum(1 for r in results if r['http_status'] == 200)
        
        ssl_valid = sum(1 for r in results 
                       if r['ssl_info'].get('success') and 
                       r['ssl_info'].get('days_left', 0) > 0)
        
        avg_time = sum(r['response_time'] for r in results if r['response_time'] > 0)
        avg_time = avg_time / total if total > 0 else 0
        
        # Adaptabilité selon largeur
        if self.terminal_width >= 100:
            stats_text = f"""
[bold cyan]📊 STATISTIQUES[/bold cyan]

Sites monitorés: [white]{total}[/white]
✅ En ligne: [green]{http_ok}[/green]
❌ Hors ligne: [red]{total - http_ok}[/red]

🔒 SSL valides: [green]{ssl_valid}[/green]
⚠️  SSL problèmes: [yellow]{total - ssl_valid}[/yellow]

⏱️  Temps moyen: [white]{avg_time:.2f}s[/white]
🔄 Cycle: [dim]{self.cycle}[/dim]
"""
        elif self.terminal_width >= 70:
            stats_text = f"""
[bold]📊 STATS[/bold]

Sites: [white]{total}[/white]
✅: [green]{http_ok}[/green]
❌: [red]{total-http_ok}[/red]

SSL ✓: [green]{ssl_valid}[/green]
SSL ✗: [red]{total-ssl_valid}[/red]

Time: [white]{avg_time:.2f}s[/white]
"""
        else:
            stats_text = f"""
Sites: {total}
✅: {http_ok} ❌: {total-http_ok}
SSL: {ssl_valid}/{total}
Avg: {avg_time:.1f}s
"""
        
        return Panel(stats_text, border_style="cyan")
    
    def create_dashboard(self, results):
        """Crée l'ensemble du dashboard"""
        # Mettre à jour la largeur
        self.terminal_width = self.get_terminal_width()
        
        # Header responsive
        current_time = datetime.now().strftime("%H:%M:%S")
        terminal_info = f"Terminal: {self.terminal_width} cols"
        
        if self.terminal_width >= 100:
            header_text = f"[bold cyan]🌐 MONITORING WEB[/bold cyan] | Cycle: {self.cycle} | {current_time} | {terminal_info}"
        elif self.terminal_width >= 70:
            header_text = f"[bold cyan]🌐 MONITOR[/bold cyan] | C:{self.cycle} | {current_time}"
        else:
            header_text = f"🌐 C:{self.cycle} | {current_time}"
        
        header = Panel(header_text, border_style="cyan")
        
        # Choisir la vue tableau selon la largeur
        if self.terminal_width >= 80:
            table = self.create_responsive_table(results)
            table_panel = Panel(table, border_style="green", title="📋 Sites monitorés")
        else:
            table = self.create_compact_view(results)
            table_panel = Panel(table, border_style="green")
        
        # Stats panel
        stats_panel = self.create_stats_panel(results)
        
        # Layout adaptatif
        layout = Layout()
        
        if self.terminal_width >= 120:
            # Large: Tableau + stats côte à côte
            layout.split(
                Layout(header, size=3),
                Layout(table_panel, name="main"),
                Layout(stats_panel, size=12)
            )
        elif self.terminal_width >= 90:
            # Moyen: Tableau seul puis stats
            layout.split(
                Layout(header, size=3),
                Layout(table_panel, name="main", size=15),
                Layout(stats_panel, name="stats")
            )
        else:
            # Petit: Tout vertical
            layout.split(
                Layout(header, size=2),
                Layout(table_panel, name="table"),
                Layout(stats_panel, name="stats", size=8)
            )
        
        return layout
    
    def run_checks(self):
        """Exécute les vérifications"""
        self.cycle += 1
        
        futures = []
        for site in self.config['sites']:
            future = self.executor.submit(self.check_site, site)
            futures.append(future)
        
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
        
        # Afficher info terminal
        console.print(f"[dim]Largeur terminal: {self.terminal_width} colonnes[/dim]")
        console.print("[green]🚀 Dashboard Responsive - Tableau 100% largeur[/green]")
        console.print("[yellow]Redimensionnez la fenêtre pour voir l'adaptation![/yellow]")
        time.sleep(2)
        
        try:
            with Live(refresh_per_second=2, screen=True, transient=True) as live:
                while True:
                    # Vérifications
                    results = self.run_checks()
                    
                    # Mettre à jour la largeur à chaque cycle
                    self.terminal_width = self.get_terminal_width()
                    
                    # Créer et afficher le dashboard
                    dashboard = self.create_dashboard(results)
                    live.update(dashboard)
                    
                    # Pause
                    time.sleep(self.config.get('refresh_interval', 30))
                    
        except KeyboardInterrupt:
            console.print("\n[yellow]👋 Arrêt du dashboard[/yellow]")
        except Exception as e:
            console.print(f"[red]❌ Erreur: {e}[/red]")

def main():
    """Point d'entrée"""
    monitor = ResponsiveMonitor()
    monitor.run()

if __name__ == "__main__":
    main()
EOF
