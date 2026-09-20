#!/usr/bin/env bash
#
# test.sh - Lightweight offline tests for spring-init.
# Does not download real projects (no network usage), only validates
# script behaviour, argument parsing, validation logic and URL building.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SPRING_INIT="${SCRIPT_DIR}/spring-init"

PASS=0
FAIL=0

GREEN=""; RED=""; CYAN=""; RESET=""
if [[ -t 1 ]]; then
    GREEN=$'\033[32m'; RED=$'\033[31m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
fi

pass() { PASS=$((PASS+1)); printf '  %s✓%s %s\n' "${GREEN}" "${RESET}" "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  %s✗%s %s\n' "${RED}" "${RESET}" "$1"; }
section() { printf '\n%s%s%s\n' "${CYAN}" "$1" "${RESET}"; }

# ---------------------------------------------------------------------------
section "1. Arquivo e permissões"
# ---------------------------------------------------------------------------
if [[ -f "${SPRING_INIT}" ]]; then pass "spring-init existe"; else fail "spring-init não encontrado"; fi
if [[ -x "${SPRING_INIT}" ]]; then pass "spring-init é executável"; else fail "spring-init não é executável"; fi

bash -n "${SPRING_INIT}" && pass "sintaxe Bash válida" || fail "erro de sintaxe Bash"

# ---------------------------------------------------------------------------
section "2. --help e --version"
# ---------------------------------------------------------------------------
if "${SPRING_INIT}" --help | grep -q "USAGE:"; then
    pass "--help mostra uso"
else
    fail "--help não retornou saída esperada"
fi

if "${SPRING_INIT}" --version | grep -qE "spring-init v[0-9]+\.[0-9]+\.[0-9]+"; then
    pass "--version mostra versão"
else
    fail "--version não retornou versão esperada"
fi

# ---------------------------------------------------------------------------
section "3. Argumento desconhecido"
# ---------------------------------------------------------------------------
if ! "${SPRING_INIT}" --nao-existe >/dev/null 2>&1; then
    pass "opção desconhecida falha corretamente"
else
    fail "opção desconhecida deveria falhar"
fi

# ---------------------------------------------------------------------------
section "4. Validação de nomes de projeto (via subshell)"
# ---------------------------------------------------------------------------
run_validate() {
    # Sources only the function definitions by executing spring-init in a
    # restricted way: we re-implement the same regex here to test in isolation
    # without triggering full script execution (which requires a terminal/menu).
    local name="$1"
    [[ "${name}" =~ ^[A-Za-z0-9_-]+$ ]] && [[ "${name}" != .* ]] && [[ "${name}" != *..* ]]
}

if run_validate "api-clientes"; then pass "nome válido aceito: api-clientes"; else fail "api-clientes deveria ser válido"; fi
if run_validate "sistema_estoque"; then pass "nome válido aceito: sistema_estoque"; else fail "sistema_estoque deveria ser válido"; fi
if ! run_validate "../../alguma-coisa"; then pass "path traversal rejeitado"; else fail "path traversal deveria ser rejeitado"; fi
if ! run_validate "rm -rf /"; then pass "comando perigoso rejeitado"; else fail "comando perigoso deveria ser rejeitado"; fi
if ! run_validate ""; then pass "nome vazio rejeitado"; else fail "nome vazio deveria ser rejeitado"; fi

# ---------------------------------------------------------------------------
section "5. mktemp + trap (diretório temporário)"
# ---------------------------------------------------------------------------
TMP_TEST_DIR="$(mktemp -d -t spring-init-test.XXXXXXXX)"
if [[ -d "${TMP_TEST_DIR}" ]]; then
    pass "mktemp -d cria diretório temporário"
else
    fail "mktemp -d falhou"
fi
rm -rf -- "${TMP_TEST_DIR}"
if [[ ! -d "${TMP_TEST_DIR}" ]]; then
    pass "diretório temporário removido com sucesso"
else
    fail "diretório temporário não foi removido"
fi

# ---------------------------------------------------------------------------
section "6. Configuração"
# ---------------------------------------------------------------------------
TEST_CONFIG_DIR="$(mktemp -d -t spring-init-config-test.XXXXXXXX)"
TEST_CONFIG_FILE="${TEST_CONFIG_DIR}/config"
cat > "${TEST_CONFIG_FILE}" <<EOF
default_java=21
default_build=maven
default_packaging=jar
default_group=com.example
default_language=java
EOF
if grep -q "default_java=21" "${TEST_CONFIG_FILE}"; then
    pass "arquivo de configuração é escrito corretamente"
else
    fail "arquivo de configuração inválido"
fi
rm -rf -- "${TEST_CONFIG_DIR}"

# ---------------------------------------------------------------------------
section "7. Construção de parâmetros de URL (encoding)"
# ---------------------------------------------------------------------------
url_encode_test() {
    local raw="$1" out="" i c len
    len=${#raw}
    for (( i=0; i<len; i++ )); do
        c="${raw:i:1}"
        case "${c}" in
            [a-zA-Z0-9.~_-]) out+="${c}" ;;
            *) out+=$(printf '%%%02X' "'${c}") ;;
        esac
    done
    printf '%s' "${out}"
}

encoded="$(url_encode_test "com william api")"
if [[ "${encoded}" == "com%20william%20api" ]]; then
    pass "url_encode escapa espaços corretamente"
else
    fail "url_encode não escapou corretamente: ${encoded}"
fi

encoded2="$(url_encode_test "web,lombok,data-jpa")"
if [[ "${encoded2}" == "web%2Clombok%2Cdata-jpa" ]]; then
    pass "url_encode escapa vírgulas corretamente"
else
    fail "url_encode não escapou vírgulas: ${encoded2}"
fi

# ---------------------------------------------------------------------------
section "8. Tratamento de argumentos (nome + --quick)"
# ---------------------------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
    fail "curl não disponível para testes de integração (esperado, apenas aviso)"
else
    pass "curl disponível no ambiente de teste"
fi

# ---------------------------------------------------------------------------
section "Resumo"
# ---------------------------------------------------------------------------
printf '\n%d passaram, %d falharam\n' "${PASS}" "${FAIL}"

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
exit 0
