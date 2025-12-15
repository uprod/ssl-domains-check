# 🌐 Web Monitoring Dashboard

Un dashboard élégant et responsive pour surveiller l'état de vos sites web en temps réel, avec vérification SSL intégrée et interface adaptative au terminal.

## 🎯 Deux modes d'installation disponibles

### 🔧 **Mode 1 : Installation COMPLÈTE (repart de zéro)**
**Utilisez ce mode si vous n'avez AUCUN fichier du projet.**

```bash
# 1. Téléchargez seulement le script setup.sh
curl -O https://raw.githubusercontent.com/uprod/ssl-domains-check/main/setup.sh

# 2. Exécutez-le pour créer TOUS les fichiers
chmod +x setup.sh
./setup.sh

# Maintenant vous avez :
# - dashboard.py (dashboard principal)
# - sites.example.json (exemple de configuration)
# - install.sh (installation dépendances)
# - start.sh (lancement)