#!/usr/bin/env bash
# Install the cocotb + Verilator toolchain for the housekeeper verification
# environment, without requiring root.
#
#   ./verification/setup-tools.sh
#
# Installs:
#   - a Python virtualenv at <repo>/.venv-verif with cocotb, pytest, PyYAML
#   - Verilator (via micromamba, into ~/.local/opt/micromamba/envs/eda)
#
# If you already have Verilator >= 5.020 on your PATH (e.g. from
# `sudo apt install verilator`), pass --skip-verilator.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$REPO_ROOT/.venv-verif"
MAMBA_ROOT="$HOME/.local/opt/micromamba"
SHIM_DIR="$HOME/.local/opt/eda-shim"
SKIP_VERILATOR=0

for arg in "$@"; do
    case "$arg" in
        --skip-verilator) SKIP_VERILATOR=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

# micromamba, fetched into the user's home. Used for Verilator, and for a
# Python where the system one cannot make virtualenvs. Defined as a function
# because both callers need it and only the first one to run should fetch it.
install_micromamba() {
    mkdir -p "$MAMBA_ROOT/bin"
    if [ ! -x "$MAMBA_ROOT/bin/micromamba" ]; then
        curl -sSL https://micro.mamba.pm/api/micromamba/linux-64/latest \
            | tar -xj -C "$MAMBA_ROOT" bin/micromamba
    fi
}

# A Python that can create a virtualenv.
#
# `python3 -m venv` needs `ensurepip`, which Debian and Ubuntu split into a
# separate `python3.N-venv` package. Without it the failure is a wall of text
# about `ensurepip is not available` from inside a half-built directory, and
# the obvious reading -- "install python3-venv" -- needs root, which this
# script otherwise never does.
#
# So it checks first, and falls back to a micromamba Python rather than
# stopping. The virtualenv lands in the same place either way, so nothing
# downstream knows the difference.
VENV_PYTHON=python3
if ! python3 -c "import ensurepip" >/dev/null 2>&1; then
    echo "==> $(python3 -V) cannot create virtualenvs: ensurepip is missing."
    echo "    On Debian and Ubuntu that is the python3-venv package, which"
    echo "    needs root:"
    echo ""
    echo "        sudo apt install python3-venv"
    echo ""
    echo "    Falling back to a micromamba Python instead, which does not."
    install_micromamba
    MAMBA_ROOT_PREFIX="$MAMBA_ROOT" "$MAMBA_ROOT/bin/micromamba" \
        create -y -n verif-python -c conda-forge python=3.12 >/dev/null
    VENV_PYTHON="$MAMBA_ROOT/envs/verif-python/bin/python"
    echo "    using $("$VENV_PYTHON" -V) from $VENV_PYTHON"
fi

echo "==> Creating Python virtualenv at $VENV"
rm -rf "$VENV"
"$VENV_PYTHON" -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
# The group's own tools are private. Fetch them over SSH, with the key you push
# with, by rewriting their HTTPS URLs for this one command -- nothing is changed
# in your git configuration. CI sets its own rewrite (job token) and keeps it.
if [ -z "${GIT_CONFIG_COUNT:-}" ]; then
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0="url.git@gitlab.com:turionspace/.insteadOf"
    export GIT_CONFIG_VALUE_0="https://gitlab.com/turionspace/"
fi
"$VENV/bin/pip" install --quiet -r "$REPO_ROOT/verification/requirements.txt"
echo "    $("$VENV/bin/python" -c 'import cocotb; print("cocotb", cocotb.__version__)')"

if [ "$SKIP_VERILATOR" -eq 1 ]; then
    echo "==> Skipping Verilator install (--skip-verilator)"
elif command -v verilator >/dev/null 2>&1; then
    echo "==> Verilator already on PATH: $(verilator --version)"
else
    echo "==> Installing Verilator via micromamba (no root required)"
    install_micromamba
    MAMBA_ROOT_PREFIX="$MAMBA_ROOT" "$MAMBA_ROOT/bin/micromamba" create -y -n eda -c conda-forge verilator

    # Verilator's build step shells out to `python3` for verilator_includer.
    # The conda environment ships its own Python, which picks up the system
    # standard library and dies with "SRE module mismatch". Putting a stable
    # python3 ahead of the conda environment on PATH avoids that.
    echo "==> Creating python3 shim at $SHIM_DIR"
    mkdir -p "$SHIM_DIR"
    ln -sf "$VENV_PYTHON" "$SHIM_DIR/python3"

    echo "    $("$MAMBA_ROOT/envs/eda/bin/verilator" --version)"
fi

cat <<EOF

Toolchain ready.

    make test          run the verification suite
    make test-fast     only the checks that need no simulator, in a second
    make coverage      where each requirement stands
    make check         whether the results should block a merge

Note: the ModelSim/ModelSimPro bundled with Libero is a 32-bit build and cannot
be used with cocotb. The 64-bit QuestaSim shipped with Libero SoC 2021+ works
and is detected automatically.
EOF
