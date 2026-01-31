#!/bin/bash
# Finalizar configuración de swap

echo "🔧 Finalizando configuración de swap..."
echo ""

# Verificar archivo
if [ ! -f /swap.img ]; then
    echo "❌ /swap.img no existe"
    exit 1
fi

echo "📊 Tamaño actual:"
ls -lh /swap.img

echo ""
echo "🔨 Formateando swap..."
sudo mkswap /swap.img

echo ""
echo "✅ Activando swap..."
sudo swapon /swap.img

echo ""
echo "⚙️  Configurando swappiness=10..."
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl vm.swappiness=10

echo ""
echo "💾 Verificando /etc/fstab..."
if ! grep -q "^/swap.img" /etc/fstab; then
    echo "/swap.img none swap sw 0 0" | sudo tee -a /etc/fstab
    echo "  ✅ Entrada añadida a /etc/fstab"
else
    echo "  ✅ /etc/fstab ya contiene la entrada"
fi

echo ""
echo "✅ Configuración completada!"
echo ""
free -h | grep -E "Mem:|Swap:"
echo ""
echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
swapon --show
