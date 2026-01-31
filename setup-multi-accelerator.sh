#!/bin/bash
# Sistema de optimización multi-acelerador
# CPU + iGPU + NPU Intel AI Boost

set -e

echo "🚀 Configuración de Sistema Multi-Acelerador"
echo "=============================================="
echo ""
echo "Hardware detectado:"
echo "  CPU: $(nproc) cores"
echo "  iGPU: Intel ARL ($(lspci | grep VGA | grep Intel))"
echo "  NPU: Intel AI Boost 3720"
echo ""

# 1. Optimizar CPU
echo "⚙️  Optimizando CPU..."

# CPU governor a performance
if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" | sudo tee $cpu > /dev/null 2>&1 || true
    done
    echo "  ✅ CPU governor → performance"
else
    echo "  ⚠️  CPUfreq no disponible"
fi

# Habilitar turbo boost (Intel)
if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
    echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
    echo "  ✅ Intel Turbo Boost habilitado"
fi

# 2. Verificar iGPU
echo ""
echo "🎮 Verificando iGPU..."
if [ -e /dev/dri/renderD128 ]; then
    echo "  ✅ iGPU disponible: /dev/dri/renderD128"
    groups | grep -q render && echo "  ✅ Usuario en grupo 'render'" || echo "  ⚠️  Usuario NO en grupo 'render'"
else
    echo "  ❌ iGPU no detectada"
fi

# 3. Verificar NPU
echo ""
echo "🧠 Verificando NPU Intel AI Boost..."
if [ -e /dev/accel/accel0 ]; then
    echo "  ✅ NPU disponible: /dev/accel/accel0"
    lsmod | grep -q intel_vpu && echo "  ✅ Módulo intel_vpu cargado" || echo "  ⚠️  Módulo intel_vpu NO cargado"
    groups | grep -q render && echo "  ✅ Usuario en grupo 'render'" || echo "  ⚠️  Usuario NO en grupo 'render'"
else
    echo "  ❌ NPU no detectada"
fi

# 4. OpenVINO runtime check
echo ""
echo "📦 Verificando OpenVINO..."
if python3 -c "import openvino" 2>/dev/null; then
    echo "  ✅ OpenVINO instalado (sistema)"
fi

if [ -d ~/.openclaw/workspace/openvino-genai-env ]; then
    echo "  ✅ OpenVINO GenAI venv disponible"
fi

# 5. Ollama status
echo ""
echo "🦙 Verificando Ollama..."
if docker ps | grep -q ollama; then
    echo "  ✅ Ollama corriendo en Docker"
    docker logs ollama-intel-arc 2>&1 | grep -i "gpu\|vulkan" | tail -2 || true
else
    echo "  ⚠️  Ollama no está corriendo"
fi

# 6. Configurar límites del sistema
echo ""
echo "⚙️  Configurando límites del sistema..."

# Aumentar límites de memoria compartida para iGPU/NPU
if [ "$(cat /proc/sys/kernel/shmmax)" -lt 17179869184 ]; then
    echo 17179869184 | sudo tee /proc/sys/kernel/shmmax > /dev/null
    echo "kernel.shmmax = 17179869184" | sudo tee -a /etc/sysctl.d/99-shared-memory.conf
    echo "  ✅ Shared memory aumentada a 16GB"
fi

# 7. Resumen de configuración
echo ""
echo "=============================================="
echo "✅ Configuración completada"
echo "=============================================="
echo ""
echo "📊 Distribución de carga recomendada:"
echo ""
echo "  🦙 LLMs (Ollama):"
echo "    • Modelos pequeños (<3B): CPU"
echo "    • Modelos medianos (3-7B): iGPU (actual)"
echo ""
echo "  🧠 NPU Intel AI Boost:"
echo "    • Embeddings (sentence-transformers)"
echo "    • Clasificación de texto"
echo "    • Feature extraction"
echo "    • NO usar para LLMs (42x más lento)"
echo ""
echo "  💻 CPU:"
echo "    • Procesamiento general"
echo "    • LLMs pequeños con ollama"
echo "    • Compilación y build"
echo ""
echo "  🎮 iGPU:"
echo "    • Ollama (Vulkan)"
echo "    • Codificación de video (VAAPI)"
echo "    • Visión por computadora (OpenVINO)"
echo ""

# 8. Crear alias útiles
echo "📝 Creando aliases útiles..."
cat > ~/.openclaw/workspace/accelerator-aliases.sh << 'ALIASES'
# Aliases para sistema multi-acelerador

# OpenVINO + NPU
alias ov-npu="source ~/.openclaw/workspace/openvino-genai-env/bin/activate"
alias npu-test="ov-npu && python ~/.openclaw/workspace/test-npu-llm.py"
alias npu-bench="ov-npu && python ~/.openclaw/workspace/benchmark-npu.py"

# Ollama
alias ollama-cpu="docker exec -it ollama-intel-arc ollama run"
alias ollama-status="docker logs ollama-intel-arc 2>&1 | grep -E 'gpu|device|vulkan' | tail -5"

# Monitoreo
alias gpu-mon="intel_gpu_top"
alias npu-mon="watch -n 1 'cat /sys/class/accel/accel0/device/npu_busy_time_us'"
alias cpu-mon="htop"
ALIASES

echo "  ✅ Aliases creados en ~/.openclaw/workspace/accelerator-aliases.sh"
echo "     Añade a tu .bashrc: source ~/.openclaw/workspace/accelerator-aliases.sh"
echo ""
