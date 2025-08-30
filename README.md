# ComfyUI RunPod Docker Setup mit GitHub Actions

## Übersicht
Diese Anleitung zeigt, wie Sie ComfyUI in der neuesten Version auf RunPod mit persistentem Storage einrichten, ohne lokale Entwicklerumgebung.

## Projektstruktur

```
comfyui-runpod/
├── Dockerfile
├── .github/
│   └── workflows/
│       └── docker-build.yml
├── scripts/
│   ├── start.sh
│   └── install-comfyui.sh
└── README.md
```

## 1. GitHub Repository erstellen

1. Erstellen Sie ein neues Repository auf GitHub (z.B. `comfyui-runpod`)
2. Klonen Sie es lokal oder arbeiten Sie direkt im GitHub Web-Editor

## 2. DockerHub vorbereiten

1. Erstellen Sie einen Account auf [hub.docker.com](https://hub.docker.com)
2. Erstellen Sie ein Access Token:
   - Gehen Sie zu Account Settings → Security
   - New Access Token erstellen
   - Speichern Sie das Token sicher

## 3. GitHub Secrets einrichten

In Ihrem GitHub Repository:
1. Settings → Secrets and variables → Actions
2. Fügen Sie folgende Secrets hinzu:
   - `DOCKERHUB_USERNAME`: Ihr DockerHub Benutzername
   - `DOCKERHUB_TOKEN`: Das erstellte Access Token

## 4. Dockerfile erstellen

Erstellen Sie `Dockerfile` im Root-Verzeichnis:

```dockerfile
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
    nano \
    vim \
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
```

## 5. Installation Script erstellen

Erstellen Sie `scripts/install-comfyui.sh`:

```bash
#!/bin/bash
set -e

echo "Installing ComfyUI dependencies..."

# Temporäre Installation für Docker Build
TEMP_DIR="/tmp/comfyui_setup"
mkdir -p $TEMP_DIR
cd $TEMP_DIR

# ComfyUI klonen (neueste Version)
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

# Python-Abhängigkeiten installieren
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install -r requirements.txt

# ComfyUI Manager installieren
cd custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager.git
cd ComfyUI-Manager
pip install -r requirements.txt
cd ../..

# Weitere beliebte Custom Nodes vorinstallieren (optional)
cd custom_nodes
# ComfyUI-AnimateDiff-Evolved
git clone https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git
# ComfyUI Impact Pack
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
cd ComfyUI-Impact-Pack
python install.py
cd ..
# ComfyUI Efficiency Nodes
git clone https://github.com/jags111/efficiency-nodes-comfyui.git
cd ../..

# Cleanup
cd /
rm -rf $TEMP_DIR

echo "ComfyUI base installation complete!"
```

## 6. Start Script erstellen

Erstellen Sie `scripts/start.sh`:

```bash
#!/bin/bash
set -e

WORKSPACE_DIR="/workspace"
COMFYUI_DIR="$WORKSPACE_DIR/ComfyUI"

echo "Starting ComfyUI setup..."

# Workspace-Verzeichnis erstellen falls nicht vorhanden
mkdir -p $WORKSPACE_DIR

# Prüfen ob ComfyUI bereits in /workspace existiert
if [ ! -d "$COMFYUI_DIR" ]; then
    echo "First run detected. Setting up ComfyUI in persistent storage..."
    
    # ComfyUI in /workspace klonen
    cd $WORKSPACE_DIR
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd $COMFYUI_DIR
    
    # Requirements installieren
    pip install -r requirements.txt
    
    # ComfyUI Manager installieren
    cd custom_nodes
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    cd ComfyUI-Manager
    pip install -r requirements.txt
    
    # Weitere Custom Nodes aus Docker Image kopieren (falls vorhanden)
    if [ -d "/tmp/comfyui_setup/ComfyUI/custom_nodes" ]; then
        cp -r /tmp/comfyui_setup/ComfyUI/custom_nodes/* $COMFYUI_DIR/custom_nodes/ 2>/dev/null || true
    fi
    
    echo "Initial setup complete!"
else
    echo "ComfyUI found in persistent storage. Updating..."
    
    # ComfyUI updaten
    cd $COMFYUI_DIR
    git pull
    
    # Manager updaten
    if [ -d "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager" ]; then
        cd $COMFYUI_DIR/custom_nodes/ComfyUI-Manager
        git pull
        pip install -r requirements.txt
    fi
    
    # Custom Nodes Dependencies installieren
    cd $COMFYUI_DIR
    if [ -d "custom_nodes" ]; then
        for dir in custom_nodes/*/; do
            if [ -f "${dir}requirements.txt" ]; then
                echo "Installing requirements for $(basename $dir)..."
                pip install -r "${dir}requirements.txt" 2>/dev/null || true
            fi
            if [ -f "${dir}install.py" ]; then
                echo "Running install.py for $(basename $dir)..."
                cd "$dir"
                python install.py 2>/dev/null || true
                cd $COMFYUI_DIR
            fi
        done
    fi
fi

# Modell-Verzeichnisse erstellen
mkdir -p $COMFYUI_DIR/models/checkpoints
mkdir -p $COMFYUI_DIR/models/vae
mkdir -p $COMFYUI_DIR/models/loras
mkdir -p $COMFYUI_DIR/models/embeddings
mkdir -p $COMFYUI_DIR/models/controlnet
mkdir -p $COMFYUI_DIR/input
mkdir -p $COMFYUI_DIR/output

# ComfyUI starten
cd $COMFYUI_DIR
echo "Starting ComfyUI server..."
python main.py --listen 0.0.0.0 --port 8188
```

## 7. GitHub Actions Workflow erstellen

Erstellen Sie `.github/workflows/docker-build.yml`:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]
    paths:
      - 'Dockerfile'
      - 'scripts/**'
      - '.github/workflows/docker-build.yml'
  workflow_dispatch:

env:
  IMAGE_NAME: comfyui-runpod

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Log in to DockerHub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKERHUB_USERNAME }}
        password: ${{ secrets.DOCKERHUB_TOKEN }}
    
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ secrets.DOCKERHUB_USERNAME }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}
          type=raw,value={{date 'YYYYMMDD-HHmmss'}}
    
    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=registry,ref=${{ secrets.DOCKERHUB_USERNAME }}/${{ env.IMAGE_NAME }}:buildcache
        cache-to: type=registry,ref=${{ secrets.DOCKERHUB_USERNAME }}/${{ env.IMAGE_NAME }}:buildcache,mode=max
        platforms: linux/amd64
```

## 8. RunPod Setup

### Network Volume erstellen (für persistente Daten):

1. RunPod Dashboard → Storage → Create Network Volume
2. Name: `comfyui-data`
3. Size: 50-100 GB (je nach Bedarf)
4. Region: Wählen Sie die gewünschte Region

### Pod erstellen:

1. RunPod Dashboard → Pods → Deploy
2. **Container Image**: `[IHR_DOCKERHUB_USERNAME]/comfyui-runpod:latest`
3. **Container Disk**: 20 GB (minimum)
4. **Volume**: Wählen Sie Ihr erstelltes Network Volume
5. **Volume Mount Path**: `/workspace`
6. **GPU**: RTX 3090, 4090 oder A5000 empfohlen
7. **Exposed Ports**: 8188,8888
8. Deploy klicken

## 9. Verwendung

Nach dem Start:
1. Warten Sie 2-3 Minuten für die Initialisierung
2. Im RunPod Dashboard → Connect → Port 8188
3. ComfyUI öffnet sich im Browser
4. ComfyUI Manager ist unter dem Manager-Button verfügbar

## Wichtige Verzeichnisse im Container

- `/workspace/ComfyUI/` - Hauptverzeichnis (persistent)
- `/workspace/ComfyUI/models/` - Modelle
- `/workspace/ComfyUI/custom_nodes/` - Custom Nodes
- `/workspace/ComfyUI/input/` - Input Dateien
- `/workspace/ComfyUI/output/` - Generierte Bilder

## Troubleshooting

### Custom Nodes werden nicht erkannt:
```bash
# Über RunPod Web Terminal:
cd /workspace/ComfyUI
python main.py --reinstall-custom-nodes
```

### Fehlende Python-Pakete:
```bash
cd /workspace/ComfyUI
pip install -r custom_nodes/[NODE_NAME]/requirements.txt
```

### ComfyUI startet nicht:
```bash
# Logs prüfen
tail -f /workspace/comfyui.log

# Manuell starten
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188
```

## Best Practices

1. **Modelle**: Große Modelle (Checkpoints) im Network Volume speichern
2. **Backups**: Regelmäßig wichtige Workflows exportieren
3. **Updates**: ComfyUI Manager für Updates verwenden
4. **Performance**: GPU mit mindestens 12GB VRAM für SDXL Modelle

## Kosten-Optimierung

- Pod nach Verwendung stoppen (nicht terminieren)
- Network Volume behält alle Daten
- Bei erneutem Start ist alles sofort verfügbar
- Community Cloud für Tests, Secure Cloud für Produktion

## Erweiterte Konfiguration

### Automatisches Modell-Download hinzufügen:

In `scripts/start.sh` vor dem Start von ComfyUI:

```bash
# Beispiel: SDXL Base Modell herunterladen
if [ ! -f "$COMFYUI_DIR/models/checkpoints/sd_xl_base_1.0.safetensors" ]; then
    wget -P $COMFYUI_DIR/models/checkpoints/ \
        https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
fi
```

Diese Lösung stellt sicher, dass:
- ComfyUI immer in `/workspace` installiert wird (persistent)
- Custom Nodes persistent bleiben
- Der Manager vorinstalliert ist
- Updates automatisch durchgeführt werden
- Alle Daten zwischen Sessions erhalten bleiben