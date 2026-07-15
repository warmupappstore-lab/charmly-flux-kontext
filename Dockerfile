# Charmly — FLUX.1 Kontext [dev] RunPod Serverless worker
# ComfyUI + runpod handler. Model weights are NOT baked into the image —
# they live on a RunPod Network Volume mounted at /runpod-volume (see README).
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1 PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3.11 python3.11-venv python3-pip git wget libgl1 libglib2.0-0 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# Torch (CUDA 12.4) first so it is cached independently of ComfyUI
RUN pip install --upgrade pip && \
    pip install torch torchvision --index-url https://download.pytorch.org/whl/cu124

# ComfyUI
WORKDIR /
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /ComfyUI
RUN pip install -r /ComfyUI/requirements.txt
RUN pip install runpod requests websocket-client

# Our handler + workflow + startup
COPY handler.py /handler.py
COPY workflow_api.json /workflow_api.json
COPY start.sh /start.sh
RUN chmod +x /start.sh

# ComfyUI reads models from the network volume (symlinked at runtime by start.sh)
CMD ["/start.sh"]
