#!/bin/bash
echo "🔧 Installation du Dashboard Monitoring Web"
echo "=========================================="

# Vérifier Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 n'est pas installé"
    exit 1
fi

echo "✅ Python3 détecté"

# Créer environnement virtuel
echo "🐍 Création de l'environnement virtuel..."
python3 -m venv venv

# Activer
source venv/bin/activate

# Installer dépendances
echo "📦 Installation des dépendances..."
pip install --upgrade pip
pip install rich requests asciichartpy

echo "✅ Installation terminée !"
echo ""
echo "Pour démarrer le dashboard :"
echo "1. source venv/bin/activate"
echo "2. python3 dashboard.py"
echo ""
echo "Ou utilisez : ./start.sh"
