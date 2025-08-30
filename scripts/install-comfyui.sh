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