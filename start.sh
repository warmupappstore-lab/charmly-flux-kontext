#!/usr/bin/env bash
# Launch ComfyUI (background) + the RunPod serverless handler.
set -e

VOL=/runpod-volume                     # RunPod network volume mount
MODELS="$VOL/ComfyUI/models"           # weights live here (see download_models.sh)

# One-time: populate the network volume with weights if missing (persists on volume)
KONTEXT="$MODELS/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors"
if [ ! -s "$KONTEXT" ]; then
  echo "[start] weights not found on volume — downloading once (~17GB, first boot only)..."
  bash /download_models.sh "$VOL"
fi

# Point ComfyUI at the network-volume models dir (weights are large, not baked)
if [ -d "$MODELS" ]; then
  rm -rf /ComfyUI/models
  ln -s "$MODELS" /ComfyUI/models
  echo "[start] linked /ComfyUI/models -> $MODELS"
else
  echo "[start] WARNING: $MODELS not found — is the network volume attached at $VOL ?"
fi

# Start ComfyUI on 127.0.0.1:8188, no browser, CPU-safe VAE off
python /ComfyUI/main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch &
COMFY_PID=$!

# Wait for ComfyUI to answer
echo "[start] waiting for ComfyUI..."
for i in $(seq 1 120); do
  if curl -sf http://127.0.0.1:8188/system_stats >/dev/null 2>&1; then
    echo "[start] ComfyUI up"; break
  fi
  sleep 1
done

# Hand over to the serverless handler (keeps ComfyUI as a child)
python -u /handler.py
