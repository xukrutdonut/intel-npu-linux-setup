#!/usr/bin/env python3
"""
Test OpenVINO GenAI en NPU Intel
"""
import openvino_genai as ov_genai
from pathlib import Path

def test_npu_generation(model_path: str, prompt: str, device: str = "NPU"):
    """
    Ejecuta generación de texto en el dispositivo especificado
    
    Args:
        model_path: Ruta al modelo exportado en formato OpenVINO IR
        prompt: Texto de entrada
        device: CPU, GPU, o NPU
    """
    print(f"🔧 Cargando modelo desde: {model_path}")
    print(f"🎯 Dispositivo: {device}")
    
    try:
        # Crear pipeline de generación
        pipe = ov_genai.LLMPipeline(model_path, device)
        
        print(f"\n💬 Prompt: {prompt}\n")
        print("🤖 Respuesta:")
        
        # Generar texto
        config = ov_genai.GenerationConfig()
        config.max_new_tokens = 50
        config.do_sample = False  # Greedy decoding para mayor velocidad
        
        result = pipe.generate(prompt, config)
        print(result)
        
        print("\n✅ Generación completada")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Uso: python test-npu-llm.py <model_path> [prompt] [device]")
        print("\nEjemplo:")
        print("  python test-npu-llm.py ./tinyllama-openvino 'Hello, I am' NPU")
        sys.exit(1)
    
    model_path = sys.argv[1]
    prompt = sys.argv[2] if len(sys.argv) > 2 else "Once upon a time"
    device = sys.argv[3] if len(sys.argv) > 3 else "NPU"
    
    test_npu_generation(model_path, prompt, device)
