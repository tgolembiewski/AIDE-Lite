#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# AIDE-Lite Build Bridge — Mac → Parallels Windows 11
# ============================================================
# WARNING: VM_NAME and HELPER_SCRIPT below are hardcoded to a
# specific developer's Parallels setup. You MUST update them to
# match your local environment before use. This is a personal
# dev helper, not part of the core extension.
# ============================================================
# Orchestrates build/deploy via prlctl exec into the Parallels VM.
# Usage: ./build.sh [all|build|rebuild|quick|close|deploy|launch|status]

VM_NAME="Windows 11"
HELPER_SCRIPT='C:\Users\tomekgolembiewski\ClaudeWinProjects\AIDE-Lite\build-helper.ps1'

# macOS Studio Pro paths
MAC_STUDIO_PRO="/Applications/Studio Pro 11.6.0 Beta.app"
MAC_MENDIX_PROJECT="$HOME/Mendix/AtlasDesignRework-main/AtlasDesignRework.mpr"
MAC_EXTENSION_UUID="94258254-b046-4cc6-9bda-e65009560cac"

# Source paths (shared volume)
SRC_WEBASSETS="/Volumes/[C] Windows 11/Users/tomekgolembiewski/ClaudeWinProjects/AIDE-Lite/src/WebAssets"
WIN_BUILD_OUTPUT="/Volumes/[C] Windows 11/Users/tomekgolembiewski/ClaudeWinProjects/AIDE-Lite/src/bin/Release/net8.0-windows"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# ============================================================
# Run a step inside the Parallels VM
# ============================================================
run_step() {
    local step="$1"
    local label="$2"

    echo -e "${CYAN}>>> ${label}${NC}"

    prlctl exec "$VM_NAME" --current-user \
        powershell -ExecutionPolicy Bypass \
        -Command "& '$HELPER_SCRIPT' -Step '$step'; exit \$LASTEXITCODE"

    local rc=$?
    if [ $rc -ne 0 ]; then
        echo -e "${RED}>>> FAILED: ${label} (exit code ${rc})${NC}"
        exit $rc
    fi
    echo ""
}

# ============================================================
# Subcommands
# ============================================================
cmd_all() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  AIDE-Lite: Full Build & Deploy Cycle  ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    run_step "close"  "Close Studio Pro"
    run_step "build"  "Build AIDE-Lite"
    run_step "deploy" "Deploy to Extensions"
    run_step "launch" "Launch Studio Pro"
    echo -e "${GREEN}>>> All done!${NC}"
}

cmd_build() {
    run_step "build" "Build AIDE-Lite"
}

cmd_rebuild() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  AIDE-Lite: Rebuild (no launch)        ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    run_step "close"  "Close Studio Pro"
    run_step "build"  "Build AIDE-Lite"
    run_step "deploy" "Deploy to Extensions"
    echo -e "${GREEN}>>> Rebuild complete. Run './build.sh launch' when ready.${NC}"
}

cmd_quick() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  AIDE-Lite: Quick Deploy               ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${YELLOW}>>> Assumes Studio Pro is already closed${NC}"
    echo ""
    run_step "build"  "Build AIDE-Lite"
    run_step "deploy" "Deploy to Extensions"
    echo -e "${GREEN}>>> Quick deploy complete. Run './build.sh launch' when ready.${NC}"
}

cmd_close() {
    run_step "close" "Close Studio Pro"
}

cmd_deploy() {
    run_step "deploy" "Deploy to Extensions"
}

cmd_launch() {
    run_step "launch" "Launch Studio Pro"
}

cmd_status() {
    run_step "status" "AIDE-Lite Status"
}

# ============================================================
# macOS Studio Pro commands
# ============================================================
mac_close() {
    echo -e "${CYAN}>>> Close macOS Studio Pro${NC}"
    local pid
    pid=$(pgrep -x studiopro 2>/dev/null || true)
    if [ -n "$pid" ]; then
        echo -e "${YELLOW}Stopping macOS Studio Pro (PID: $pid)...${NC}"
        kill "$pid" 2>/dev/null || true
        # Wait up to 10 seconds for clean shutdown
        for i in $(seq 1 10); do
            if ! pgrep -x studiopro >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done
        # Force kill if still running
        if pgrep -x studiopro >/dev/null 2>&1; then
            kill -9 "$pid" 2>/dev/null || true
            sleep 1
        fi
        echo -e "${GREEN}macOS Studio Pro stopped.${NC}"
    else
        echo -e "${GRAY}macOS Studio Pro is not running.${NC}"
    fi
    echo ""
}

mac_deploy() {
    echo -e "${CYAN}>>> Deploy to macOS extension cache${NC}"

    # Deploy to the extensions-cache inside the Mendix project.
    # Studio Pro clears this on startup, so when used with mac_launch,
    # we deploy AFTER Studio Pro has started and cleared the cache.
    local cache_dir
    cache_dir="$(dirname "$MAC_MENDIX_PROJECT")/.mendix-cache/extensions-cache/$MAC_EXTENSION_UUID"
    echo -e "${GRAY}Target: $cache_dir${NC}"

    mkdir -p "$cache_dir"

    # Copy DLL and deps from Windows build output (via shared volume)
    if [ -f "$WIN_BUILD_OUTPUT/AideLite.dll" ]; then
        cp "$WIN_BUILD_OUTPUT/AideLite.dll" "$cache_dir/"
        cp "$WIN_BUILD_OUTPUT/AideLite.deps.json" "$cache_dir/"
        echo -e "${GRAY}Copied DLL + deps from Windows build output${NC}"
    else
        echo -e "${RED}ERROR: No Windows build output found at $WIN_BUILD_OUTPUT${NC}"
        exit 1
    fi

    # Copy manifest
    cp "/Volumes/[C] Windows 11/Users/tomekgolembiewski/ClaudeWinProjects/AIDE-Lite/src/manifest.json" "$cache_dir/"

    # Copy WebAssets (always from source — these are the latest)
    rm -rf "$cache_dir/WebAssets"
    cp -R "$SRC_WEBASSETS" "$cache_dir/WebAssets"

    local file_count
    file_count=$(find "$cache_dir" -type f | wc -l | tr -d ' ')
    echo -e "${GREEN}Deployed $file_count files to macOS extension cache.${NC}"
    echo ""
}

mac_launch() {
    echo -e "${CYAN}>>> Launch macOS Studio Pro${NC}"

    if ! [ -d "$MAC_STUDIO_PRO" ]; then
        echo -e "${RED}ERROR: Studio Pro not found at $MAC_STUDIO_PRO${NC}"
        exit 1
    fi
    if ! [ -f "$MAC_MENDIX_PROJECT" ]; then
        echo -e "${RED}ERROR: Mendix project not found at $MAC_MENDIX_PROJECT${NC}"
        exit 1
    fi

    # Check if already running
    if pgrep -x studiopro >/dev/null 2>&1; then
        echo -e "${YELLOW}WARNING: macOS Studio Pro is already running${NC}"
        exit 1
    fi

    echo -e "${GRAY}Opening: $MAC_MENDIX_PROJECT${NC}"
    open -a "$MAC_STUDIO_PRO" "$MAC_MENDIX_PROJECT"
    echo -e "${GREEN}macOS Studio Pro launched.${NC}"
    echo ""
}

cmd_mac() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  AIDE-Lite: macOS Build & Deploy       ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    mac_close
    run_step "build"  "Build AIDE-Lite (via Windows)"
    mac_launch
    echo -e "${CYAN}>>> Waiting for Studio Pro to initialize cache...${NC}"
    sleep 5
    mac_deploy
    echo -e "${GREEN}>>> All done! (macOS)${NC}"
    echo -e "${YELLOW}>>> Reopen the project in Studio Pro to load AIDE Lite${NC}"
}

cmd_mac_quick() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  AIDE-Lite: macOS Quick Deploy         ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "${YELLOW}>>> WebAssets only (no DLL rebuild)${NC}"
    echo ""
    mac_close
    mac_launch
    echo -e "${CYAN}>>> Waiting for Studio Pro to initialize cache...${NC}"
    sleep 5
    mac_deploy
    echo -e "${GREEN}>>> All done! (macOS quick)${NC}"
    echo -e "${YELLOW}>>> Reopen the project in Studio Pro to load AIDE Lite${NC}"
}

cmd_mac_deploy() {
    mac_deploy
}

cmd_mac_close() {
    mac_close
}

cmd_mac_launch() {
    mac_launch
}

cmd_both() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  AIDE-Lite: Build & Deploy (Both)      ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    run_step "close"  "Close Windows Studio Pro"
    mac_close
    run_step "build"  "Build AIDE-Lite"
    run_step "deploy" "Deploy to Windows Extensions"
    mac_deploy
    run_step "launch" "Launch Windows Studio Pro"
    mac_launch
    echo -e "${GREEN}>>> All done! (Windows + macOS)${NC}"
}

# ============================================================
# Usage
# ============================================================
usage() {
    echo -e "${CYAN}AIDE-Lite Build Bridge${NC} — Mac → Parallels"
    echo ""
    echo "Usage: ./build.sh <command>"
    echo ""
    echo "Windows commands:"
    echo "  all        Full workflow: close → build → deploy → launch"
    echo "  build      Build only (check for compile errors)"
    echo "  rebuild    Close → build → deploy (no launch)"
    echo "  quick      Build → deploy (assumes Studio Pro already closed)"
    echo "  close      Close Studio Pro + remove lock file"
    echo "  deploy     Copy build output to Extensions folder"
    echo "  launch     Launch Studio Pro with project"
    echo "  status     Check Studio Pro state and deployment info"
    echo ""
    echo "macOS commands:"
    echo "  mac        Full workflow: close → build → deploy → launch (macOS SP 11.6)"
    echo "  mac-quick  WebAssets-only deploy (no DLL rebuild, fastest)"
    echo "  mac-deploy Deploy to macOS extension cache only"
    echo "  mac-close  Close macOS Studio Pro"
    echo "  mac-launch Launch macOS Studio Pro"
    echo ""
    echo "Cross-platform:"
    echo "  both       Build once, deploy to Windows + macOS, launch both"
    echo ""
}

# ============================================================
# Dispatch
# ============================================================
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

case "$1" in
    all)        cmd_all ;;
    build)      cmd_build ;;
    rebuild)    cmd_rebuild ;;
    quick)      cmd_quick ;;
    close)      cmd_close ;;
    deploy)     cmd_deploy ;;
    launch)     cmd_launch ;;
    status)     cmd_status ;;
    mac)        cmd_mac ;;
    mac-quick)  cmd_mac_quick ;;
    mac-deploy) cmd_mac_deploy ;;
    mac-close)  cmd_mac_close ;;
    mac-launch) cmd_mac_launch ;;
    both)       cmd_both ;;
    -h|--help|help)
        usage ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        usage
        exit 1
        ;;
esac
