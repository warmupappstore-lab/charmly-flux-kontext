#!/usr/bin/env python3
"""RunPod serverless handler for Charmly FLUX.1 Kontext [dev] via ComfyUI.

Job input:
  {
    "prompt": "<edit instruction / positive prompt>",   # required
    "image":  "<base64 PNG/JPG of the reference (ref_hand)>",  # required (or image_url)
    "image_url": "https://...",                          # optional alt to image
    "seed":  123456,                                     # optional (random if omitted)
    "steps": 28                                          # optional
  }

Returns: { "image": "<base64 PNG>", "seed": <seed> }
"""
import base64, io, json, os, random, time, uuid
import requests

COMFY = "http://127.0.0.1:8188"
IN_DIR = "/ComfyUI/input"
OUT_DIR = "/ComfyUI/output"
WORKFLOW = "/workflow_api.json"

import runpod


def _load_workflow():
    with open(WORKFLOW) as f:
        return json.load(f)


def _save_input_image(job_input):
    os.makedirs(IN_DIR, exist_ok=True)
    name = f"ref_{uuid.uuid4().hex}.png"
    path = os.path.join(IN_DIR, name)
    if job_input.get("image"):
        raw = base64.b64decode(job_input["image"])
    elif job_input.get("image_url"):
        raw = requests.get(job_input["image_url"], timeout=60).content
    else:
        raise ValueError("job input needs 'image' (base64) or 'image_url'")
    with open(path, "wb") as f:
        f.write(raw)
    return name


def _patch(wf, prompt, image_name, seed, steps):
    """Patch the workflow by class_type so it survives node-id changes."""
    for node in wf.values():
        ct = node.get("class_type")
        ins = node.setdefault("inputs", {})
        if ct == "LoadImage":
            ins["image"] = image_name
        elif ct == "CLIPTextEncode":
            # single positive encode in the Kontext workflow
            ins["text"] = prompt
        elif ct == "KSampler":
            ins["seed"] = seed
            if steps:
                ins["steps"] = steps
        elif ct == "RandomNoise":            # some flux workflows use RandomNoise
            ins["noise_seed"] = seed
    return wf


def _queue(wf, client_id):
    r = requests.post(f"{COMFY}/prompt", json={"prompt": wf, "client_id": client_id}, timeout=60)
    r.raise_for_status()
    return r.json()["prompt_id"]


def _wait(prompt_id, timeout=300):
    t0 = time.time()
    while time.time() - t0 < timeout:
        h = requests.get(f"{COMFY}/history/{prompt_id}", timeout=30).json()
        if prompt_id in h:
            return h[prompt_id]
        time.sleep(1)
    raise TimeoutError("ComfyUI generation timed out")


def _collect_image(hist):
    outs = hist.get("outputs", {})
    for node_out in outs.values():
        for img in node_out.get("images", []):
            fn = img["filename"]
            sub = img.get("subfolder", "")
            path = os.path.join(OUT_DIR, sub, fn)
            with open(path, "rb") as f:
                return base64.b64encode(f.read()).decode()
    raise RuntimeError("no image in ComfyUI output")


def handler(job):
    ji = job.get("input", {}) or {}
    prompt = ji.get("prompt")
    if not prompt:
        return {"error": "missing 'prompt'"}
    try:
        seed = int(ji.get("seed") or random.randint(1, 2**31 - 1))
        steps = ji.get("steps")
        image_name = _save_input_image(ji)
        wf = _patch(_load_workflow(), prompt, image_name, seed, steps)
        cid = uuid.uuid4().hex
        pid = _queue(wf, cid)
        hist = _wait(pid)
        img_b64 = _collect_image(hist)
        return {"image": img_b64, "seed": seed}
    except Exception as e:  # noqa: BLE001
        return {"error": f"{type(e).__name__}: {e}"}


runpod.serverless.start({"handler": handler})
