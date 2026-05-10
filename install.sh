#!/bin/bash
set -euo pipefail

echo "Android Webcam - Installer"
DESIRED_SCRCPY="2.0"
DESIRED_ADB="30.0.0"
DESIRED_V4L2="0.12.0"
pm=""
v4l2_installed=false
# Function to compare versions
version_ge() {
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# Function to detect distro
detect_distro() {
    if command -v apt &>/dev/null; then
        pm="apt"
    elif command -v dnf &>/dev/null; then
        pm="dnf"
    elif command -v pacman &>/dev/null; then
        pm="pacman"
    else
        pm="unknown distro"
    fi
}

#------------------------------------------------------------------
# CHECKING FUNCTIONS
# Return 0 = OK, Return 1 = Not Installed, Return 2 = Too Old
# -----------------------------------------------------------------

check_executable() {
    local name=$1
    local cmd=$2
    local regex=$3
    local desired=$4

    if command -v "${name%% *}" &>/dev/null || [ -x "$name" ]; then
        local version=$($cmd 2>&1 | grep -oE "$regex" | sort -V | tail -n1)
        if [ -n "$version" ]; then
            if version_ge "$version" "$desired"; then
                echo "[OK] $name: installed version $version (OK, meets desired $desired)"
                v4l2_installed=true
                return 0
            else
                echo "[WARN] $name: installed version $version (OLDER than desired $desired)"
                return 2
            fi
        else
            echo "[WARN] $name: installed but could not determine version"
            return 1
        fi
    else
        echo "[WARN] $name: not installed"
        return 1
    fi
}

# Check scrcpy package and its version
check_scrcpy() {
    local build_path="./build-packages/scrcpy/app/scrcpy"
    if [ -x "$build_path" ]; then
        echo "Found local scrcpy build at "$build_path
        check_executable "$build_path" "$build_path --version" '^scrcpy [0-9]+\.[0-9]+(\.[0-9]+)?' "$DESIRED_SCRCPY"
        return $?
    fi
    check_executable "scrcpy" "scrcpy --version" '^scrcpy [0-9]+\.[0-9]+(\.[0-9]+)?' "$DESIRED_SCRCPY"
}

# Check adb package and its version
check_adb() {
    local build_path="./build-packages/adb/adb"
    if [ -x "$build_path" ]; then
        echo "Found local adb build at "$build_path
        check_executable "$build_path" "$build_path --version" '[0-9]{2,}\.[0-9]+\.[0-9]+' "$DESIRED_ADB"
        return $?
    fi
    check_executable "adb" "adb --version" '[0-9]+\.[0-9]+\.[0-9]+' "$DESIRED_ADB"
}

check_v4l2() {
    local desired=$DESIRED_V4L2

    if lsmod | grep -q v4l2loopback; then
        local version=$(modinfo v4l2loopback 2>/dev/null | grep "^version:" | head -n1 | awk '{print$2}')
        if [ -n "$version" ]; then
            if version_ge "$version" "$desired"; then
                echo "v4l2loopback: loaded version $version (OK, meets desired $desired)"
                return 0
            else
                echo "v4l2loopback: loaded version $version (OLDER, than desired $desired)"
                return 2
            fi
        else
            echo "v4l2loopback: loaded but version unknown"
            return 1
        fi
    elif [ -f "/lib/modules/$(uname -r)/kernel/drivers/media/v4l2-loopback/v4l2loopback.ko" ] || \
        [ -f "/lib/modules/$(uname -r)/extra/v4l2loopback.ko" ]; then
        local version=$(modinfo v4l2loopback 2>/dev/null | grep "^version:" | awk '{print $2}')
        if [ -n "$version" ]; then
            echo "v4l2loopback: available (not loaded) version $version (OLDER than desired $desired)"
            return 2
        else
            echo "v4l2loopback: available (not loaded) but version unknown"
            return 1
        fi
    else
        echo "v4l2loopback: not installed"
        return 1
    fi
}

# ------------------------------------------------------------------
# REPOSITORY FUNCTIONS
# ------------------------------------------------------------------'

check_repo_version() {
    local pkg=$1
    local version=""

    if [ "$pm" = "unknown" ] || [ -z "$pm" ]; then
        return 1
    fi

    case $pm in
        apt)
            version=$(apt-cache policy "$pkg" 2>/dev/null | grep "Candidate:" | awk {'print $2}')
            ;;
        dnf)
            version=$(dnf list available "$pkg" 2>/dev/null | grep "$pkg" | awk '{print $2}' | head -n1)
            ;;
        pacman)
            # -Si checks the sync database (remote); Qi checks locally installed
            version=$(pacman -Si "$pkg" 2>/dev/null | grep "Version:" | awk {'print $3}' | cut -d'-' -f1)
            ;;
    esac

    if [ -n "$version" ]; then
        echo "$version"
    fi
}

install_package() {
    local pkg=$1
    echo "Attempting to install $pkg via $pm..."
    case $pm in
        apt) sudo apt update && sudo apt install -y "$pkg" ;;
        dnf) sudo dnf update && sudo dnf install -y "$pkg" ;;
        pacman) sudo pacman -Sy && sudo pacman -S --noconfirm "$pkg" ;;
    esac
}

# --------------------------------------------------------------------
# THE "GLUE" - RESOLVING DEPENDENCIES
# --------------------------------------------------------------------

resolve_package() {
    local pkg_name=$1
    local desired_version=$2
    local check_func=$3

    echo ">>> Checking dependency: $pkg_name"
    
    # Run the specific check function (e.g., check_scrcpy)
    local status=0
    $check_func || status=$?

    # If status is 0, its already installed and up to date. We can skip.
    if [ $status -eq 0 ]; then
        return 0
    fi

    # If it's missing or too old, we check the package manager
    echo "--- Looking for $pkg_name in $pm respositories..."
    local repo_ver=$(check_repo_version "$pkg_name")

    if [ -z "$repo_ver" ]; then
        echo "!!! ERROR: '$pkg_name' is not available in your package manager."
        echo "!!! PLEASE INSTALL MANUALLY from source or third-party repository."
        echo ""
        return 1
    fi
    
    # Compare the version available in the repo with our desired version
    if version_ge "$repo_ver" "$desired_version"; then
        echo "--> Found suitable version ($repo_ver) in repo. Installing..."
        install_package "$pkg_name"
    else
        echo "!!! ERROR: The version in your repo ($repo_ver) is too old (needs $desired_version)."
      echo "PLEASE INSTALL MANUALLY from source or a third-party repository."
        echo ""
        return 1
    fi
}

# ------------------------------------------------------------------
# MAIN EXECUTION
# ------------------------------------------------------------------

detect_distro

if [ "$pm" = "unknown" ]; then
    echo "Unsupported distribution. Please install dependencies manually."
    exit 1
fi

echo "=== Resolving Dependencies ==="
resolve_package "scrcpy" "$DESIRED_SCRCPY" "check_scrcpy"
resolve_package "adb" "$DESIRED_ADB" "check_adb"

if [ -f "config.example.conf" ]; then
    echo "Creating config.conf from template..."
    cp "config.example.conf" "config.conf"
fi

need_reboot=false
# Adding user to video group so that they dont need sudo to use camera
if ! groups | grep -q video; then
    echo "Adding $USER to video group..."
    sudo usermod -aG video "$USER"
    sudo usermod -aG plugdev "$USER"
    need_reboot=true
fi

if [ -f "start-webcam.sh" ]; then
    APP_PATH=$(realpath "start-webcam.sh")
    ICON_PATH="camera-web" # Standard system icon
    cat <<EOF > android-webcam.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Webcam
Comment=Use android device as a webcam
Exec=$APP_PATH
Icon=$ICON_PATH
Terminal=false
Categories=AudioVideo;Video;
EOF

    mkdir -p ~/.local/share/applications
    mv android-webcam.desktop ~/.local/share/applications/
    chmod +x ~/.local/share/applications/android-webcam.desktop
else
    echo "[WARN] start-webcam.sh not found in current directory. Shortcut not created."
fi

echo "----------------------------------------------------------------"
echo "Installation complete."
echo "A shortcut has been added to your application Menu."
if [ "$need_reboot" = true ]; then
    echo "[IMPORTANT] Please reboot to apply group permissions."
fi
if [ "$v4l2_installed" = false ]; then
    echo "[!] Reminder: Please install desired version of v4l2loopback for your distribution before the next step."
fi
echo "Next step: Connect your android device and run ./start-webcam.sh"
echo "----------------------------------------------------------------"

