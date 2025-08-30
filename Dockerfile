# Basis-Image von Runpod mit CUDA und Python
FROM runpod/pytorch:2.2.1-py3.10-cuda12.1.1-devel-ubuntu22.04

# Arbeitsverzeichnis setzen
WORKDIR /

# System-Updates und grundlegende Abhängigkeiten
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    vim \
    nano \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libgthread-2.0-0 \
    libgtk2.0-0 \
    ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Python-Abhängigkeiten installieren
RUN pip install --upgrade pip setuptools wheel

# WICHTIG: ComfyUI wird NICHT im Image installiert, sondern beim Start!
# Das stellt sicher, dass alles im persistenten /workspace liegt

# Alle Python-Dependencies vorinstallieren für schnelleren Start
RUN pip install \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
    opencv-python \
    opencv-contrib-python \
    numpy \
    pillow \
    scipy \
    scikit-image \
    matplotlib \
    pandas \
    transformers \
    diffusers \
    accelerate \
    xformers \
    einops \
    omegaconf \
    safetensors \
    aiohttp \
    pyyaml \
    tqdm \
    psutil \
    kornia \
    rembg[gpu] \
    segment-anything \
    groundingdino-py \
    GitPython \
    google-translate-py \
    langdetect \
    imageio \
    imageio-ffmpeg \
    networkx \
    numexpr \
    onnxruntime-gpu \
    pycocotools \
    requests \
    rich \
    sympy \
    typing-extensions \
    websocket-client \
    timm \
    addict \
    yapf \
    color-matcher \
    facexlib \
    tb-nightly \
    yapf \
    lpips \
    pytorch_lightning

# CLIP und andere ML-Dependencies
RUN pip install \
    git+https://github.com/openai/CLIP.git \
    fairscale \
    ftfy \
    regex \
    huggingface-hub

# Startup-Skript erstellen
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "========================================"\n\
echo "ComfyUI Runpod Startup Script v2.0"\n\
echo "========================================"\n\
\n\
# Farben für Output\n\
RED="\\033[0;31m"\n\
GREEN="\\033[0;32m"\n\
YELLOW="\\033[1;33m"\n\
NC="\\033[0m"\n\
\n\
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }\n\
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }\n\
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }\n\
\n\
# GPU Info\n\
log_info "GPU: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || echo \"N/A\")"\n\
\n\
# WICHTIG: Alles in /workspace installieren für Persistenz!\n\
cd /workspace\n\
\n\
# ComfyUI installieren oder updaten\n\
if [ ! -d "/workspace/ComfyUI" ]; then\n\
    log_info "Installiere ComfyUI zum ersten Mal..."\n\
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI\n\
    cd /workspace/ComfyUI\n\
    pip install -r requirements.txt\n\
    log_info "ComfyUI installiert!"\n\
else\n\
    log_info "ComfyUI bereits vorhanden"\n\
    cd /workspace/ComfyUI\n\
    # Optional: Updates\n\
    if [ "${AUTO_UPDATE:-false}" = "true" ]; then\n\
        log_info "Prüfe auf Updates..."\n\
        git pull || log_warn "Update fehlgeschlagen"\n\
        pip install -r requirements.txt --upgrade --quiet\n\
    fi\n\
fi\n\
\n\
# Verzeichnisse erstellen\n\
mkdir -p /workspace/ComfyUI/models/checkpoints \\\n\
         /workspace/ComfyUI/models/vae \\\n\
         /workspace/ComfyUI/models/loras \\\n\
         /workspace/ComfyUI/models/embeddings \\\n\
         /workspace/ComfyUI/models/controlnet \\\n\
         /workspace/ComfyUI/models/clip \\\n\
         /workspace/ComfyUI/models/clip_vision \\\n\
         /workspace/ComfyUI/models/upscale_models \\\n\
         /workspace/ComfyUI/models/ipadapter \\\n\
         /workspace/ComfyUI/models/instantid \\\n\
         /workspace/ComfyUI/input \\\n\
         /workspace/ComfyUI/output \\\n\
         /workspace/ComfyUI/temp \\\n\
         /workspace/ComfyUI/custom_nodes\n\
\n\
# ComfyUI Manager installieren (wenn nicht vorhanden)\n\
if [ ! -d "/workspace/ComfyUI/custom_nodes/ComfyUI-Manager" ]; then\n\
    log_info "Installiere ComfyUI Manager..."\n\
    cd /workspace/ComfyUI/custom_nodes\n\
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git\n\
    cd ComfyUI-Manager\n\
    pip install -r requirements.txt || true\n\
fi\n\
\n\
# Impact Pack installieren (wenn nicht vorhanden)\n\
if [ ! -d "/workspace/ComfyUI/custom_nodes/ComfyUI-Impact-Pack" ]; then\n\
    log_info "Installiere Impact Pack..."\n\
    cd /workspace/ComfyUI/custom_nodes\n\
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git\n\
    cd ComfyUI-Impact-Pack\n\
    git submodule update --init --recursive\n\
    python install.py || true\n\
    pip install -r requirements.txt || true\n\
fi\n\
\n\
# Weitere wichtige Custom Nodes (optional)\n\
declare -A custom_nodes=(\n\
    ["ComfyUI-AnimateDiff-Evolved"]="https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git"\n\
    ["ComfyUI_IPAdapter_plus"]="https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"\n\
    ["comfyui_controlnet_aux"]="https://github.com/Fannovel16/comfyui_controlnet_aux.git"\n\
    ["was-node-suite-comfyui"]="https://github.com/WASasquatch/was-node-suite-comfyui.git"\n\
    ["rgthree-comfy"]="https://github.com/rgthree/rgthree-comfy.git"\n\
)\n\
\n\
cd /workspace/ComfyUI/custom_nodes\n\
for node_name in "${!custom_nodes[@]}"; do\n\
    if [ ! -d "/workspace/ComfyUI/custom_nodes/$node_name" ]; then\n\
        log_info "Installiere $node_name..."\n\
        git clone "${custom_nodes[$node_name]}" "$node_name" || log_warn "Fehler beim Klonen von $node_name"\n\
    fi\n\
done\n\
\n\
# Dependencies für alle Custom Nodes installieren\n\
log_info "Installiere Custom Node Dependencies..."\n\
cd /workspace/ComfyUI/custom_nodes\n\
for dir in */; do\n\
    if [ -f "$dir/requirements.txt" ]; then\n\
        log_info "  Dependencies für $(basename $dir)"\n\
        pip install -r "$dir/requirements.txt" --quiet 2>/dev/null || log_warn "    Einige Dependencies konnten nicht installiert werden"\n\
    fi\n\
    if [ -f "$dir/install.py" ]; then\n\
        log_info "  Führe install.py für $(basename $dir) aus"\n\
        cd "$dir"\n\
        python install.py 2>/dev/null || log_warn "    Install-Script fehlgeschlagen"\n\
        cd ..\n\
    fi\n\
done\n\
\n\
# Network Volume Support (falls vorhanden)\n\
if [ -d "/runpod-volume" ]; then\n\
    log_info "Network Volume gefunden - synchronisiere Modelle..."\n\
    \n\
    # Modelle vom Network Volume linken\n\
    for model_type in checkpoints vae loras embeddings controlnet clip clip_vision upscale_models; do\n\
        if [ -d "/runpod-volume/models/$model_type" ]; then\n\
            mkdir -p "/runpod-volume/models/$model_type"\n\
            rm -rf "/workspace/ComfyUI/models/$model_type"\n\
            ln -sf "/runpod-volume/models/$model_type" "/workspace/ComfyUI/models/$model_type"\n\
            log_info "  ✓ $model_type verlinkt"\n\
        fi\n\
    done\n\
    \n\
    # Custom Nodes Backup\n\
    if [ ! -d "/runpod-volume/custom_nodes_backup" ]; then\n\
        log_info "Erstelle Backup der Custom Nodes auf Network Volume..."\n\
        cp -r /workspace/ComfyUI/custom_nodes /runpod-volume/custom_nodes_backup\n\
    fi\n\
fi\n\
\n\
# Modelle zählen\n\
checkpoint_count=$(find /workspace/ComfyUI/models/checkpoints -type f \\( -name "*.safetensors" -o -name "*.ckpt" \\) 2>/dev/null | wc -l)\n\
lora_count=$(find /workspace/ComfyUI/models/loras -type f -name "*.safetensors" 2>/dev/null | wc -l)\n\
node_count=$(find /workspace/ComfyUI/custom_nodes -maxdepth 1 -type d | wc -l)\n\
\n\
log_info "========================================"\n\
log_info "Status:"\n\
log_info "  Checkpoints: $checkpoint_count"\n\
log_info "  LoRAs: $lora_count"\n\
log_info "  Custom Nodes: $((node_count-1))"\n\
log_info "========================================"\n\
\n\
# ComfyUI starten\n\
cd /workspace/ComfyUI\n\
log_info "Starte ComfyUI auf Port 8188..."\n\
log_info "Zugriff über Runpod Connect Button"\n\
\n\
exec python main.py \\\n\
    --listen 0.0.0.0 \\\n\
    --port 8188 \\\n\
    --preview-method auto \\\n\
    --use-pytorch-cross-attention \\\n\
    ${EXTRA_COMFYUI_ARGS:-}\n\
' > /start.sh && chmod +x /start.sh

# Port exponieren
EXPOSE 8188

# Umgebungsvariablen
ENV PYTHONUNBUFFERED=1
ENV CUDA_VISIBLE_DEVICES=0
ENV AUTO_UPDATE=false

# Arbeitsverzeichnis
WORKDIR /workspace

# Start-Befehl
CMD ["/start.sh"]