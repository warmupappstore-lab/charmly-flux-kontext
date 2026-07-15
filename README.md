# Charmly — FLUX.1 Kontext [dev] RunPod Serverless worker

Reference-based image **editing** worker for the Charmly auto-poster. Takes the locked
`ref_hand.jpg` (open palm + neon "Charmly" scene) + an edit prompt and returns one
close-up charm photo. Runs **FLUX.1 Kontext [dev]** in ComfyUI on a RunPod Serverless
endpoint (24 GB GPU, e.g. RTX 4090 / L4). No IP filter (self-hosted).

## Job API
```json
// input
{ "prompt": "<edit instruction>", "image": "<base64 ref_hand>", "seed": 123, "steps": 28 }
// output
{ "image": "<base64 PNG>", "seed": 123 }
```

## Files
- `Dockerfile` — ComfyUI + torch(cu124) + runpod handler. Weights are **not** baked in.
- `handler.py` — RunPod serverless handler; patches the workflow by `class_type` (prompt, LoadImage, seed) and returns the output image.
- `workflow_api.json` — ComfyUI FLUX Kontext graph (UNETLoader→DualCLIP→VAE→LoadImage→FluxKontextImageScale→VAEEncode→ReferenceLatent→FluxGuidance→KSampler→SaveImage).
- `start.sh` — symlinks `/ComfyUI/models` → network volume, boots ComfyUI, then the handler.
- `download_models.sh` — one-time: pull the 4 weight files onto the network volume.

## Deploy
1. **Network Volume** — create one (~50 GB) in a RunPod datacenter that has 24 GB GPUs.
2. **Weights** — attach the volume to any pod and run:
   ```bash
   ./download_models.sh /runpod-volume        # ~20 GB: kontext fp8 + t5xxl fp8 + clip_l + ae
   ```
   Files land in `/runpod-volume/ComfyUI/models/{diffusion_models,text_encoders,vae}`.
3. **Endpoint** — RunPod → Serverless → New Endpoint → **build from this GitHub repo**
   (or push the image to a registry). Settings:
   - GPU: **24 GB** (RTX 4090 / L4)
   - Attach the **Network Volume** at mount path `/runpod-volume`
   - Workers: min **0** (scale to zero), max 1–2
   - **FlashBoot: Premium** (enabled by the account owner) — kills cold-start latency
   - Container disk ~20 GB, idle timeout ~15 s, exec timeout ~300 s
4. **Test**
   ```bash
   curl -s https://api.runpod.ai/v2/<ENDPOINT_ID>/runsync \
     -H "Authorization: Bearer $RUNPOD_API_KEY" -H "Content-Type: application/json" \
     -d "{\"input\":{\"prompt\":\"<edit prompt>\",\"image\":\"$(base64 -w0 ref_hand.jpg)\"}}"
   ```

## Notes
- Model filenames in `workflow_api.json` must match what `download_models.sh` put on the volume.
- Kontext is an **instruction-edit** model: prompts should say *what to keep* and *what to change* (the Charmly composer handles this).
- License: FLUX.1 Kontext **[dev]** is non-commercial; a BFL self-hosting commercial license is available for production/commercial use.
