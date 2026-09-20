# spring-init

Um **Spring Initializr interativo para o terminal**, feito em Bash puro,
sem Node.js, Python ou dependências pesadas. Cria projetos Spring Boot
diretamente do seu terminal usando a API oficial [start.spring.io](https://start.spring.io).

Testado em **Fedora Linux**, com compatibilidade esperada em Ubuntu, Debian e Arch.

---

## O que é

`spring-init` abre um assistente interativo (ou modo rápido via linha de
comando) que:

- consulta dinamicamente a API do Spring Initializr (versões de Spring Boot e Java);
- monta a URL do `starter.zip` com os parâmetros que você escolher;
- baixa e extrai o projeto automaticamente;
- mostra um resumo do projeto antes de criar, com interface colorida via ANSI.

Nada é hardcoded: versões de Spring Boot/Java vêm sempre da API oficial.

---

## Requisitos

- Bash (`#!/usr/bin/env bash`)
- `curl`
- `unzip`
- `java` (JDK) — necessário para rodar o projeto gerado, não para gerar o ZIP

No Fedora:

```bash
sudo dnf install curl unzip java-21-openjdk
```

O script **verifica** essas dependências antes de começar e informa como
instalá-las caso faltem — ele nunca instala nada automaticamente por você.

---

## Estrutura do projeto

```
spring-init/
├── spring-init       # script principal (executável)
├── install.sh         # instalador (usuário ou sistema)
├── uninstall.sh        # desinstalador
├── test.sh             # testes offline
└── README.md
```

---

## Instalação

```bash
git clone https://github.com/william-grassis67/spring-init-cli.git spring-init
cd spring-init
chmod +x install.sh
./install.sh
```

O instalador pergunta onde instalar:

1. **Usuário atual** → `~/.local/bin/spring-init` (recomendado, **sem sudo**)
2. **Todo o sistema** → `/usr/local/bin/spring-init` (requer `sudo`)

Se `~/.local/bin` não estiver no seu `PATH`, o instalador mostra a linha
exata para adicionar ao `~/.bashrc` ou `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Depois, reabra o terminal (ou rode `source ~/.bashrc`) e teste:

```bash
spring-init --version
```

---

## Uso

### Modo interativo

```bash
spring-init
```

Abre o menu principal:

```
┌────────────────────────────────────┐
│        Novo projeto Spring Boot     │
├────────────────────────────────────┤
│  1) Criar projeto                   │
│  2) Configurações                   │
│  3) Sobre                           │
│  4) Sair                            │
└────────────────────────────────────┘
```

### Com nome pré-preenchido

```bash
spring-init meu-projeto
```

O assistente pergunta artifact ID, group ID, package name, versão do
Spring Boot, versão do Java, build tool (Maven/Gradle), linguagem
(Java/Kotlin/Groovy), packaging (Jar/War) e dependências — com o nome já
preenchido como padrão.

### Modo rápido

```bash
spring-init api-clientes --quick
```

Cria imediatamente um projeto **Java + Maven + Jar + Spring Web**, usando
seus padrões salvos em configuração, sem perguntar nada além do necessário.

### Ajuda e versão

```bash
spring-init --help
spring-init --version
```

### Modo debug

```bash
spring-init --debug
```

Mostra detalhes técnicos (URL gerada, diretório temporário, exit codes) em
caso de erro — útil para diagnosticar problemas de rede ou parâmetros.

---

## Exemplo real de uso

```bash
$ spring-init teste-api

Nome do projeto [teste-api]:
Artifact ID [teste-api]:
Group ID [com.example]: com.william
Package name [com.william.testeapi]:

Spring Boot version
  1. 3.5.0 (recomendada)
  2. 3.4.9
Escolha [1]:

Java version
  1. 17
  2. 21 (padrão)
  3. 25
Escolha [2]:

Build tool
1. Maven
2. Gradle
Escolha [1]:

Language
1. Java
2. Kotlin
3. Groovy
Escolha [1]:

Packaging
1. Jar
2. War
Escolha [1]:

Dependências disponíveis
   1. Spring Web
   2. Spring Data JPA
   ...
> 1 2 8

✓ Spring Web
✓ Spring Data JPA
✓ Lombok

========================================================
  PROJECT SUMMARY
========================================================
  • Name:        teste-api
  • Group:       com.william
  • Artifact:    teste-api
  ...
========================================================
Criar projeto? [y/N] y

-> Gerando projeto Spring Boot...
✓ Download concluído.
-> Extraindo projeto...
✓ Projeto extraído em ./teste-api

========================================================
  ✓ PROJECT CREATED SUCCESSFULLY
========================================================
  Location: ./teste-api

  Next steps:

    cd teste-api
    ./mvnw spring-boot:run
========================================================
```

---

## Dependências suportadas

| #  | Dependência              | ID do Spring Initializr    |
|----|---------------------------|-----------------------------|
| 1  | Spring Web                | `web`                      |
| 2  | Spring Data JPA           | `data-jpa`                 |
| 3  | Spring Security           | `security`                 |
| 4  | Validation                | `validation`                |
| 5  | MySQL Driver               | `mysql`                    |
| 6  | PostgreSQL Driver          | `postgresql`               |
| 7  | H2 Database                | `h2`                       |
| 8  | Lombok                     | `lombok`                   |
| 9  | Spring Boot DevTools       | `devtools`                 |
| 10 | Actuator                   | `actuator`                 |
| 11 | Thymeleaf                  | `thymeleaf`                |
| 12 | Configuration Processor    | `configuration-processor`  |

Digite os números separados por espaço (`1 2 8`), `a` para todas ou `n`
para nenhuma.

---

## Configuração

`spring-init` guarda seus padrões em:

```
~/.config/spring-init/config
```

Formato simples `chave=valor`:

```
default_java=21
default_build=maven
default_packaging=jar
default_group=com.example
default_language=java
```

Você pode editar esses valores pelo menu `Configurações` (opção 2 do menu
principal) ou diretamente no arquivo. Nenhuma senha ou credencial é
armazenada.

---

## Segurança

- `set -Eeuo pipefail` em todos os scripts.
- Nomes de projeto e artifact validados por regex (`^[A-Za-z0-9_-]+$`),
  rejeitando caminhos como `../../algo` e qualquer caractere fora do padrão.
- Todos os parâmetros enviados ao `start.spring.io` passam por
  percent-encoding (`url_encode`) antes de montar a URL.
- Nenhum comando recebido da internet é executado; não há uso de `eval`.
- Diretórios de projeto existentes **nunca** são sobrescritos sem
  confirmação explícita (é preciso digitar `OVERWRITE`).
- Arquivos temporários usam `mktemp -d` e são sempre limpos via `trap`
  (`EXIT` e `ERR`), mesmo em caso de erro.

---

## Testes

```bash
./test.sh
```

`test.sh` roda testes **offline** (não baixa nada do Spring Initializr):

- script é executável e sintaticamente válido (`bash -n`);
- `--help` e `--version` retornam a saída esperada;
- opções desconhecidas falham corretamente;
- validação de nomes de projeto (aceita válidos, rejeita path traversal e
  comandos perigosos);
- criação e limpeza de diretório temporário (`mktemp` + `trap`);
- escrita do arquivo de configuração;
- percent-encoding correto dos parâmetros de URL (espaços, vírgulas etc).

---

## Desinstalação

```bash
chmod +x uninstall.sh
./uninstall.sh
```

Remove o binário instalado em `~/.local/bin/spring-init` e/ou
`/usr/local/bin/spring-init` (perguntando por `sudo` apenas quando
necessário). As configurações em `~/.config/spring-init/` só são apagadas
se você confirmar explicitamente.

---

## Como contribuir

1. Faça um fork do repositório.
2. Crie uma branch: `git checkout -b minha-feature`.
3. Rode `./test.sh` antes de abrir o PR.
4. Mantenha funções pequenas e nomeadas de forma clara (`ask_*`,
   `show_*`, `check_*`, `select_*`), seguindo o estilo já usado no script.
5. Evite adicionar dependências externas — o objetivo é continuar
   funcionando com apenas Bash + `curl` + `unzip` + `java`.
6. Abra o Pull Request explicando o que mudou e por quê.

---

## Licença

Sinta-se livre para adaptar este projeto conforme a licença que você
escolher para o seu repositório (MIT é uma boa escolha padrão para esse
tipo de ferramenta).
