#!/bin/bash
# Script para aumentar swap de 8GB a 32GB y optimizar swappiness

set -e

echo "🔧 Optimización de SWAP"
echo "========================"
echo ""
echo "Estado actual:"
free -h | grep -E "Mem:|Swap:"
echo ""

# Verificar que tenemos espacio
AVAILABLE_GB=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
echo "📊 Espacio disponible en /: ${AVAILABLE_GB}GB"

if [ "$AVAILABLE_GB" -lt 35 ]; then
    echo "❌ No hay suficiente espacio (necesitamos 32GB + margen)"
    exit 1
fi

echo ""
echo "⚠️  Este script hará lo siguiente:"
echo "  1. Desactivar swap actual (8GB)"
echo "  2. Crear nuevo archivo de swap de 32GB"
echo "  3. Activar nuevo swap"
echo "  4. Reducir swappiness de 60 → 10"
echo "  5. Actualizar /etc/fstab"
echo ""
read -p "¿Continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelado"
    exit 0
fi

echo ""
echo "🔄 Paso 1: Desactivando swap actual..."
sudo swapoff /swap.img

echo "📝 Paso 2: Creando nuevo archivo de swap de 32GB..."
echo "  (esto puede tardar 1-2 minutos)"
sudo dd if=/dev/zero of=/swap.img bs=1M count=32768 status=progress

echo "🔒 Paso 3: Configurando permisos y formato..."
sudo chmod 600 /swap.img
sudo mkswap /swap.img

echo "✅ Paso 4: Activando swap..."
sudo swapon /swap.img

echo "⚙️  Paso 5: Configurando swappiness=10..."
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl vm.swappiness=10

echo "💾 Paso 6: Verificando /etc/fstab..."
if ! grep -q "^/swap.img" /etc/fstab; then
    echo "/swap.img none swap sw 0 0" | sudo tee -a /etc/fstab
    echo "  ✅ Entrada añadida a /etc/fstab"
else
    echo "  ✅ /etc/fstab ya contiene la entrada"
fi

echo ""
echo "✅ Optimización completada!"
echo ""
echo "Estado final:"
free -h | grep -E "Mem:|Swap:"
echo ""
echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
swapon --show
echo ""
echo "🎉 Swap aumentado de 8GB → 32GB y swappiness reducido a 10"
