# 🌐 Web Monitoring Dashboard - Responsive Terminal Interface

[![Python Version](https://img.shields.io/badge/python-3.7%2B-blue)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rich Terminal](https://img.shields.io/badge/terminal-rich-green)](https://github.com/Textualize/rich)

Un dashboard élégant et **100% responsive** pour surveiller vos sites web en temps réel. L'interface s'adapte automatiquement à la taille de votre terminal avec vérification SSL intégrée.


## ✨ Fonctionnalités principales

- ✅ **Monitoring HTTP/HTTPS** en temps réel
- 🔒 **Vérification SSL** avec expiration détaillée
- 📱 **Interface 100% responsive** - s'adapte au terminal
- ⚡ **Vérifications parallèles** pour plus de rapidité
- 🎨 **UI colorée** avec la bibliothèque Rich
- 📊 **Statistiques live** mise à jour automatiquement
- 🔄 **Auto-refresh** configurable (30s par défaut)
- 🚨 **Alertes visuelles** par code couleur
- 📈 **Historique des performances**

## 🚀 Installation Ultra-Rapide (30 secondes)

### **Option A : Installation depuis ZÉRO** (sans fichiers existants)
```bash
# 1. Télécharger seulement le script d'installation
curl -O https://raw.githubusercontent.com/uprod/ssl-domains-check/main/setup.sh

# 2. Exécuter pour créer TOUT le projet
chmod +x setup.sh
./setup.sh

# 3. Installer les dépendances
chmod +x install.sh start.sh
./install.sh

# 4. Configurer vos sites
cp sites.example.json sites.json
nano sites.json  # Éditez avec vos URLs

# 5. Lancer !
./start.sh
```

### **Option B : Installation LÉGÈRE** (fichiers existants)
```bash
# Si vous avez déjà les fichiers (git clone, téléchargement ZIP)
chmod +x install.sh start.sh
./install.sh
cp sites.example.json sites.json
nano sites.json
./start.sh
```

### **📋 Configuration**
```json
{
	"refresh_interval": 30,
	"sites": [
		{
			"name": "Google Search",
			"url": "https://www.google.com",
			"expected_status": 200,
			"ssl_check": true,
			"timeout": 5
		},
		{
			"name": "GitHub",
			"url": "https://github.com",
			"expected_status": 200,
			"ssl_check": true,
			"timeout": 5
		}
	]
}
```