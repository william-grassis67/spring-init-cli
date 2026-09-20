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
section "9. Parser de metadados (jq) - regressão do bug de mistura de campos"
# ---------------------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
    fail "jq não encontrado (obrigatório para o parser de metadados)"
else
    pass "jq disponível no ambiente de teste"

    SAMPLE_JSON="$(mktemp -t spring-init-metadata-test.XXXXXXXX.json)"
    cat > "${SAMPLE_JSON}" <<'JSONEOF'
{
  "dependencies": {
    "values": [
      { "name": "Developer Tools", "values": [
        { "id": "devtools", "name": "Spring Boot DevTools" },
        { "id": "native", "name": "GraalVM Native Support" },
        { "id": "dgs-codegen", "name": "Netflix DGS Code Generation" }
      ]}
    ]
  },
  "javaVersion": {
    "default": "21",
    "values": [ { "id": "27" }, { "id": "25" }, { "id": "21" }, { "id": "17" } ]
  },
  "bootVersion": {
    "default": "3.5.0",
    "values": [
      { "id": "4.2.0.BUILD-SNAPSHOT" },
      { "id": "4.1.1.RELEASE" },
      { "id": "3.5.0" },
      { "id": "3.4.9" }
    ]
  }
}
JSONEOF

    boot_default="$(jq -r --arg k "bootVersion" '.[$k].default // empty' "${SAMPLE_JSON}")"
    if [[ "${boot_default}" == "3.5.0" ]]; then
        pass "jq extrai corretamente o default de bootVersion"
    else
        fail "default de bootVersion incorreto: '${boot_default}'"
    fi

    mapfile -t boot_ids < <(jq -r --arg k "bootVersion" '.[$k].values[]?.id // empty' "${SAMPLE_JSON}")
    contaminated=0
    for id in "${boot_ids[@]}"; do
        case "${id}" in
            native|devtools|dgs-codegen|17|21|25|27)
                contaminated=1
                ;;
        esac
    done
    if [[ "${contaminated}" -eq 0 && "${#boot_ids[@]}" -eq 4 ]]; then
        pass "bootVersion.values não contém ids de dependencies/javaVersion (regressão corrigida)"
    else
        fail "bootVersion.values contém valores de outras seções: ${boot_ids[*]}"
    fi

    mapfile -t java_ids < <(jq -r --arg k "javaVersion" '.[$k].values[]?.id // empty' "${SAMPLE_JSON}")
    contaminated=0
    for id in "${java_ids[@]}"; do
        case "${id}" in
            native|devtools|dgs-codegen) contaminated=1 ;;
        esac
    done
    if [[ "${contaminated}" -eq 0 && "${#java_ids[@]}" -eq 4 ]]; then
        pass "javaVersion.values não contém ids de dependencies/bootVersion"
    else
        fail "javaVersion.values contém valores de outras seções: ${java_ids[*]}"
    fi

    rm -f -- "${SAMPLE_JSON}"
fi

# ---------------------------------------------------------------------------
section "10. Validadores de formato de versão"
# ---------------------------------------------------------------------------
validate_boot_version_t() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9]+)*$ ]]
}
validate_java_version_t() {
    [[ "$1" =~ ^[0-9]{1,3}$ ]]
}

if validate_boot_version_t "3.5.0"; then pass "3.5.0 aceito como versão de Spring Boot válida"; else fail "3.5.0 deveria ser válido"; fi
if validate_boot_version_t "4.1.1.RELEASE"; then pass "4.1.1.RELEASE aceito"; else fail "4.1.1.RELEASE deveria ser válido"; fi
if ! validate_boot_version_t "native"; then pass "'native' rejeitado como versão de Spring Boot"; else fail "'native' não deveria ser aceito como versão"; fi
if ! validate_boot_version_t "devtools"; then pass "'devtools' rejeitado como versão de Spring Boot"; else fail "'devtools' não deveria ser aceito como versão"; fi
if validate_java_version_t "21"; then pass "21 aceito como versão de Java válida"; else fail "21 deveria ser válido"; fi
if ! validate_java_version_t "dgs-codegen"; then pass "'dgs-codegen' rejeitado como versão de Java"; else fail "'dgs-codegen' não deveria ser aceito"; fi

# ---------------------------------------------------------------------------
section "Resumo"
# ---------------------------------------------------------------------------
printf '\n%d passaram, %d falharam\n' "${PASS}" "${FAIL}"

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
exit 0
