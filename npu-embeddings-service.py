#!/usr/bin/env python3
"""
Servicio de Embeddings optimizado para NPU Intel AI Boost
Usa modelos pequeños de sentence-transformers convertidos a OpenVINO
"""

import openvino as ov
from pathlib import Path
import numpy as np
from typing import List
import time

class NPUEmbeddings:
    """Cliente de embeddings usando NPU Intel AI Boost"""
    
    def __init__(self, model_name: str = "all-MiniLM-L6-v2", device: str = "NPU"):
        """
        Inicializa el servicio de embeddings en NPU
        
        Args:
            model_name: Nombre del modelo (se descargará si no existe)
            device: CPU, GPU, o NPU
        """
        self.device = device
        self.model_name = model_name
        self.model_path = Path.home() / ".openclaw/workspace/models" / f"{model_name}-ov"
        
        print(f"🧠 Inicializando NPU Embeddings...")
        print(f"   Modelo: {model_name}")
        print(f"   Dispositivo: {device}")
        
        # Crear carpeta de modelos
        self.model_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Descargar/convertir modelo si no existe
        if not self.model_path.exists():
            print(f"📥 Descargando y convirtiendo modelo...")
            self._download_and_convert()
        
        # Cargar modelo en NPU
        print(f"⚡ Cargando modelo en {device}...")
        start = time.time()
        core = ov.Core()
        model = core.read_model(self.model_path / "openvino_model.xml")
        self.compiled_model = core.compile_model(model, device)
        load_time = time.time() - start
        print(f"   ✅ Cargado en {load_time:.2f}s")
        
    def _download_and_convert(self):
        """Descarga y convierte modelo de HuggingFace a OpenVINO IR"""
        from optimum.intel import OVModelForFeatureExtraction
        from transformers import AutoTokenizer
        
        print("   📦 Descargando de HuggingFace...")
        tokenizer = AutoTokenizer.from_pretrained(f"sentence-transformers/{self.model_name}")
        
        print("   🔄 Convirtiendo a OpenVINO IR...")
        model = OVModelForFeatureExtraction.from_pretrained(
            f"sentence-transformers/{self.model_name}",
            export=True,
            compile=False
        )
        
        # Guardar
        model.save_pretrained(self.model_path)
        tokenizer.save_pretrained(self.model_path)
        print(f"   ✅ Modelo guardado en {self.model_path}")
    
    def embed(self, texts: List[str]) -> np.ndarray:
        """
        Genera embeddings para una lista de textos
        
        Args:
            texts: Lista de textos
            
        Returns:
            Array de embeddings (shape: [len(texts), embedding_dim])
        """
        from transformers import AutoTokenizer
        
        # Cargar tokenizer
        tokenizer = AutoTokenizer.from_pretrained(self.model_path)
        
        # Tokenizar
        inputs = tokenizer(
            texts,
            padding=True,
            truncation=True,
            max_length=512,
            return_tensors="np"
        )
        
        # Inferencia en NPU
        start = time.time()
        outputs = self.compiled_model(inputs)
        inference_time = time.time() - start
        
        # Extraer embeddings (mean pooling)
        embeddings = outputs[self.compiled_model.output(0)]
        
        # Mean pooling
        attention_mask = inputs['attention_mask']
        mask_expanded = np.expand_dims(attention_mask, -1)
        sum_embeddings = np.sum(embeddings * mask_expanded, axis=1)
        sum_mask = np.clip(np.sum(mask_expanded, axis=1), a_min=1e-9, a_max=None)
        embeddings = sum_embeddings / sum_mask
        
        print(f"⚡ Inferencia: {inference_time*1000:.1f}ms para {len(texts)} textos")
        print(f"   ({len(texts)/inference_time:.1f} textos/s)")
        
        return embeddings
    
    def similarity(self, text1: str, text2: str) -> float:
        """Calcula similitud coseno entre dos textos"""
        emb1, emb2 = self.embed([text1, text2])
        
        # Cosine similarity
        dot = np.dot(emb1, emb2)
        norm1 = np.linalg.norm(emb1)
        norm2 = np.linalg.norm(emb2)
        
        return float(dot / (norm1 * norm2))


def demo():
    """Demo del servicio de embeddings en NPU"""
    print("=" * 60)
    print("🧠 Demo: Embeddings en NPU Intel AI Boost")
    print("=" * 60)
    print()
    
    # Inicializar servicio (esto tarda en la primera ejecución)
    embedder = NPUEmbeddings(device="NPU")
    
    print()
    print("📝 Generando embeddings para 5 textos...")
    texts = [
        "El gato está en el tejado",
        "The cat is on the roof",
        "Python es un lenguaje de programación",
        "El perro corre por el parque",
        "Machine learning es fascinante"
    ]
    
    embeddings = embedder.embed(texts)
    print(f"✅ Embeddings shape: {embeddings.shape}")
    
    print()
    print("🔍 Similitudes:")
    pairs = [
        (0, 1),  # Español-Inglés (misma frase)
        (0, 3),  # Gato vs Perro
        (2, 4),  # Python vs ML
    ]
    
    for i, j in pairs:
        sim = embedder.similarity(texts[i], texts[j])
        print(f"  '{texts[i][:40]}...'")
        print(f"  '{texts[j][:40]}...'")
        print(f"  → Similitud: {sim:.3f}")
        print()


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "demo":
        demo()
    else:
        print("Uso:")
        print("  python npu-embeddings-service.py demo")
        print()
        print("O importa la clase NPUEmbeddings en tu código:")
        print()
        print("  from npu_embeddings_service import NPUEmbeddings")
        print("  embedder = NPUEmbeddings(device='NPU')")
        print("  emb = embedder.embed(['texto 1', 'texto 2'])")
