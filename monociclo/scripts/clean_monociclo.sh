#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN="\033[0;32m"
BLUE="\033[0;34m"
RESET="\033[0m"

echo -e "${BLUE}==>${RESET} Limpando diretório de build do monociclo..."
rm -rf "${MONO_DIR}/build"
echo -e "${GREEN}[OK]${RESET} Build do monociclo limpo com sucesso."
