#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${MONO_DIR}/.." && pwd)"
BUILD_DIR="${MONO_DIR}/build"

GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

mkdir -p "${BUILD_DIR}"
cd "${ROOT_DIR}"

OUT_VVP="${BUILD_DIR}/mips_monociclo_top.vvp"

SRC_FILES=(
    "src/datapath/pc.v"
    "src/datapath/adder.v"
    "src/datapath/mux2to1.v"
    "src/datapath/mux3to1.v"
    "src/datapath/mux4to1.v"
    "src/datapath/sign_extend.v"
    "src/datapath/reg_file.v"
    "src/datapath/alu.v"
    "src/control/main_control.v"
    "src/control/alu_control.v"
    "src/control/control_unit.v"
    "src/memory/instr_mem.v"
    "src/memory/data_mem.v"
    "monociclo/src/datapath_monociclo.v"
    "monociclo/src/mips_monociclo_top.v"
)

TB_FILE="monociclo/tb/tb_mips_monociclo_top.v"

echo -e "${BLUE}==>${RESET} Compilando mips_monociclo_top (Legado) com Icarus Verilog..."
iverilog -g2012 -Wall -o "${OUT_VVP}" "${SRC_FILES[@]}" "${TB_FILE}"

echo -e "${BLUE}==>${RESET} Executando simulação do Monociclo..."
vvp "${OUT_VVP}"

echo -e "${GREEN}[OK]${RESET} Simulação do Monociclo concluída com sucesso."
