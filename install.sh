#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_NAME="lerobot-MakerMods-main"
REPO_DIR="$SCRIPT_DIR/$REPO_NAME"
WEBUI_DIR="$REPO_DIR/src/lerobot/webui"
PYTHON_DIR="$REPO_DIR/python"
PYTHON_VERSION="3.10.20"
BUILD_TAG="20260310"
RELEASE_TAG="v0.1.0-beta.1"

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin)
    case "$ARCH" in
      arm64)  TRIPLE="aarch64-apple-darwin" ;;
      x86_64) TRIPLE="x86_64-apple-darwin" ;;
      *) echo "Unsupported macOS architecture: $ARCH"; exit 1 ;;
    esac
    ;;
  Linux)
    case "$ARCH" in
      x86_64)  TRIPLE="x86_64-unknown-linux-gnu" ;;
      aarch64) TRIPLE="aarch64-unknown-linux-gnu" ;;
      *) echo "Unsupported Linux architecture: $ARCH"; exit 1 ;;
    esac
    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

PYTHON_FILENAME="cpython-${PYTHON_VERSION}+${BUILD_TAG}-${TRIPLE}-install_only.tar.gz"
PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/${BUILD_TAG}/${PYTHON_FILENAME}"
REPO_ZIP_URL="https://github.com/Maker-Mods/lerobot-MakerMods/archive/refs/heads/main.zip"
WEBUI_URL="https://github.com/Maker-Mods/MakerMods-App/releases/download/${RELEASE_TAG}/webui.tar.gz"
BACKEND_URL="https://github.com/Maker-Mods/MakerMods-App/releases/download/${RELEASE_TAG}/backend.tar.gz"
REQUIREMENTS_URL="https://github.com/Maker-Mods/MakerMods-App/releases/download/${RELEASE_TAG}/standalone-requirements.txt"

echo "=== LeRobot UI — Standalone Installer ==="
echo ""

# Check for required tools
if ! command -v unzip &>/dev/null; then
  echo "Error: 'unzip' is required but not installed."
  if [ "$OS" = "Linux" ] && command -v apt &>/dev/null; then
    read -r -p "Install unzip via apt? [y/N] " response
    case "$response" in
      [yY][eE][sS]|[yY]) sudo apt-get update && sudo apt-get install -y unzip ;;
      *) echo "unzip is required. Aborting."; exit 1 ;;
    esac
  else
    echo "Please install unzip and re-run this script."
    exit 1
  fi
fi

# Check for ffmpeg
if ! command -v ffmpeg &>/dev/null; then
  echo "ffmpeg is not installed."
  if [ "$OS" = "Darwin" ] && command -v brew &>/dev/null; then
    PKG_MANAGER="brew"
  elif [ "$OS" = "Linux" ] && command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
  else
    echo "No supported package manager found (brew on macOS, apt on Linux)."
    echo "Please install ffmpeg manually and re-run this script."
    exit 1
  fi

  read -r -p "ffmpeg is required but not installed. Install it via $PKG_MANAGER? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY])
      if [ "$PKG_MANAGER" = "brew" ]; then
        brew install ffmpeg
      else
        sudo apt-get update && sudo apt-get install -y ffmpeg
      fi
      ;;
    *)
      echo "ffmpeg is required. Aborting."
      exit 1
      ;;
  esac
fi

# Download and extract the lerobot-MakerMods repository
if [ -d "$REPO_DIR" ]; then
  echo "Repository already present at $REPO_DIR, skipping download."
else
  echo "Downloading lerobot-MakerMods repository..."
  curl -L --fail --no-progress-meter -o "/tmp/lerobot-main.zip" "$REPO_ZIP_URL"
  echo "Extracting repository..."
  unzip -q "/tmp/lerobot-main.zip" -d "$SCRIPT_DIR"
  rm "/tmp/lerobot-main.zip"
  echo "Repository extracted to $REPO_DIR"
fi

echo ""

# Create webui directory inside the repo
mkdir -p "$WEBUI_DIR"

# Download and extract pre-built frontend into src/lerobot/webui/
if [ -d "$WEBUI_DIR/frontend/out" ]; then
  echo "Pre-built frontend already present at src/lerobot/webui/frontend/out, skipping download."
else
  echo "Downloading pre-built frontend..."
  curl -L --fail --progress-bar -o "/tmp/webui.tar.gz" "$WEBUI_URL"
  echo "Extracting frontend..."
  tar -xzf "/tmp/webui.tar.gz" -C "$WEBUI_DIR"
  rm "/tmp/webui.tar.gz"
  echo "Frontend extracted to src/lerobot/webui/frontend/out"
fi

# Download and extract backend into src/lerobot/webui/
if [ -d "$WEBUI_DIR/backend" ]; then
  echo "Backend already present at src/lerobot/webui/backend, skipping download."
else
  echo "Downloading backend..."
  curl -L --fail --progress-bar -o "/tmp/backend.tar.gz" "$BACKEND_URL"
  echo "Extracting backend..."
  tar -xzf "/tmp/backend.tar.gz" -C "$WEBUI_DIR"
  rm "/tmp/backend.tar.gz"
  echo "Backend extracted to src/lerobot/webui/backend"
fi

# Download standalone requirements into repo root
if [ -f "$REPO_DIR/standalone-requirements.txt" ]; then
  echo "standalone-requirements.txt already present, skipping download."
else
  echo "Downloading standalone-requirements.txt..."
  curl -L --fail --progress-bar -o "$REPO_DIR/standalone-requirements.txt" "$REQUIREMENTS_URL"
fi

echo ""

# Download and extract standalone Python into repo root
if [ -d "$PYTHON_DIR" ]; then
  echo "Python already installed at $PYTHON_DIR, skipping download."
else
  echo "Downloading Python ${PYTHON_VERSION} for ${TRIPLE}..."
  curl -L --fail --progress-bar -o "/tmp/${PYTHON_FILENAME}" "$PYTHON_URL"
  echo "Extracting..."
  tar -xzf "/tmp/${PYTHON_FILENAME}" -C "$REPO_DIR"
  rm "/tmp/${PYTHON_FILENAME}"
  echo "Python installed at $PYTHON_DIR"
fi

# Create venv using the standalone Python (isolates packages from system)
if [ -d "$REPO_DIR/.venv" ]; then
  echo "Virtual environment already exists at $REPO_DIR/.venv, skipping creation."
else
  echo "Creating virtual environment..."
  "$PYTHON_DIR/bin/python3" -m venv "$REPO_DIR/.venv"
  echo "Virtual environment created at $REPO_DIR/.venv"
fi

# Install dependencies into the venv
# WARNING: Large install (~2-4GB with PyTorch). First run takes time.
echo ""
echo "Installing dependencies (this may take 5-15 minutes, ~2-4GB download)..."
"$REPO_DIR/.venv/bin/pip" install --upgrade pip
"$REPO_DIR/.venv/bin/pip" install -r "$REPO_DIR/standalone-requirements.txt"

# Install lerobot from local repo source so MakerMods-specific scripts are available
echo "Installing lerobot from source..."
"$REPO_DIR/.venv/bin/pip" install -e "$REPO_DIR"

# Write run.sh into the repo root
cat > "$REPO_DIR/run.sh" << 'EOF'
#!/bin/bash
set -e

MAIN_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON="$MAIN_DIR/.venv/bin/python3"

if [ ! -f "$PYTHON" ]; then
  echo "Error: .venv not found. Run install.sh first."
  exit 1
fi

echo "Starting LeRobot UI at http://localhost:8000"
cd "$MAIN_DIR/src/lerobot/webui"
exec "$PYTHON" -m backend.main
EOF
chmod +x "$REPO_DIR/run.sh"

echo ""
echo "=========================================="
echo "Installation complete!"
echo ""
echo "Run the app:  cd $REPO_NAME && ./run.sh"
echo "Dev/inspect:  cd $REPO_NAME && source .venv/bin/activate"
echo "=========================================="
