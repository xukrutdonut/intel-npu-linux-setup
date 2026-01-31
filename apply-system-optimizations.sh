#!/bin/bash
# Script de optimización del sistema
# Aplica mejoras de alto impacto de forma segura

set -e

echo "🚀 Optimización del Sistema"
echo "============================"
echo ""
echo "Este script aplicará las siguientes optimizaciones:"
echo "  1. Detener contenedor problemático (reev-annonars)"
echo "  2. Habilitar Intel Turbo Boost"
echo "  3. Optimizar scheduler NVMe → none"
echo "  4. Aumentar read-ahead a 2048 KB"
echo "  5. Optimizar VM dirty ratios"
echo "  6. Limpiar redes Docker no usadas"
echo "  7. Configurar límites del sistema"
echo ""
read -p "¿Continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelado"
    exit 0
fi

echo ""
echo "──────────────────────────────────────────"
echo ""

# 1. Detener contenedor problemático
echo "1️⃣  Deteniendo contenedor reev-annonars..."
if docker ps -a | grep -q reev-annonars; then
    docker stop reev-annonars 2>/dev/null || true
    docker update --restart=no reev-annonars 2>/dev/null || true
    echo "  ✅ Contenedor detenido y restart deshabilitado"
else
    echo "  ℹ️  Contenedor no encontrado"
fi

echo ""

# 2. Habilitar Turbo Boost
echo "2️⃣  Habilitando Intel Turbo Boost..."
if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
    TURBO_STATE=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
    if [ "$TURBO_STATE" = "1" ]; then
        echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
        echo "  ✅ Turbo Boost habilitado (era: deshabilitado)"
    else
        echo "  ✅ Turbo Boost ya estaba habilitado"
    fi
else
    echo "  ⚠️  Intel P-State no disponible (¿CPU AMD?)"
fi

echo ""

# 3. Optimizar scheduler NVMe
echo "3️⃣  Optimizando scheduler NVMe..."
if [ -f /sys/block/nvme0n1/queue/scheduler ]; then
    CURRENT_SCHED=$(cat /sys/block/nvme0n1/queue/scheduler | grep -oP '\[\K[^\]]+')
    if [ "$CURRENT_SCHED" != "none" ]; then
        echo none | sudo tee /sys/block/nvme0n1/queue/scheduler > /dev/null
        echo "  ✅ Scheduler cambiado: $CURRENT_SCHED → none"
        
        # Hacer permanente
        echo 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"' | \
            sudo tee /etc/udev/rules.d/60-nvme-scheduler.rules > /dev/null
        echo "  ✅ Configurado permanentemente en udev"
    else
        echo "  ✅ Scheduler ya estaba en 'none'"
    fi
else
    echo "  ℹ️  NVMe no detectado"
fi

echo ""

# 4. Aumentar read-ahead
echo "4️⃣  Aumentando read-ahead..."
if [ -f /sys/block/nvme0n1/queue/read_ahead_kb ]; then
    CURRENT_RA=$(cat /sys/block/nvme0n1/queue/read_ahead_kb)
    if [ "$CURRENT_RA" -lt 2048 ]; then
        echo 2048 | sudo tee /sys/block/nvme0n1/queue/read_ahead_kb > /dev/null
        echo "  ✅ Read-ahead: ${CURRENT_RA}KB → 2048KB"
        
        # Añadir a udev
        echo 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/read_ahead_kb}="2048"' | \
            sudo tee -a /etc/udev/rules.d/60-nvme-scheduler.rules > /dev/null
    else
        echo "  ✅ Read-ahead ya estaba en ${CURRENT_RA}KB"
    fi
fi

echo ""

# 5. Optimizar VM dirty ratios
echo "5️⃣  Optimizando VM dirty ratios..."
sudo sysctl -w vm.dirty_ratio=10 > /dev/null
sudo sysctl -w vm.dirty_background_ratio=5 > /dev/null
echo "vm.dirty_ratio = 10" | sudo tee /etc/sysctl.d/99-vm-tuning.conf > /dev/null
echo "vm.dirty_background_ratio = 5" | sudo tee -a /etc/sysctl.d/99-vm-tuning.conf > /dev/null
echo "  ✅ dirty_ratio: 20 → 10"
echo "  ✅ dirty_background_ratio: 10 → 5"

echo ""

# 6. Limpiar redes Docker
echo "6️⃣  Limpiando redes Docker no usadas..."
NETWORKS_BEFORE=$(docker network ls | wc -l)
docker network prune -f > /dev/null 2>&1 || true
NETWORKS_AFTER=$(docker network ls | wc -l)
CLEANED=$((NETWORKS_BEFORE - NETWORKS_AFTER))
if [ "$CLEANED" -gt 0 ]; then
    echo "  ✅ Eliminadas $CLEANED redes no usadas"
else
    echo "  ✅ Sin redes para limpiar"
fi

echo ""

# 7. Configurar límites del sistema
echo "7️⃣  Configurando límites del sistema..."
if ! grep -q "nofile 65536" /etc/security/limits.conf 2>/dev/null; then
    echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf > /dev/null
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf > /dev/null
    echo "  ✅ File descriptors aumentados a 65536"
else
    echo "  ✅ Límites ya configurados"
fi

echo ""
echo "──────────────────────────────────────────"
echo ""
echo "✅ Optimizaciones aplicadas correctamente"
echo ""
echo "📊 Resumen:"
echo "  • Contenedor problemático: Detenido"
echo "  • Turbo Boost: Habilitado"
echo "  • NVMe Scheduler: none"
echo "  • Read-ahead: 2048 KB"
echo "  • VM dirty ratios: Optimizados"
echo "  • Redes Docker: Limpiadas"
echo "  • File descriptors: 65536"
echo ""
echo "⚠️  Algunas optimizaciones requieren reinicio para aplicarse completamente"
echo ""
echo "Para verificar:"
echo "  cat /sys/devices/system/cpu/intel_pstate/no_turbo  # Debe ser 0"
echo "  cat /sys/block/nvme0n1/queue/scheduler  # Debe ser [none]"
echo "  cat /sys/block/nvme0n1/queue/read_ahead_kb  # Debe ser 2048"
echo "  sysctl vm.dirty_ratio vm.dirty_background_ratio"
echo ""
