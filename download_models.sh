#!/usr/bin/env bash
# Populate the RunPod Network Volume with FLUX.1 Kontext [dev] weights (fp8, non-gated).
# Run ONCE on any pod that has the network volume attached, e.g.:
#   HF_TOKEN=hf_xxx ./download_models.sh /runpod-volume
# HF_TOKEN is optional (only needed if a URL 401s and you fall back to gated repos).
set -euo pipefail

VOL="${1:-/runpod-volume}"
BASE="$VOL/ComfyUI/models"
mkdir -p "$BASE/diffusion_models" "$BASE/text_encoders" "$BASE/vae"

HF="https://huggingface.co/Comfy-Org/flux1-kontext-dev_ComfyUI/resolve/main/split_files"

dl() {  # dl <url> <dest>
  local url="$1" dest="$2"
  if [ -s "$dest" ]; then echo "[skip] $dest exists"; return; fi
  echo "[get ] $dest"
  if [ -n "${HF_TOKEN:-}" ]; then
    wget -c --header="Authorization: Bearer ${HF_TOKEN}" -O "$dest" "$url"
  else
    wget -c -O "$dest" "$url"
  fi
}

dl "$HF/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors" "$BASE/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors"
dl "$HF/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors"          "$BASE/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors"
dl "$HF/text_encoders/clip_l.safetensors"                           "$BASE/text_encoders/clip_l.safetensors"
dl "$HF/vae/ae.safetensors"                                         "$BASE/vae/ae.safetensors"

echo "[done] weights in $BASE"
du -sh "$BASE"/*/* 2>/dev/null || true
