# Basis-Image von RunPod mit CUDA Support
FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04

# Arbeitsverzeichnis setzen
WORKDIR /

# System-Updates und benötigte Pakete installieren
RUN apt-get update && apt-get install -y \
    git \
    python3-pip \
    python3-venv \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    wget \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Python-Pakete aktualisieren
RUN pip install --upgrade pip setuptools wheel

# Scripts kopieren
COPY scripts/install-comfyui.sh /install-comfyui.sh
COPY scripts/start.sh /start.sh
RUN chmod +x /install-comfyui.sh /start.sh

# ComfyUI Installation Script ausführen
RUN /install-comfyui.sh

# Ports freigeben
EXPOSE 8188 8888

# Start-Script als Entrypoint
ENTRYPOINT ["/start.sh"]