#!/usr/bin/env bash
# check_env.sh — Verify Python dependencies and UDP buffer sysctl settings,
#                offering to fix any issues that are found.

REQUIRED_BUFFER_SIZE=268435456  # 256 MB (must match receiver.py)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { echo -e "  ${GREEN}[✔]${RESET} $*"; }
fail() { echo -e "  ${RED}[✗]${RESET} $*"; }
warn() { echo -e "  ${YELLOW}[!]${RESET} $*"; }
info() { echo -e "  ${CYAN}[-]${RESET} $*"; }

ERRORS=0

# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  STEP 1 — Python interpreter${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════════${RESET}\n"

PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" &>/dev/null; then
        PYTHON="$candidate"
        PY_VER=$("$PYTHON" --version 2>&1)
        pass "Found $candidate  ($PY_VER)"
        break
    fi
done

if [[ -z "$PYTHON" ]]; then
    fail "No Python interpreter found (tried python3, python)"
    echo -e "\n${RED}Cannot continue without Python. Aborting.${RESET}\n"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  STEP 2 — Python library checks${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════════${RESET}\n"

# Format: "import_name pip_package_name kind(stdlib|pip)"
LIBS=(
    "socket          socket          stdlib"
    "argparse        argparse        stdlib"
    "os              os              stdlib"
    "time            time            stdlib"
    "struct          struct          stdlib"
    "subprocess      subprocess      stdlib"
    "sys             sys             stdlib"
    "collections     collections     stdlib"
    "queue           queue           stdlib"
    "threading       threading       stdlib"
    "signal          signal          stdlib"
    "glob            glob            stdlib"
    "pathlib         pathlib         stdlib"
    "dpkt            dpkt            pip"
    "numpy           numpy           pip"
    "cv2             opencv-python   pip"
)

MISSING_LIBS=()   # pip package names that need installing

for entry in "${LIBS[@]}"; do
    import_name=$(awk '{print $1}' <<< "$entry")
    pip_name=$(awk    '{print $2}' <<< "$entry")
    kind=$(awk        '{print $3}' <<< "$entry")

    if "$PYTHON" -c "import $import_name" 2>/dev/null; then
        ver=$("$PYTHON" -c "
import importlib.metadata as m
try:    print(m.version('$pip_name'))
except: print('')
" 2>/dev/null || true)
        [[ -n "$ver" ]] && ver=" v${ver}" || ver=""
        [[ "$kind" == "pip" ]] && label="(pip: $pip_name)" || label="(stdlib)"
        pass "$import_name${ver}  ${label}"
    else
        [[ "$kind" == "pip" ]] && label="(pip: $pip_name)" || label="(stdlib)"
        fail "$import_name  — NOT FOUND  ${label}"
        if [[ "$kind" == "pip" ]]; then
            MISSING_LIBS+=("$pip_name")
        fi
        (( ERRORS++ )) || true
    fi
done

# ── Offer to install missing pip packages ────────────────────────────────────
if [[ ${#MISSING_LIBS[@]} -gt 0 ]]; then
    echo ""
    warn "Missing pip packages: ${MISSING_LIBS[*]}"
    echo -ne "  ${BOLD}Install them now? [Y/n]:${RESET} "
    read -r answer </dev/tty
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        echo ""
        for pkg in "${MISSING_LIBS[@]}"; do
            info "Installing $pkg …"
            if sudo "$PYTHON" -m pip install "$pkg" --break-system-packages; then
                pass "$pkg installed successfully"
                (( ERRORS-- )) || true
            else
                fail "Failed to install $pkg"
            fi
        done
    else
        info "Skipping — install manually with:  pip install ${MISSING_LIBS[*]}"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  STEP 3 — UDP receive buffer (sysctl) settings${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════════${RESET}\n"

info "Required buffer size: ${REQUIRED_BUFFER_SIZE} bytes  ($(( REQUIRED_BUFFER_SIZE / 1024 / 1024 )) MB)"
echo ""

if ! command -v sysctl &>/dev/null; then
    warn "sysctl not found — cannot check buffer settings (non-Linux system?)"
else
    SYSCTL_KEYS_TO_FIX=()

    for key in net.core.rmem_max net.core.rmem_default; do
        current=$(sysctl -n "$key" 2>/dev/null || echo "UNKNOWN")

        if [[ "$current" == "UNKNOWN" ]]; then
            warn "$key  → could not read value"
            (( ERRORS++ )) || true
        elif (( current >= REQUIRED_BUFFER_SIZE )); then
            pass "$key = ${current}  ($(( current / 1024 / 1024 )) MB)  ✓ sufficient"
        else
            fail "$key = ${current}  ($(( current / 1024 / 1024 )) MB)  — too low  (need $(( REQUIRED_BUFFER_SIZE / 1024 / 1024 )) MB)"
            SYSCTL_KEYS_TO_FIX+=("$key")
            (( ERRORS++ )) || true
        fi
    done

    # ── Offer to fix sysctl settings via sudo ────────────────────────────────
    if [[ ${#SYSCTL_KEYS_TO_FIX[@]} -gt 0 ]]; then
        echo ""
        warn "Buffer settings need to be raised.  This requires sudo."
        echo -ne "  ${BOLD}Run sudo sysctl to fix them now? [Y/n]:${RESET} "
        read -r answer </dev/tty
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo ""
            ALL_FIXED=true
            for key in "${SYSCTL_KEYS_TO_FIX[@]}"; do
                info "Running: sudo sysctl -w ${key}=${REQUIRED_BUFFER_SIZE}"
                if sudo sysctl -w "${key}=${REQUIRED_BUFFER_SIZE}"; then
                    pass "$key updated (active until next reboot)"
                    (( ERRORS-- )) || true
                else
                    fail "Failed to update $key"
                    ALL_FIXED=false
                fi
            done
            if $ALL_FIXED; then
                echo ""
                SYSCTL_CONF="/etc/sysctl.d/99-udp-receiver.conf"
                info "Writing persistent config to ${SYSCTL_CONF} …"
                {
                    for key in "${SYSCTL_KEYS_TO_FIX[@]}"; do
                        echo "${key} = ${REQUIRED_BUFFER_SIZE}"
                    done
                } | sudo tee "$SYSCTL_CONF" > /dev/null \
                    && pass "${SYSCTL_CONF} written — settings will persist across reboots" \
                    || warn "Could not write ${SYSCTL_CONF} — changes are active now but will not survive a reboot"
            fi
        else
            info "Skipping — fix manually with:"
            for key in "${SYSCTL_KEYS_TO_FIX[@]}"; do
                info "  sudo sysctl -w ${key}=${REQUIRED_BUFFER_SIZE}"
            done
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  SUMMARY${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════════${RESET}\n"

if (( ERRORS <= 0 )); then
    echo -e "  ${GREEN}${BOLD}All checks passed — environment is ready.${RESET}\n"
    exit 0
else
    echo -e "  ${RED}${BOLD}${ERRORS} issue(s) remain — see details above.${RESET}\n"
    exit 1
fi