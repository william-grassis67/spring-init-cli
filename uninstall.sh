#!/usr/bin/env bash
#
# uninstall.sh - Removes spring-init from the locations installed by
# install.sh. Does NOT remove user configuration unless explicitly confirmed.
#
set -Eeuo pipefail

USER_BIN_DIR="${HOME}/.local/bin"
SYSTEM_BIN_DIR="/usr/local/bin"
CONFIG_DIR="${HOME}/.config/spring-init"

GREEN=""; YELLOW=""; CYAN=""; BOLD=""; RESET=""
if [[ -t 1 ]]; then
    GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'
    BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

info() { printf '%s->%s %s\n' "${CYAN}" "${RESET}" "$1"; }
ok()   { printf '%s✓%s %s\n' "${GREEN}" "${RESET}" "$1"; }
warn() { printf '%s!%s %s\n' "${YELLOW}" "${RESET}" "$1"; }

printf '%s%sspring-init uninstaller%s\n\n' "${BOLD}" "${CYAN}" "${RESET}"

removed_any=0

if [[ -f "${USER_BIN_DIR}/spring-init" ]]; then
    rm -f "${USER_BIN_DIR}/spring-init"
    ok "Removido: ${USER_BIN_DIR}/spring-init"
    removed_any=1
fi

if [[ -f "${SYSTEM_BIN_DIR}/spring-init" ]]; then
    info "Encontrado em ${SYSTEM_BIN_DIR} (requer sudo para remover)."
    if sudo rm -f "${SYSTEM_BIN_DIR}/spring-init"; then
        ok "Removido: ${SYSTEM_BIN_DIR}/spring-init"
        removed_any=1
    fi
fi

if [[ "${removed_any}" -eq 0 ]]; then
    warn "Nenhuma instalação de spring-init encontrada nos locais padrão."
fi

if [[ -d "${CONFIG_DIR}" ]]; then
    echo
    read -r -p "Remover também as configurações em ${CONFIG_DIR}? [y/N] " answer
    case "${answer}" in
        y|Y|yes|YES|s|S|sim|SIM)
            rm -rf -- "${CONFIG_DIR}"
            ok "Configurações removidas."
            ;;
        *)
            info "Configurações mantidas em ${CONFIG_DIR}."
            ;;
    esac
fi

echo
ok "Desinstalação concluída."
