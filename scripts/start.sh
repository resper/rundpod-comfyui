#!/bin/bash

# ComfyUI Startup Script für Runpod
# Dieses Script handled Network Volumes und persistente Daten

echo "========================================="
echo "ComfyUI Runpod Startup Script"
echo "========================================="

# Farbcodes für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funktion für farbige Ausgaben
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# GPU Information anzeigen
log_info "GPU Information:"
nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader || log_warn "nvidia-smi nicht verfügbar"

# Python und CUDA Versionen
log_info "Python Version: $(python --version)"
log_info "CUDA Version: $(nvcc --version | grep release | awk '{print $5}' | sed 's/,//')"

# Prüfen ob Network Volume vorhanden ist
if [ -d "/runpod-volume" ]; then
    log_info "Network Volume gefunden unter /runpod-volume"
    
    # Verzeichnisstruktur auf Network Volume erstellen
    log_info "Erstelle Verzeichnisstruktur auf Network Volume..."
    
    directories=(
        "/runpod-volume/ComfyUI/models/checkpoints"
        "/runpod-volume/ComfyUI/models/vae"
        "/runpod-volume/ComfyUI/models/loras"
        "/runpod-volume/ComfyUI/models/embeddings"
        "/runpod-volume/ComfyUI/models/controlnet"
        "/runpod-volume/ComfyUI/models/clip"
        "/runpod-volume/ComfyUI/models/clip_vision"
        "/runpod-volume/ComfyUI/models/upscale_models"
        "/runpod-volume/ComfyUI/input"
        "/runpod-volume/ComfyUI/output"
        "/runpod-volume/ComfyUI/temp"
        "/runpod-volume/ComfyUI/custom_nodes"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        log_info "  ✓ $dir"
    done
    
    # Custom Nodes zum Volume kopieren (nur wenn nicht vorhanden)
    if [ ! -d "/runpod-volume/ComfyUI/custom_nodes/ComfyUI-Manager" ]; then
        log_info "Kopiere Custom Nodes zum Network Volume..."
        cp -r /workspace/ComfyUI/custom_nodes/* /runpod-volume/ComfyUI/custom_nodes/ 2>/dev/null || true
        log_info "  ✓ Custom Nodes kopiert"
    else
        log_info "Custom Nodes bereits auf Network Volume vorhanden"
    fi
    
    # Symlinks für persistente Daten erstellen
    log_info "Erstelle Symlinks für persistente Daten..."
    
    # Alte Verzeichnisse entfernen falls vorhanden
    rm -rf /workspace/ComfyUI/models 2>/dev/null || true
    rm -rf /workspace/ComfyUI/input 2>/dev/null || true
    rm -rf /workspace/ComfyUI/output 2>/dev/null || true
    rm -rf /workspace/ComfyUI/temp 2>/dev/null || true
    
    # Neue Symlinks erstellen
    ln -sf /runpod-volume/ComfyUI/models /workspace/ComfyUI/models
    ln -sf /runpod-volume/ComfyUI/input /workspace/ComfyUI/input
    ln -sf /runpod-volume/ComfyUI/output /workspace/ComfyUI/output
    ln -sf /runpod-volume/ComfyUI/temp /workspace/ComfyUI/temp
    
    log_info "  ✓ Symlinks erstellt"
    
    # Custom Nodes vom Volume linken
    log_info "Verlinke Custom Nodes vom Network Volume..."
    for dir in /runpod-volume/ComfyUI/custom_nodes/*/; do
        if [ -d "$dir" ]; then
            dirname=$(basename "$dir")
            if [ ! -e "/workspace/ComfyUI/custom_nodes/$dirname" ]; then
                ln -sf "$dir" "/workspace/ComfyUI/custom_nodes/$dirname"
                log_info "  ✓ Verlinkt: $dirname"
            fi
        fi
    done
    
    # Modelle zählen
    checkpoint_count=$(find /runpod-volume/ComfyUI/models/checkpoints -type f -name "*.safetensors" -o -name "*.ckpt" 2>/dev/null | wc -l)
    lora_count=$(find /runpod-volume/ComfyUI/models/loras -type f -name "*.safetensors" 2>/dev/null | wc -l)
    
    log_info "Gefundene Modelle:"
    log_info "  - Checkpoints: $checkpoint_count"
    log_info "  - LoRAs: $lora_count"
    
else
    log_warn "Kein Network Volume gefunden - Daten werden nicht persistent gespeichert!"
    log_warn "Empfehlung: Fügen Sie ein Network Volume unter /runpod-volume hinzu"
fi

# ComfyUI Updates prüfen (optional)
if [ "$AUTO_UPDATE" = "true" ]; then
    log_info "Prüfe auf ComfyUI Updates..."
    cd /workspace/ComfyUI
    git fetch
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u})
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        log_info "Update verfügbar, aktualisiere ComfyUI..."
        git pull
        pip install -r requirements.txt --upgrade --quiet
        log_info "  ✓ ComfyUI aktualisiert"
    else
        log_info "  ✓ ComfyUI ist aktuell"
    fi
fi

# Custom Node Dependencies installieren (falls neue hinzugefügt wurden)
log_info "Prüfe Custom Node Dependencies..."
for req_file in /workspace/ComfyUI/custom_nodes/*/requirements.txt; do
    if [ -f "$req_file" ]; then
        node_name=$(basename $(dirname "$req_file"))
        # Prüfen ob bereits installiert wurde (simple check)
        if [ ! -f "/tmp/.installed_$node_name" ]; then
            log_info "  Installiere Dependencies für: $node_name"
            pip install -r "$req_file" --quiet 2>/dev/null || log_warn "    Einige Dependencies konnten nicht installiert werden"
            touch "/tmp/.installed_$node_name"
        fi
    fi
done

# Arbeitsverzeichnis wechseln
cd /workspace/ComfyUI

# IP-Adresse ermitteln
IP=$(hostname -I | awk '{print $1}')

# ComfyUI starten
log_info "========================================="
log_info "Starte ComfyUI..."
log_info "Zugriff über: http://$IP:8188"
log_info "oder über Runpod Connect Button"
log_info "========================================="

# ComfyUI mit erweiterten Optionen starten
exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --preview-method auto \
    --use-pytorch-cross-attention \
    ${EXTRA_COMFYUI_ARGS}