#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUARTUS_DIR="${1:-}"
REVISION="${2:-}"

if [[ -z "${QUARTUS_DIR}" || -z "${REVISION}" ]]; then
    echo "Uso: $0 <diretorio_quartus> <revisao>" >&2
    exit 1
fi

TARGET_DIR="${ROOT_DIR}/${QUARTUS_DIR}"
mkdir -p "${TARGET_DIR}/assembly-mips"
cp "${ROOT_DIR}/assembly-mips/sort.bin" "${TARGET_DIR}/assembly-mips/"

cd "${TARGET_DIR}"
echo "==> [${REVISION}] [1/4] Análise e Síntese (quartus_map)..."
quartus_map "${REVISION}"
echo "==> [${REVISION}] [2/4] Mapeamento e Roteamento (quartus_fit)..."
quartus_fit "${REVISION}"
echo "==> [${REVISION}] [3/4] Geração do Bitstream .sof (quartus_asm)..."
quartus_asm "${REVISION}"
echo "==> [${REVISION}] [4/4] Análise Temporal Estática — Fmax (quartus_sta)..."
quartus_sta "${REVISION}"
echo "[OK] Síntese completa concluída em ${QUARTUS_DIR}/output_files/${REVISION}.*"
