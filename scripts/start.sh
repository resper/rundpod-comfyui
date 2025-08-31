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
    
    # ComfyUI updaten mit Konflikt-Behandlung
    cd $COMFYUI_DIR
    
    # Git-Status prüfen
    if git diff --quiet && git diff --staged --quiet; then
        # Keine lokalen Änderungen, normales Update
        echo "No local changes detected, updating ComfyUI..."
        git pull
    else
        echo "Local changes detected. Handling git conflicts..."
        
        # Option 1: Lokale Änderungen speichern und Update durchführen
        # (Änderungen werden gesichert aber nicht angewendet)
        git stash push -m "Auto-stash before update $(date +%Y%m%d-%H%M%S)"
        git pull
        
        # Optional: Versuchen, die Änderungen wieder anzuwenden
        # git stash pop || echo "Could not reapply local changes, they are saved in stash"
        
        # Option 2 (Alternative - aggressiver): Lokale Änderungen verwerfen
        # echo "Discarding local changes for clean update..."
        # git reset --hard
        # git clean -fd
        # git pull
    fi
    
    # Manager updaten mit gleicher Logik
    if [ -d "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager" ]; then
        cd $COMFYUI_DIR/custom_nodes/ComfyUI-Manager
        
        if git diff --quiet && git diff --staged --quiet; then
            git pull
        else
            echo "Stashing ComfyUI-Manager changes..."
            git stash push -m "Manager auto-stash $(date +%Y%m%d-%H%M%S)"
            git pull
        fi
        
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