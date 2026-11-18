#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VCD_FILE="${MONO_DIR}/build/mips_monociclo_top.vcd"

RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

if [[ ! -f "${VCD_FILE}" ]]; then
    echo -e "${RED}[ERRO]${RESET} Arquivo ${VCD_FILE} não encontrado."
    echo "Execute primeiro: ./scripts/run_simulation_monociclo.sh"
    exit 1
fi

echo -e "${BLUE}==>${RESET} Abrindo GTKWave para MIPS Monociclo: ${VCD_FILE}"
gtkwave "${VCD_FILE}" > /dev/null 2>&1 &
