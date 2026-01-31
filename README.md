# Intel NPU Driver + Multi-Accelerator Setup

Compilación, instalación y configuración del driver NPU Intel AI Boost para Linux + optimización de sistema multi-acelerador (CPU + iGPU + NPU).

## 📋 Resumen

Este repositorio documenta la compilación del driver NPU Intel para Linux y la configuración de un sistema con múltiples aceleradores optimizados.

### Hardware
- **CPU:** 16 cores
- **iGPU:** Intel ARL (Arrow Lake-P Integrated Graphics)
- **NPU:** Intel AI Boost 3720 (Meteor Lake - ~10 TOPS INT8)
- **RAM:** 92GB
- **Swap:** 32GB (optimizado con swappiness=10)

## 🎯 Resultados

### Benchmark LLM (TinyLlama 1.1B int8)

| Dispositivo | Tokens/s | Tiempo carga | Uso recomendado |
|------------|----------|--------------|-----------------|
| **CPU** | 40.86 | 0.52s | ✅ LLMs pequeños (<3B) |
| **iGPU** | 37.09 | 2.50s | ✅ LLMs medianos (3-7B) |
| **NPU** | 0.97 | 16.00s | ❌ NO para LLMs |

### Conclusión
- **NPU:** No práctico para LLMs (42x más lento que CPU)
- **NPU:** Limitado para embeddings genéricos (falla con dynamic shapes)
- **Recomendación:** CPU/iGPU para LLMs, NPU solo para modelos custom específicos

## 📦 Instalación del Driver NPU

### Requisitos previos
```bash
sudo apt update
sudo apt install -y build-essential cmake git pkg-config \
    libboost-all-dev libtbb-dev level-zero-dev \
    python3-dev python3-pip ninja-build
```

### Compilación

```bash
# Clonar repositorio
git clone https://github.com/intel/linux-npu-driver.git
cd linux-npu-driver

# Crear carpeta build
mkdir build && cd build

# Configurar
cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_TESTING=OFF \
    ..

# Compilar (tarda ~45 minutos)
ninja -j$(nproc)
```

### Problemas solucionados durante compilación

#### 1. Error `-Werror=maybe-uninitialized`
```cmake
# Editar: build/compiler/src/npu_compiler/cmake/compile_options.cmake
# Comentar la línea:
# add_compile_options(-Werror)
```

#### 2. GTest falta `#include <cstdint>` (GCC 15+)
```bash
# Parchear todos los archivos gtest-death-test.cc
find ~/linux-npu-driver/build/compiler/src -name "gtest-death-test.cc" \
    -type f -exec sed -i '49i #include <cstdint>' {} \;
```

#### 3. Librerías Level Zero faltantes
```bash
# Copiar libze_loader desde build interno
cp build/compiler/build_npu_compiler/lib/libze_loader.so.1.24.3 \
   build/lib/libze_loader.so.1.24.2

# Crear symlinks
cd build/lib
ln -sf libze_loader.so.1.24.2 libze_loader.so.1
ln -sf libze_loader.so.1 libze_loader.so

# Crear dummies para validation/tracing layers (no compiladas)
touch libze_validation_layer.so.1.24.2
touch libze_tracing_layer.so.1.24.2
ln -sf libze_validation_layer.so.1.24.2 libze_validation_layer.so.1
ln -sf libze_tracing_layer.so.1.24.2 libze_tracing_layer.so.1
```

### Instalación

```bash
# Instalar en /tmp primero (evita sudo al compilar)
make DESTDIR=/tmp/npu-install install

# Copiar al sistema
sudo cp -r /tmp/npu-install/lib/firmware/* /lib/firmware/
sudo cp /tmp/npu-install/usr/local/lib/*.so* /usr/local/lib/
sudo ldconfig
```

### Verificación

```bash
# Verificar módulo kernel
lsmod | grep intel_vpu

# Verificar dispositivo
ls -l /dev/accel/accel0

# Verificar con OpenVINO
python3 -c "from openvino import Core; print(Core().available_devices)"
# Output esperado: ['CPU', 'GPU', 'NPU']

# Test básico
cd build
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
./bin/ze_intel_npu_tests --gtest_filter="*createErrors"
```

## 🚀 OpenVINO GenAI (opcional, para pruebas)

```bash
# Crear entorno virtual
python3 -m venv openvino-genai-env
source openvino-genai-env/bin/activate

# Instalar
pip install openvino-genai optimum-intel[nncf,openvino] huggingface-hub

# Descargar modelo de prueba
python3 << EOF
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id="OpenVINO/TinyLlama-1.1B-Chat-v1.0-int8-ov",
    local_dir="./tinyllama-npu"
)
EOF
```

## ⚙️ Optimización del Sistema

### 1. Swap optimizado

```bash
# Desactivar swap actual
sudo swapoff /swap.img

# Crear swap de 32GB
sudo dd if=/dev/zero of=/swap.img bs=1M count=32768 status=progress
sudo chmod 600 /swap.img
sudo mkswap /swap.img
sudo swapon /swap.img

# Reducir swappiness
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl vm.swappiness=10

# Hacer permanente
echo "/swap.img none swap sw 0 0" | sudo tee -a /etc/fstab
```

### 2. CPU optimizado

```bash
# Governor a performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" | sudo tee $cpu
done

# Habilitar turbo boost (Intel)
echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
```

### 3. Verificar permisos GPU/NPU

```bash
# Añadir usuario al grupo render
sudo usermod -aG render $USER

# Verificar
groups | grep render
```

## 📊 Scripts incluidos

- **`setup-multi-accelerator.sh`** - Configura y optimiza el sistema completo
- **`optimize-swap.sh`** - Aumenta swap de 8GB a 32GB
- **`finish-swap.sh`** - Completa configuración de swap
- **`test-npu-llm.py`** - Prueba simple de generación en NPU
- **`benchmark-npu.py`** - Benchmark CPU vs GPU vs NPU
- **`npu-embeddings-service.py`** - Servicio de embeddings (falla con dynamic shapes)
- **`multi-accelerator-quickstart.sh`** - Guía rápida del sistema

## 📝 Configuración final recomendada

### Para LLMs (Ollama)
```yaml
Dispositivo: iGPU Intel ARL (Vulkan)
Modelos:
  - llama3.2:3b-instruct-q8_0
  - gemma:2b-instruct-q8_0
Rendimiento: ~37 tokens/s
```

### Para NPU
```
❌ NO recomendado para:
  - LLMs (42x más lento que CPU)
  - Embeddings genéricos (falla con dynamic shapes)

⚠️ Casos de uso limitados:
  - Modelos custom con shapes fijos
  - Edge computing específico
  - Mejor soporte en Windows
```

## 🔧 Archivos instalados

```
/lib/firmware/updates/intel/vpu/
├── vpu_37xx_v1.bin (2.4MB)
├── vpu_40xx_v1.bin (986KB)
└── vpu_50xx_v1.bin (965KB)

/usr/local/lib/
├── libze_intel_npu.so.1.28.0 (24MB)
├── libnpu_driver_compiler.so (119MB)
├── libze_loader.so.1.24.2
├── libze_validation_layer.so.1.24.2 (dummy)
└── libze_tracing_layer.so.1.24.2 (dummy)

/dev/accel/accel0 (NPU device)
```

## 📚 Referencias

- [Intel NPU Driver GitHub](https://github.com/intel/linux-npu-driver)
- [OpenVINO](https://docs.openvino.ai/)
- [Intel AI Boost Documentation](https://www.intel.com/content/www/us/en/products/docs/processors/core-ultra/ai-pc.html)

## ⚖️ Licencia

Este repositorio contiene documentación y scripts. El driver NPU Intel está bajo licencia MIT.

## 🙏 Créditos

- Driver NPU: Intel Corporation
- Compilación y optimización: Documentado en 2026-01-31
- Sistema: Arch Linux con kernel 6.17.0-8-generic
