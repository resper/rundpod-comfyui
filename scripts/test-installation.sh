#!/bin/bash

# Test-Script um zu prüfen ob die ComfyUI Installation korrekt funktioniert
# Kann nach dem Pod-Start via SSH ausgeführt werden

echo "========================================="
echo "ComfyUI Installation Test"
echo "========================================="

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

# Test-Funktion
test_check() {
    local test_name=$1
    local test_command=$2
    
    echo -n "Testing: $test_name ... "
    
    if eval $test_command > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((ERRORS++))
        return 1
    fi
}

# Warning-Funktion
test_warn() {
    local test_name=$1
    local test_command=$2
    
    echo -n "Checking: $test_name ... "
    
    if eval $test_command > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ WARNING${NC}"
        ((WARNINGS++))
        return 1
    fi
}

echo ""
echo "1. System Tests"
echo "----------------------------------------"
test_check "CUDA available" "nvidia-smi"
test_check "Python installed" "python --version"
test_check "Pip installed" "pip --version"
test_check "Git installed" "git --version"

echo ""
echo "2. ComfyUI Installation"
echo "----------------------------------------"
test_check "ComfyUI directory exists" "[ -d /workspace/ComfyUI ]"
test_check "ComfyUI main.py exists" "[ -f /workspace/ComfyUI/main.py ]"
test_check "Models directory exists" "[ -d /workspace/ComfyUI/models ]"
test_check "Custom nodes directory exists" "[ -d /workspace/ComfyUI/custom_nodes ]"

echo ""
echo "3. Python Dependencies"
echo "----------------------------------------"
test_check "PyTorch installed" "python -c 'import torch'"
test_check "OpenCV installed" "python -c 'import cv2'"
test_check "NumPy installed" "python -c 'import numpy'"
test_check "Pillow installed" "python -c 'import PIL'"
test_check "Transformers installed" "python -c 'import transformers'"
test_check "Diffusers installed" "python -c 'import diffusers'"

echo ""
echo "4. Custom Nodes"
echo "----------------------------------------"
test_warn "ComfyUI Manager" "[ -d /workspace/ComfyUI/custom_nodes/ComfyUI-Manager ]"
test_warn "Impact Pack" "[ -d /workspace/ComfyUI/custom_nodes/ComfyUI-Impact-Pack ]"

# Custom Nodes zählen
if [ -d /workspace/ComfyUI/custom_nodes ]; then
    node_count=$(find /workspace/ComfyUI/custom_nodes -maxdepth 1 -type d | wc -l)
    echo "Installed custom nodes: $((node_count-1))"
fi

echo ""
echo "5. Model Files"
echo "----------------------------------------"
checkpoint_count=$(find /workspace/ComfyUI/models -name "*.safetensors" -o -name "*.ckpt" 2>/dev/null | wc -l)
echo "Model files found: $checkpoint_count"

if [ $checkpoint_count -eq 0 ]; then
    echo -e "${YELLOW}⚠ No model files found. You need to download models to generate images.${NC}"
fi

echo ""
echo "6. ComfyUI Service"
echo "----------------------------------------"
# Prüfen ob ComfyUI läuft
if pgrep -f "python.*main.py" > /dev/null; then
    echo -e "${GREEN}✓ ComfyUI is running${NC}"
    
    # Port Check
    if netstat -tuln | grep -q ":8188"; then
        echo -e "${GREEN}✓ ComfyUI listening on port 8188${NC}"
    else
        echo -e "${RED}✗ ComfyUI not listening on port 8188${NC}"
        ((ERRORS++))
    fi
else
    echo -e "${YELLOW}⚠ ComfyUI is not running${NC}"
    echo "  Start with: cd /workspace/ComfyUI && python main.py --listen 0.0.0.0 --port 8188"
fi

echo ""
echo "7. Disk Space"
echo "----------------------------------------"
df -h /workspace | tail -1 | awk '{print "Used: "$3" / "$2" ("$5")"}'

# GPU Memory
echo ""
echo "8. GPU Memory"
echo "----------------------------------------"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | awk '{print "GPU Memory: "$1" MB / "$2" MB"}'

echo ""
echo "========================================="
echo "Test Results:"
echo "========================================="

if [ $ERRORS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed! ComfyUI is ready to use.${NC}"
    else
        echo -e "${YELLOW}⚠ Tests passed with $WARNINGS warnings.${NC}"
        echo "  The warnings are not critical, but you may want to check them."
    fi
else
    echo -e "${RED}✗ $ERRORS tests failed!${NC}"
    echo "  Please run the fix script: ./fix-custom-nodes.sh"
fi

echo ""
echo "Next steps:"
echo "1. Open ComfyUI in browser via Runpod Connect button"
echo "2. Download models to /workspace/ComfyUI/models/checkpoints/"
echo "3. Install additional custom nodes via ComfyUI Manager"

# Optional: URL anzeigen
if [ -n "$RUNPOD_POD_ID" ]; then
    echo ""
    echo "Your pod ID: $RUNPOD_POD_ID"
fi