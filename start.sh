#!/usr/bin/env bash
# Launch ComfyUI (background) + the RunPod serverless handler.
set -e

VOL=/runpod-volume                     # RunPod network volume mount
MODELS="$VOL/ComfyUI/models"           # weights live here (see download_models.sh)

# Ensure weights are on the network volume (idempotent: skips complete files by size,
# repairs partials, downloads missing). Fast no-op once the volume is populated.
echo "[start] verifying weights on volume..."
bash /download_models.sh "$VOL" || { echo "[start] weight download failed"; exit 1; }

# Point ComfyUI at the network-volume models dir (weights are large, not baked)
if [ -d "$MODELS" ]; then
  rm -rf /ComfyUI/models
  ln -s "$MODELS" /ComfyUI/models
  echo "[start] linked /ComfyUI/models -> $MODELS"
else
  echo "[start] WARNING: $MODELS not found — is the network volume attached at $VOL ?"
fi

# Start ComfyUI on 127.0.0.1:8188 — capture its output so the handler can surface
# any startup crash in the job result (self-diagnosis, no console needed).
python /ComfyUI/main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch \
  > /comfyui.log 2>&1 &
COMFY_PID=$!

# Wait for ComfyUI to answer (up to 300s: first load of the 12GB fp8 model is slow)
echo "[start] waiting for ComfyUI..."
for i in $(seq 1 300); do
  if curl -sf http://127.0.0.1:8188/system_stats >/dev/null 2>&1; then
    echo "[start] ComfyUI up"; break
  fi
  if ! kill -0 "$COMFY_PID" 2>/dev/null; then
    echo "[start] ComfyUI process DIED — last log lines:"; tail -n 40 /comfyui.log
    break   # start the handler anyway so the error is returned via the job
  fi
  sleep 1
done

# Hand over to the serverless handler (keeps ComfyUI as a child)
python -u /handler.py
