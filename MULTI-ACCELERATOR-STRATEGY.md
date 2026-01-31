# Sistema Multi-Acelerador Optimizado
# CPU + iGPU Intel ARL + NPU Intel AI Boost (3720)

## 🎯 Estrategia de Distribución de Carga

### 1. CPU (Ryzen/Intel - 24 cores)
**Mejor para:**
- LLMs pequeños (<3B parámetros)
- Procesamiento paralelo general
- Compilación, build, tareas de sistema

**Configuración:**
- Governor: performance
- Turbo boost: enabled
- SMT/HT: enabled

### 2. iGPU Intel ARL (Integrated Graphics)
**Mejor para:**
- LLMs medianos (3-7B parámetros) en Ollama
- Codificación de video (VAAPI/QSV)
- Tareas gráficas ligeras

**Configuración:**
- Driver: i915 (kernel)
- OpenCL: intel-compute-runtime
- Vulkan: mesa-vulkan-drivers
- Level Zero: instalado

### 3. NPU Intel AI Boost (3720 - Meteor Lake)
**Mejor para:**
- ❌ NO para LLMs (0.97 tokens/s - 42x más lento)
- ✅ Embeddings (sentence-transformers, CLIP)
- ✅ Clasificación de texto rápida
- ✅ Feature extraction
- ✅ Detección de objetos pequeños
- ✅ Tareas de inferencia edge con baja latencia

**Características:**
- TOPS: ~10-13 TOPS (INT8)
- Memoria: Compartida con sistema
- Consumo: ~5W (muy eficiente)
- Latencia: Baja para modelos pequeños

---

## 🚀 Stack Recomendado

### A. LLMs (Generación de texto)
```
Ollama → iGPU (Vulkan) o CPU
```
- **Actual:** Ollama en iGPU con Vulkan ✅
- **Modelos actuales:** llama3.2:3b, gemma:2b
- **NO cambiar** - funciona bien así

### B. Embeddings / RAG (Retrieval)
```
OpenVINO + NPU → Modelos de embeddings
```
- **Usar:** sentence-transformers convertidos a OpenVINO IR
- **Ejemplos:**
  - all-MiniLM-L6-v2 (embeddings rápidos)
  - multilingual-e5-small (multiidioma)
  - CLIP (imagen+texto)

### C. Clasificación / NLP Ligero
```
OpenVINO + NPU → BERT, DistilBERT, etc.
```
- Sentiment analysis
- Named Entity Recognition (NER)
- Intent classification
- Language detection

### D. Visión por Computadora
```
OpenVINO + NPU/iGPU → YOLOv8n, MobileNet, EfficientNet
```
- Detección de objetos
- Clasificación de imágenes
- Face detection

---

## 📦 Configuración Práctica

### 1. Crear servicios especializados por dispositivo
