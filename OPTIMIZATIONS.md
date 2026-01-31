# 🔧 Optimizaciones Recomendadas del Sistema

Basado en auditoría del sistema realizada el 2026-01-31

## ⚠️ Problemas críticos detectados

### 1. **Contenedor reev-annonars crasheando constantemente**
- **Estado:** 547 reinicios
- **Error:** "Column family not found: genes"
- **Impacto:** Consume recursos innecesariamente

**Solución:**
```bash
# Detener el contenedor problemático
docker stop reev-annonars
docker update --restart=no reev-annonars

# O eliminarlo si no es crítico
docker rm -f reev-annonars
```

---

## 🚀 Optimizaciones de alto impacto

### 2. **Turbo Boost deshabilitado** ⚠️
- **Estado actual:** Deshabilitado (0)
- **Impacto:** -20-30% rendimiento CPU

**Solución:**
```bash
# Habilitar Turbo Boost
echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo

# Hacer permanente
echo "# Habilitar Intel Turbo Boost" | sudo tee -a /etc/sysctl.d/99-cpu-performance.conf
echo "intel_pstate.no_turbo=0" | sudo tee -a /etc/default/grub.d/cpu-performance.cfg
```

### 3. **Scheduler de disco no optimizado para NVMe**
- **Estado actual:** `mq-deadline` 
- **Recomendado:** `none` para NVMe (mejor rendimiento)

**Solución:**
```bash
# Cambiar a 'none' para NVMe
echo none | sudo tee /sys/block/nvme0n1/queue/scheduler

# Hacer permanente
echo 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"' | \
    sudo tee /etc/udev/rules.d/60-nvme-scheduler.rules
```

### 4. **Read-ahead bajo para NVMe**
- **Estado actual:** 128 KB
- **Recomendado:** 1024-2048 KB para cargas secuenciales

**Solución:**
```bash
# Aumentar read-ahead
echo 2048 | sudo tee /sys/block/nvme0n1/queue/read_ahead_kb

# Hacer permanente (añadir a udev rule anterior)
echo 'ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/read_ahead_kb}="2048"' | \
    sudo tee -a /etc/udev/rules.d/60-nvme-scheduler.rules
```

---

## 🧹 Limpieza del sistema

### 5. **Demasiadas redes Docker (19)**
- **Problema:** Redes Docker no usadas ocupan espacio

**Solución:**
```bash
# Limpiar redes no usadas
docker network prune -f

# Ver redes activas
docker network ls
```

### 6. **Snaps ocupando loops (22 snaps)**
- **Problema:** Cada snap crea un loop device

**Revisar:**
```bash
# Listar snaps
snap list

# Eliminar snaps no usados
sudo snap remove <nombre-snap>

# Considerar deshabilitar snapd si no lo usas
sudo systemctl disable --now snapd
```

---

## ⚡ Optimizaciones de rendimiento

### 7. **ZRAM no configurado**
- **Beneficio:** Compresión en RAM = menos swap I/O

**Solución:**
```bash
# Instalar zram-tools
sudo apt install zram-tools

# Configurar
echo "ALGO=lz4" | sudo tee -a /etc/default/zramswap
echo "PERCENT=25" | sudo tee -a /etc/default/zramswap

# Habilitar
sudo systemctl enable --now zramswap
```

### 8. **Transparent Huge Pages en madvise**
- **Estado:** `[madvise]` (bueno)
- **Recomendación:** Mantener así (o `always` para bases de datos)

**Para bases de datos:**
```bash
# Cambiar a 'always' si usas muchas DBs
echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

### 9. **VM dirty ratios optimizables**
- **Actual:** dirty_ratio=20, dirty_background_ratio=10
- **Recomendado:** Para SSD/NVMe reducir para mejor latencia

**Solución:**
```bash
# Optimizar para NVMe
sudo sysctl vm.dirty_ratio=10
sudo sysctl vm.dirty_background_ratio=5

# Hacer permanente
echo "vm.dirty_ratio = 10" | sudo tee -a /etc/sysctl.d/99-vm-tuning.conf
echo "vm.dirty_background_ratio = 5" | sudo tee -a /etc/sysctl.d/99-vm-tuning.conf
```

---

## 🔧 Optimizaciones menores

### 10. **apt-daily-upgrade tardando 21 minutos**
```bash
# Deshabilitar actualizaciones automáticas si no las necesitas
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable apt-daily.timer
```

### 11. **Límites del sistema**
```bash
# Verificar límites actuales
ulimit -a

# Aumentar file descriptors si usas muchos contenedores
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
```

---

## 📊 Prioridad de optimizaciones

| # | Optimización | Impacto | Esfuerzo | Prioridad |
|---|-------------|---------|----------|-----------|
| 1 | Detener reev-annonars | Alto | Bajo | 🔴 Crítico |
| 2 | Habilitar Turbo Boost | Alto | Bajo | 🔴 Alto |
| 3 | NVMe scheduler → none | Medio | Bajo | 🟡 Medio |
| 4 | Read-ahead aumentado | Medio | Bajo | 🟡 Medio |
| 5 | Limpiar redes Docker | Bajo | Bajo | 🟢 Bajo |
| 6 | VM dirty ratios | Medio | Bajo | 🟡 Medio |
| 7 | ZRAM | Medio | Medio | 🟡 Opcional |
| 8 | Limpiar snaps | Bajo | Medio | 🟢 Opcional |

---

## 🎯 Script de aplicación rápida

Ver: `apply-system-optimizations.sh`

---

## ✅ Estado actual del sistema

**Puntos fuertes:**
- ✅ CPU Governor: performance
- ✅ Swap: 32GB optimizado (swappiness=10)
- ✅ RAM: 92GB con 62GB disponibles
- ✅ GPU/NPU: Correctamente detectados
- ✅ Docker: Funcionando correctamente

**Puntos a mejorar:**
- ⚠️ Turbo Boost deshabilitado
- ⚠️ NVMe scheduler no optimizado
- ⚠️ Contenedor crasheando constantemente
- ℹ️ Read-ahead bajo para NVMe
- ℹ️ VM dirty ratios mejorables
