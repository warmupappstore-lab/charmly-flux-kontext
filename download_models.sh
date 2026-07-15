#!/usr/bin/env bash
# Populate the RunPod Network Volume with FLUX.1 Kontext [dev] weights (fp8, non-gated).
# Idempotent: skips a file only if its size already matches the remote Content-Length,
# otherwise (re)downloads fully — so a partial file from a crashed boot is repaired.
# Run automatically by start.sh on boot, or manually: ./download_models.sh /runpod-volume
set -uo pipefail

VOL="${1:-/runpod-volume}"
BASE="$VOL/ComfyUI/models"
mkdir -p "$BASE/diffusion_models" "$BASE/text_encoders" "$BASE/vae"

dl() {  # dl <url> <dest>
  local url="$1" dest="$2"
  local remote local_sz
  remote=$(curl -sIL "$url" | tr -d '\r' | awk 'tolower($1)=="content-length:"{v=$2} END{print v}')
  local_sz=$([ -f "$dest" ] && stat -c%s "$dest" || echo 0)
  if [ -n "$remote" ] && [ "$local_sz" = "$remote" ]; then
    echo "[skip] $(basename "$dest") complete ($local_sz)"; return 0
  fi
  echo "[get ] $(basename "$dest")  local=$local_sz remote=${remote:-?}"
  curl -fL -o "$dest" "$url" || { echo "[FAIL] $url"; rm -f "$dest"; return 1; }
}

dl "https://huggingface.co/Comfy-Org/flux1-kontext-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors" \
   "$BASE/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors" || exit 1
dl "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" \
   "$BASE/text_encoders/t5xxl_fp8_e4m3fn.safetensors" || exit 1
dl "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
   "$BASE/text_encoders/clip_l.safetensors" || exit 1
dl "https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors" \
   "$BASE/vae/ae.safetensors" || exit 1

echo "[done] weights in $BASE"
du -sh "$BASE"/*/* 2>/dev/null || true
