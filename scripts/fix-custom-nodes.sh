#!/bin/bash

# Fix-Script für Custom Nodes Probleme auf Runpod
# Kann via SSH ausgeführt werden wenn Probleme auftreten

echo "========================================="
echo "ComfyUI Custom Nodes Fix Script"
echo "========================================="

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Optionen
REINSTALL_ALL=false
FIX_PERMISSIONS=false
UPDATE_NODES=false

# Argumente verarbeiten
while [[ $# -gt 0 ]]; do
    case $1 in
        --reinstall-all)
            REINSTALL_ALL=true
            shift
            ;;
        --fix-permissions)
            FIX_PERMISSIONS=true
            shift
            ;;
        --update-nodes)
            UPDATE_NODES=true
            shift
            ;;
        --help)
            echo "Verwendung: $0 [OPTIONEN]"
            echo "Optionen:"
            echo "  --reinstall-all     Alle Custom Nodes neu installieren"
            echo "  --fix-permissions   Dateiberechtigungen reparieren"
            echo "  --update-nodes      Alle Custom Nodes updaten"
            echo "  --help             Diese Hilfe anzeigen"
            exit 0
            ;;
        *)
            log_error "Unbekannte Option: $1"
            exit 1
            ;;
    esac
done

# Prüfen ob ComfyUI existiert
if [ ! -d "/workspace/ComfyUI" ]; then
    log_error "ComfyUI nicht gefunden in /workspace/ComfyUI"
    log_info "Installiere ComfyUI neu..."
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
    cd /workspace/ComfyUI
    pip install -r requirements.txt
fi

cd /workspace/ComfyUI

# 1. Fehlende Custom Nodes Verzeichnis erstellen
if [ ! -d "/workspace/ComfyUI/custom_nodes" ]; then
    log_warn "Custom Nodes Verzeichnis fehlt - wird erstellt"
    mkdir -p /workspace/ComfyUI/custom_nodes
fi

# 2. ComfyUI Manager installieren/reparieren
if [ ! -d "/workspace/ComfyUI/custom_nodes/ComfyUI-Manager" ] || [ "$REINSTALL_ALL" = true ]; then
    log_info "Installiere/Repariere ComfyUI Manager..."
    cd /workspace/ComfyUI/custom_nodes
    rm -rf ComfyUI-Manager
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    cd ComfyUI-Manager
    pip install -r requirements.txt 2>/dev/null || true
fi

# 3. Impact Pack reparieren (häufigste cv2 Fehlerquelle)
if [ ! -d "/workspace/ComfyUI/custom_nodes/ComfyUI-Impact-Pack" ] || [ "$REINSTALL_ALL" = true ]; then
    log_info "Installiere/Repariere Impact Pack..."
    cd /workspace/ComfyUI/custom_nodes
    rm -rf ComfyUI-Impact-Pack
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
    cd ComfyUI-Impact-Pack
    git submodule update --init --recursive
    python install.py 2>/dev/null || true
    pip install -r requirements.txt 2>/dev/null || true
fi

# 4. OpenCV explizit installieren
log_info "Stelle sicher dass OpenCV installiert ist..."
pip install opencv-python opencv-contrib-python --upgrade

# 5. Weitere wichtige Dependencies
log_info "Installiere wichtige Dependencies..."
pip install \
    numpy \
    pillow \
    scipy \
    scikit-image \
    matplotlib \
    transformers \
    diffusers \
    accelerate \
    safetensors \
    GitPython \
    segment-anything

# 6. Alle Custom Nodes durchgehen und Dependencies installieren
log_info "Prüfe alle Custom Nodes auf fehlende Dependencies..."
cd /workspace/ComfyUI/custom_nodes

for dir in */; do
    if [ -d "$dir" ]; then
        node_name=$(basename "$dir")
        log_info "Prüfe $node_name..."
        
        # Update wenn gewünscht
        if [ "$UPDATE_NODES" = true ]; then
            cd "$dir"
            git pull 2>/dev/null || log_warn "  Konnte $node_name nicht updaten"
            cd ..
        fi
        
        # Requirements installieren
        if [ -f "$dir/requirements.txt" ]; then
            log_info "  Installiere requirements.txt für $node_name"
            pip install -r "$dir/requirements.txt" --quiet 2>/dev/null || log_warn "  Einige Dependencies konnten nicht installiert werden"
        fi
        
        # Install.py ausführen
        if [ -f "$dir/install.py" ]; then
            log_info "  Führe install.py für $node_name aus"
            cd "$dir"
            python install.py 2>/dev/null || log_warn "  Install-Script fehlgeschlagen"
            cd ..
        fi
    fi
done

# 7. Berechtigungen reparieren
if [ "$FIX_PERMISSIONS" = true ]; then
    log_info "Repariere Dateiberechtigungen..."
    chmod -R 755 /workspace/ComfyUI
    chmod -R 777 /workspace/ComfyUI/output
    chmod -R 777 /workspace/ComfyUI/input
    chmod -R 777 /workspace/ComfyUI/temp 2>/dev/null || true
fi

# 8. Python-Cache löschen
log_info "Lösche Python-Cache..."
find /workspace/ComfyUI -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find /workspace/ComfyUI -name "*.pyc" -delete 2>/dev/null || true

# 9. Test ob cv2 funktioniert
log_info "Teste OpenCV (cv2) Import..."
python -c "import cv2; print(f'OpenCV Version: {cv2.__version__}')" && \
    log_info "✓ OpenCV funktioniert!" || \
    log_error "✗ OpenCV Import fehlgeschlagen!"

# 10. Zusammenfassung
echo ""
echo "========================================="
log_info "Fix-Script abgeschlossen!"
echo "========================================="

# Custom Nodes zählen
node_count=$(find /workspace/ComfyUI/custom_nodes -maxdepth 1 -type d | wc -l)
log_info "Installierte Custom Nodes: $((node_count-1))"

# Liste der Custom Nodes
log_info "Gefundene Custom Nodes:"
for dir in /workspace/ComfyUI/custom_nodes/*/; do
    if [ -d "$dir" ]; then
        echo "  - $(basename $dir)"
    fi
done

echo ""
log_info "Nächste Schritte:"
echo "  1. ComfyUI neu starten: supervisorctl restart comfyui"
echo "  2. Oder Pod neu starten über Runpod Dashboard"
echo "  3. Browser-Cache leeren (Strg+F5 in ComfyUI)"

# Optional: ComfyUI direkt neu starten
read -p "ComfyUI jetzt neu starten? (j/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Jj]$ ]]; then
    log_info "Starte ComfyUI neu..."
    pkill -f "python.*main.py" 2>/dev/null || true
    sleep 2
    cd /workspace/ComfyUI
    nohup python main.py --listen 0.0.0.0 --port 8188 > /tmp/comfyui.log 2>&1 &
    log_info "ComfyUI wurde neu gestartet!"
    log_info "Logs: tail -f /tmp/comfyui.log"
fi