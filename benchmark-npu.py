#!/usr/bin/env python3
"""Benchmark NPU vs CPU vs GPU para generación de texto"""
import openvino_genai as ov_genai
import time
from pathlib import Path

model_path = Path.home() / ".openclaw/workspace/tinyllama-npu"
prompt = "Once upon a time, in a land far away"

devices = ["CPU", "GPU", "NPU"]
results = {}

config = ov_genai.GenerationConfig()
config.max_new_tokens = 100
config.do_sample = False

for device in devices:
    print(f"\n{'='*60}")
    print(f"🎯 Dispositivo: {device}")
    print(f"{'='*60}")
    
    try:
        # Cargar modelo
        start_load = time.time()
        pipe = ov_genai.LLMPipeline(str(model_path), device)
        load_time = time.time() - start_load
        
        # Generar (con warmup)
        print("⏳ Warmup...")
        _ = pipe.generate("test", config)
        
        # Benchmark real
        print("⏱️  Midiendo rendimiento...")
        start = time.time()
        result = pipe.generate(prompt, config)
        gen_time = time.time() - start
        
        tokens = len(result.split())
        tokens_per_sec = tokens / gen_time
        
        results[device] = {
            "load_time": load_time,
            "gen_time": gen_time,
            "tokens": tokens,
            "tokens_per_sec": tokens_per_sec
        }
        
        print(f"\n📊 Resultados:")
        print(f"  ⏰ Tiempo de carga: {load_time:.2f}s")
        print(f"  ⚡ Tiempo de generación: {gen_time:.2f}s")
        print(f"  📝 Tokens generados: {tokens}")
        print(f"  🚀 Velocidad: {tokens_per_sec:.2f} tokens/s")
        print(f"\n🤖 Texto generado:")
        print(f"  {result[:200]}...")
        
    except Exception as e:
        print(f"❌ Error en {device}: {e}")
        results[device] = {"error": str(e)}

# Resumen
print(f"\n{'='*60}")
print(f"📊 RESUMEN COMPARATIVO")
print(f"{'='*60}\n")

for device, data in results.items():
    if "error" not in data:
        print(f"{device:6s}: {data['tokens_per_sec']:6.2f} tokens/s (gen: {data['gen_time']:.2f}s, load: {data['load_time']:.2f}s)")
    else:
        print(f"{device:6s}: ERROR - {data['error']}")

print()
