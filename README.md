# ComfyUI Docker für Runpod

Dieses Repository enthält ein Docker-Image für ComfyUI, optimiert für die Verwendung auf Runpod mit persistentem Speicher in `/workspace`.

## ⚠️ WICHTIG: Persistenz-Strategie

**Dieses Image verwendet eine spezielle Strategie für maximale Persistenz:**

1. **ComfyUI wird NICHT im Docker-Image installiert**, sondern beim ersten Start in `/workspace/ComfyUI`
2. **Alle Custom Nodes** werden direkt in `/workspace/ComfyUI/custom_nodes` installiert
3. **Alle Modelle** bleiben in `/workspace/ComfyUI/models`
4. **Python Dependencies** sind im Image vorinstalliert für schnelleren Start

**Vorteile:**
- ✅ Custom Nodes überleben JEDEN Neustart
- ✅ Modelle bleiben immer erhalten
- ✅ Workflows und Einstellungen persistent
- ✅ Updates ohne Image-Rebuild möglich

## Features

- ✅ **Neueste ComfyUI Version** mit automatischen Updates
- ✅ **Vorinstallierte Custom Nodes** inkl. Impact Pack, AnimateDiff, IPAdapter Plus
- ✅ **Alle wichtigen Dependencies** (OpenCV, Transformers, Diffusers, etc.)
- ✅ **Persistente Daten** in `/workspace` und Network Volume Support
- ✅ **Automatischer Build** via GitHub Actions
- ✅ **ComfyUI Manager** für einfache Node-Installation

## 🚀 Schnellstart

## 📁 Repository-Struktur

```
.
├── Dockerfile                    # Haupt-Dockerfile
├── .dockerignore                # Build-Optimierung
├── .github/
│   └── workflows/
│       └── docker-build.yml     # GitHub Actions Workflow
├── scripts/
│   ├── fix-custom-nodes.sh     # Reparatur-Script
│   ├── test-installation.sh    # Test-Script
│   └── start.sh                # Startup-Script (wird ins Image kopiert)
├── docker-compose.yml           # Für lokales Testen (optional)
└── README.md                    # Diese Datei
```

### 2. DockerHub Konfiguration

1. Erstellen Sie einen Account auf [DockerHub](https://hub.docker.com/)
2. Generieren Sie einen Access Token:
   - Gehen Sie zu Account Settings → Security
   - Klicken Sie auf "New Access Token"
   - Geben Sie dem Token einen Namen (z.B. "github-actions")
   - Wählen Sie "Read, Write, Delete" Permissions
   - Kopieren Sie den Token (wird nur einmal angezeigt!)

### 3. GitHub Secrets einrichten

In Ihrem GitHub Repository:
1. Gehen Sie zu Settings → Secrets and variables → Actions
2. Fügen Sie folgende Secrets hinzu:
   - `DOCKERHUB_USERNAME`: Ihr DockerHub Benutzername
   - `DOCKERHUB_TOKEN`: Der Access Token von DockerHub

### 4. Docker Image bauen

Das Image wird automatisch gebaut, wenn Sie:
- Änderungen zum `main`/`master` Branch pushen
- Den Workflow manuell triggern (Actions → Run workflow)

Nach erfolgreichem Build finden Sie Ihr Image unter:
```
docker.io/IHR_DOCKERHUB_USERNAME/comfyui-runpod:latest
```

## 📦 Verwendung auf Runpod

### Option 1: GPU Pod mit Custom Docker Image

1. Gehen Sie zu [Runpod](https://www.runpod.io/) → GPU Pods
2. Klicken Sie auf "Deploy"
3. Wählen Sie eine GPU (empfohlen: RTX 4090 oder besser)
4. Unter "Container Image" geben Sie ein:
   ```
   IHR_DOCKERHUB_USERNAME/comfyui-runpod:latest
   ```
5. Container Disk: mindestens 30GB
6. Volume Disk: 50-100GB für Modelle (optional aber empfohlen)
7. Exposed HTTP Ports: `8188`
8. Deploy!

### Option 2: Mit Network Volume (Empfohlen)

1. **Network Volume erstellen:**
   - Storage → New Network Volume
   - Wählen Sie eine Region
   - 50-100GB Speicher
   - Volume erstellen

2. **Pod mit Volume deployen:**
   - Bei Pod-Erstellung Volume auswählen
   - Mount Path: `/runpod-volume`
   - Das Image wird automatisch die Verzeichnisse einrichten

### Zugriff auf ComfyUI

Nach dem Start:
1. Warten Sie 2-3 Minuten für die Initialisierung
2. In der Pod-Übersicht klicken Sie auf "Connect"
3. Wählen Sie "Connect to HTTP Service [Port 8188]"
4. ComfyUI öffnet sich im Browser

## 🔧 Fehlerbehebung

### Custom Nodes verschwinden nach Neustart

**Das Problem:** Custom Nodes werden nicht persistent gespeichert.

**Die Lösung:** Dieses Image installiert ALLES in `/workspace`, wodurch es persistent bleibt!

Falls trotzdem Probleme auftreten:

1. **SSH in den Pod verbinden**
2. **Fix-Script ausführen:**
```bash
# Script herunterladen
wget https://raw.githubusercontent.com/IHR_GITHUB/IHR_REPO/main/fix-custom-nodes.sh
chmod +x fix-custom-nodes.sh

# Ausführen mit Optionen:
./fix-custom-nodes.sh --reinstall-all  # Alle Nodes neu installieren
./fix-custom-nodes.sh --fix-permissions # Berechtigungen reparieren
./fix-custom-nodes.sh --update-nodes    # Alle Nodes updaten
```

### ModuleNotFoundError: No module named 'cv2'

**Ursache:** Impact Pack oder andere Nodes finden OpenCV nicht.

**Lösung:**
```bash
# Via SSH verbinden und ausführen:
pip install opencv-python opencv-contrib-python
cd /workspace/ComfyUI/custom_nodes/ComfyUI-Impact-Pack
python install.py
```

### Custom Nodes installieren

Mit ComfyUI Manager (bereits vorinstalliert):
1. In ComfyUI auf "Manager" klicken
2. "Install Custom Nodes" wählen
3. Node suchen und installieren

Manuell via SSH:
```bash
cd /workspace/ComfyUI/custom_nodes
git clone https://github.com/AUTHOR/NODE_NAME.git
cd NODE_NAME
pip install -r requirements.txt  # falls vorhanden
```

### Modelle hinzufügen

Modelle können in folgende Verzeichnisse gelegt werden:
- Checkpoints: `/workspace/ComfyUI/models/checkpoints/`
- LoRAs: `/workspace/ComfyUI/models/loras/`
- VAE: `/workspace/ComfyUI/models/vae/`
- ControlNet: `/workspace/ComfyUI/models/controlnet/`

Mit Network Volume bleiben diese dauerhaft erhalten.

## 🔄 Updates

### ComfyUI aktualisieren

SSH in den Pod und ausführen:
```bash
cd /workspace/ComfyUI
git pull
pip install -r requirements.txt --upgrade
```

### Docker Image neu bauen

1. Ändern Sie die `Dockerfile`
2. Pushen Sie zu GitHub
3. GitHub Actions baut automatisch das neue Image

## 📊 Ressourcenverbrauch

- **Minimale GPU**: RTX 3060 (12GB VRAM)
- **Empfohlene GPU**: RTX 4090 (24GB VRAM)
- **Container Disk**: 30-50GB
- **Network Volume**: 50-100GB für Modelle
- **RAM**: 16GB+ empfohlen

## 🛠️ Anpassungen

### Weitere Custom Nodes hinzufügen

Bearbeiten Sie die `Dockerfile` und fügen Sie im Abschnitt "Custom Nodes" hinzu:
```dockerfile
RUN cd /workspace/ComfyUI/custom_nodes && \
    git clone https://github.com/AUTHOR/NEUER_NODE.git
```

### Python Packages hinzufügen

In der `Dockerfile` im Abschnitt "Python-Abhängigkeiten":
```dockerfile
RUN pip install PACKAGE_NAME
```

## 📝 Lizenz

MIT License - Frei verwendbar

## 🤝 Support

Bei Problemen:
1. Prüfen Sie die Logs in Runpod (Pod → Logs)
2. SSH-Verbindung für Debugging
3. ComfyUI Manager für Node-Probleme nutzen

## Wichtige Hinweise

- Das erste Starten kann 5-10 Minuten dauern
- Network Volumes sind für dauerhafte Modellspeicherung empfohlen
- Bei Serverless-Deployments andere Images verwenden (runpod-worker-comfy)
- Regelmäßige Backups wichtiger Workflows empfohlen
