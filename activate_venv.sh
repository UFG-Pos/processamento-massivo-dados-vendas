#!/bin/bash
# Script de ativação rápida do ambiente virtual

if [ -d "venv" ]; then
    source venv/bin/activate
    echo "✅ Ambiente virtual ativado!"
    echo "📦 Python: $(python --version)"
    echo "📍 Localização: $(which python)"
    echo ""
    echo "💡 Para desativar, use: deactivate"
else
    echo "❌ Ambiente virtual não encontrado!"
    echo "   Execute: ./setup_venv.sh"
fi
