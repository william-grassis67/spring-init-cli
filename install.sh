#!/usr/bin/env bash
#
# install.sh - Installs spring-init for the current user (no sudo required
# by default), or system-wide if the user explicitly chooses that option.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SOURCE_FILE="${SCRIPT_DIR}/spring-init"

USER_BIN_DIR="${HOME}/.local/bin"
SYSTEM_BIN_DIR="/usr/local/bin"

RED=""; GREEN=""; YELLOW=""; CYAN=""; BOLD=""; RESET=""
if [[ -t 1 ]]; then
    RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
    CYAN=$'\033[36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

info()    { printf '%s->%s %s\n' "${CYAN}" "${RESET}" "$1"; }
ok()      { printf '%s✓%s %s\n' "${GREEN}" "${RESET}" "$1"; }
warn()    { printf '%s!%s %s\n' "${YELLOW}" "${RESET}" "$1"; }
fail()    { printf '%s✗%s %s\n' "${RED}" "${RESET}" "$1" >&2; exit 1; }

if [[ ! -f "${SOURCE_FILE}" ]]; then
    fail "Não encontrei o arquivo 'spring-init' em ${SCRIPT_DIR}."
fi

printf '%s%sspring-init installer%s\n\n' "${BOLD}" "${CYAN}" "${RESET}"
echo "Onde deseja instalar?"
echo "  1) Usuário atual  (${USER_BIN_DIR})  [recomendado, sem sudo]"
echo "  2) Todo o sistema (${SYSTEM_BIN_DIR})  [requer sudo]"
read -r -p "Escolha [1]: " choice
choice="${choice:-1}"

case "${choice}" in
    2)
        TARGET_DIR="${SYSTEM_BIN_DIR}"
        NEED_SUDO=1
        ;;
    *)
        TARGET_DIR="${USER_BIN_DIR}"
        NEED_SUDO=0
        ;;
esac

TARGET_FILE="${TARGET_DIR}/spring-init"

if [[ "${NEED_SUDO}" -eq 1 ]]; then
    info "Instalando em ${TARGET_DIR} (requer sudo)..."
    sudo mkdir -p "${TARGET_DIR}"
    sudo cp -f "${SOURCE_FILE}" "${TARGET_FILE}"
    sudo chmod +x "${TARGET_FILE}"
else
    info "Instalando em ${TARGET_DIR}..."
    mkdir -p "${TARGET_DIR}"
    cp -f "${SOURCE_FILE}" "${TARGET_FILE}"
    chmod +x "${TARGET_FILE}"
fi

ok "spring-init instalado em ${TARGET_FILE}"

if [[ "${NEED_SUDO}" -eq 0 ]]; then
    case ":${PATH}:" in
        *":${USER_BIN_DIR}:"*)
            ok "${USER_BIN_DIR} já está no PATH."
            ;;
        *)
            warn "${USER_BIN_DIR} não está no seu PATH."
            echo
            echo "Adicione a linha abaixo ao seu ~/.bashrc (ou ~/.zshrc) e reabra o terminal:"
            echo
            printf '  %sexport PATH="%s:$PATH"%s\n\n' "${BOLD}" "${USER_BIN_DIR}" "${RESET}"
            ;;
    esac
fi

echo
ok "Instalação concluída!"
echo
echo "Teste com:"
echo "  spring-init --version"
echo "  spring-init"
