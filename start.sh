#!/bin/bash
cd "$(dirname "$0")"

# Activer l'environnement virtuel
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d "dashboard_env" ]; then
    source dashboard_env/bin/activate
fi

# Lancer le dashboard
python3 dashboard.py "$@"
