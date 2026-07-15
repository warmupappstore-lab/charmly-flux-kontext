# Charmly — FLUX.1 Kontext [dev] RunPod Serverless worker
# ComfyUI + runpod handler. Model weights are NOT baked into the image —
# they live on a RunPod Network Volume mounted at /runpod-volume (see README).
#
# NOTE: -devel (not -runtime) base + build-essential are REQUIRED: newer ComfyUI
# pulls in comfy_kitchen/Triton, which JIT-compiles CUDA kernels at import and
# needs a C compiler + CUDA headers (else "Failed to find C compiler").
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1 PYTHONUNBUFFERED=1 CC=gcc

# Use the distro's python3 (3.10) consistently — pip and python MUST be the same
# interpreter, otherwise deps install for one and scripts run under the other.
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-dev git wget curl build-essential libgl1 libglib2.0-0 \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# Torch stack (CUDA 12.4) — install torch+torchvision+torchaudio TOGETHER from the
# same cu124 index so their CUDA builds match. If torchaudio comes from the default
# PyPI it targets a different CUDA (libcudart.so.13) and ComfyUI crashes on import.
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# ComfyUI + its requirements (+ deps its newer asset DB needs, and our handler deps)
WORKDIR /
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
RUN python3 -m pip install -r /ComfyUI/requirements.txt
RUN python3 -m pip install runpod requests websocket-client sqlalchemy alembic

# Our handler + workflow + startup + one-time weight downloader
COPY handler.py /handler.py
COPY workflow_api.json /workflow_api.json
COPY download_models.sh /download_models.sh
COPY start.sh /start.sh
RUN chmod +x /start.sh /download_models.sh

# ComfyUI reads models from the network volume (symlinked at runtime by start.sh)
CMD ["/start.sh"]
