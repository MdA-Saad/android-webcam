#!/bin/bash


# ======================================================================
# android-webcam - MIT License
#
# This script uses scrcpy (Apache 2.0) and v4l2loopback (GPL 2.0) 
# See CREDITS.md for full license details.
# ======================================================================


set -euo pipefail

echo "Android Webcam - Installer"

# REQUIRED VERSIONS
DESIRED_SCRCPY="2.0"
DESIRED_ADB="30.0.0"
DESIRED_V4L2="0.12.0"
DESIRED_ZENITY="3.00"

# VARIABLES
PACKAGE_MANAGER=""
# checks if the requirement are satisfied or not
IS_REQUIRED_VERSION_V4L2="false"
IS_REQUIRED_VERSION_SCRCPY="false"
NEEDS_REBOOT="false"
USER_DESKTOP=$(xdg-user-dir DESKTOP || echo "$HOME/Desktop")

# PATHS FOR SCRCPY APP and SERVER
PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
BUILD_PACKAGES="$PROJECT_ROOT/build-packages"
ICON_FILE="$PROJECT_ROOT/assets/android-webcam.png" # using system icons
APP_PATH="$PROJECT_ROOT/UI/start-up.sh"

# Function to compare versions
version_ge() {
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# Function to detect distro
detect_distro() {
    if command -v apt &>/dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v pacman &>/dev/null; then
        PACKAGE_MANAGER="pacman"
    else
        PACKAGE_MANAGER="unknown distro"
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
    local build_path="$BUILD_PACKAGES/scrcpy"
    if [ -x "$build_path" ]; then
        echo "Found local scrcpy build at "$build_path
        check_executable "$build_path" "$build_path --version" '^scrcpy [0-9]+\.[0-9]+(\.[0-9]+)?' "$DESIRED_SCRCPY"
        return $?
    fi
    check_executable "scrcpy" "scrcpy --version" '^scrcpy [0-9]+\.[0-9]+(\.[0-9]+)?' "$DESIRED_SCRCPY"
}

# Check adb package and its version
check_adb() { 
    check_executable "adb" "adb --version" '[0-9]+\.[0-9]+\.[0-9]+' "$DESIRED_ADB"
}

check_zenity(){
    check_executable "zenity" "zenity --version" '[0-9]+\.[0-9]+(\.[0-9]+)?' "$DESIRED_ZENITY"
}

check_v4l2() {
    local desired=$DESIRED_V4L2
    local version=""

    if modinfo v4l2loopback &>/dev/null; then
        version=$(modinfo v4l2loopback | grep "^version:" | awk '{print $2}' | \
            grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' || echo "")

        if lsmod | grep -q v4l2loopback; then
            echo "[OK] v4l2loopback: currently loaded (Version: ${version:-unknown})"
        else
            echo "[OK] v4l2loopback: installed but not loaded (Version: ${version:-unknown})"
        fi
    else
        echo "[WARN] v4l2loopback: Not found in system."
        return 1
    fi

    # Compare versions
    if [ -n "$version" ]; then
        if version_ge "$version" "$desired"; then
            echo "v4l2loopback: loaded version $version (OK, meets desired $desired)"
            IS_REQUIRED_VERSION_V4L2="true"
            return 0
        else
            echo "v4l2loopback: loaded version $version (OLDER, than desired $desired)"
            return 2
        fi
    else
        echo "[WARN] v4l2loopback: Installed, but version could not be verified."
        IS_REQUIRED_VERSION_V4L2="true"
        return 0
    fi
}

# ------------------------------------------------------------------
# REPOSITORY FUNCTIONS
# ------------------------------------------------------------------

check_repo_version() {
    local pkg=$1
    local version=""

    if [ "$PACKAGE_MANAGER" = "unknown" ] || [ -z "$PACKAGE_MANAGER" ]; then
        return 1
    fi

    case $PACKAGE_MANAGER in
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
    echo "Attempting to install $pkg via $PACKAGE_MANAGER..."
    case $PACKAGE_MANAGER in
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
    local var_to_update="${4:-}" # This is optional parameter

    echo ">>> Checking dependency: $pkg_name"
    
    # Run the specific check function (e.g., check_scrcpy)
    local status=0
    $check_func || status=$?

    # If status is 0, its already installed and up to date. We can skip.
    if [ $status -eq 0 ]; then
        if [ -n "$var_to_update" ]; then
            local -n var_ref=$var_to_update # This is dependency flag
            var_ref=true
        fi
        return 0
    fi

    # If it's missing or too old, we check the package manager
    echo "--- Looking for $pkg_name in $PACKAGE_MANAGER repositories..."
    local repo_ver=$(check_repo_version "$pkg_name")
    
    if [ -n "$repo_ver" ] && version_ge "$repo_ver" "$desired_version" ; then
        echo "--> Found suitable version ($repo_ver) in repo. Installing..."
        install_package "$pkg_name"
        if [ -n "$var_to_update" ]; then
            local -n var_ref=$var_to_update
            var_ref=true
        fi
        return 0 # Exit with success
    fi
    
    # Fallback: Build from source (Only for scrcpy)
    if [ $pkg_name == "scrcpy" ]; then
        if [ -z $repo_ver ]; then
            echo "--> $pkg_name is missing in $PACKAGE_MANAGER. Triggering local build..."
        else
            echo "Version of $pkg_name available in repo is too old ($repo_ver). Triggering local build ..."
        fi

        if [ -f "$PROJECT_ROOT/scripts/build-scrcpy.sh" ]; then
            chmod +x "$PROJECT_ROOT/scripts/build-scrcpy.sh"
            "$PROJECT_ROOT/scripts/build-scrcpy.sh"

            if $check_func && [ -n "$var_to_update" ]; then
                local -n var_ref=$var_to_update
                var_ref=true
            fi

            if $check_func; then
                echo "[OK] scrcpy built and verified locally."
                return 0
            else
                echo "!!! ERROR: Build finished but verification failed."
                return 1
            fi
        else
            echo "!!! ERROR: build-scrcpy.sh not found in $PROJECT_ROOT/scripts/"
            return 1
        fi
    fi

    # Error handling for other packages
    if [ -z "$repo_ver" ]; then
        echo "!!! ERROR: '$pkg_name' is not available in your package manager."
    else
        echo "--> The $pkg_name in your repo ($repo_ver) is OLDER than desired ($desired_version)."
    fi
    echo "!!! PLEASE INSTALL MANUALLY third-party repositories or build from source."
    echo ""
    return 1
}

# ------------------------------------------------------------------
# MAIN EXECUTION
# ------------------------------------------------------------------

detect_distro # Function call to detect the distro

if [ "$PACKAGE_MANAGER" = "unknown" ]; then
    echo "Unsupported distribution. Please install dependencies manually."
    exit 1
fi

echo "=== Resolving Dependencies ==="
resolve_package "scrcpy" "$DESIRED_SCRCPY" "check_scrcpy" IS_REQUIRED_VERSION_SCRCPY
resolve_package "adb" "$DESIRED_ADB" "check_adb"
resolve_package "zenity" "$DESIRED_ZENITY" "check_zenity"
check_v4l2 || true

if [ -f "config.example.conf" ]; then
    echo "Creating config.conf from template..."
    cp "config.example.conf" "config.conf"
fi

# Adding user to video group so that they dont need sudo to use camera
if ! groups | grep -q video; then
    echo "Adding $USER to video group..."
    sudo usermod -aG video "$USER"
    sudo usermod -aG plugdev "$USER"
    NEEDS_REBOOT="true"
fi

if [ -f "$APP_PATH" ]; then
    cat <<EOF > android-webcam.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Webcam
Comment=Use android device as a webcam
Exec=env ADW_DISABLE_PORTAL=1 bash $APP_PATH
Icon=$ICON_FILE
Terminal=false
Categories=AudioVideo;Video;
EOF
    chmod +x android-webcam.desktop
    mkdir -p ~/.local/share/applications
    cp android-webcam.desktop "$USER_DESKTOP"
    cp android-webcam.desktop ~/.local/share/applications/

    echo "----------------------------------------------------------------"
    echo "Installation complete."
    echo "A shortcut has been added to your application Menu."

    echo "Next step: Please complete the next steps and connect your android device and run ./main.sh"
    echo "----------------------------------------------------------------"
else
    echo "[WARN] start-up file not found in current directory. Shortcut not created."
fi


if [ "$NEEDS_REBOOT" = "true" ]; then
    echo "[IMPORTANT] Please reboot to apply group permissions."
fi
if [ "$IS_REQUIRED_VERSION_V4L2" = "false" ]; then
    echo "[!] Reminder: Please install desired version of v4l2loopback for your distribution before the next step."
fi

if [ "$IS_REQUIRED_VERSION_SCRCPY" = "false" ]; then
    echo "[!] Reminder: Please install the latest version of scrcpy for your distribution"
fi


