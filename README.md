# Processador MIPS de 32 bits com Pipeline de 5 Estágios

> **Terceira Entrega** da disciplina de **Arquitetura de Sistemas Digitais e Laboratório**  
> **Universidade Federal do Amazonas (UFAM)** — Faculdade de Engenharia Elétrica e da Computação (FEEC)  
> **Autores:** José Dercy Vieira da Silva Filho e Vinicius Menezes  
> **Mantenedor do Repositório:** José Dercy Silva ([@josedercysilva](https://github.com/josedercysilva))  
> **Plataforma Alvo:** FPGA Intel MAX 10 (`10M50DAF484C7G`) — Placa Terasic DE10-Lite  
> **Prazo da Entrega:** 13/11/2026, até às 13:59h (Pontuação Total: 8,0 pontos)  

---

## Visão Geral

Implementação em Verilog HDL (IEEE Std 1364-2005) de um processador **MIPS de 32 bits com arquitetura em Pipeline clássica de 5 estágios** (IF, ID, EX, MEM, WB), baseada no modelo de Patterson & Hennessy (*Computer Organization and Design*).

O processador adota arquitetura **Harvard** com subsistemas desacoplados para instruções (ROM) e dados (RAM), garantindo isolamento estrutural. Para assegurar máxima vazão (*throughput*) sem corrupção de dados ou paradas desnecessárias, o caminho de dados integra unidades dedicadas para resolução de perigos (*hazards*):

1. **Forwarding Unit (Encaminhamento de Dados):** Resolve conflitos de dados RAW (*Read-After-Write*) adiantando resultados dos estágios `EX/MEM` e `MEM/WB` diretamente para as entradas da ULA no estágio `EX`.
2. **Hazard Detection Unit (Detecção de Perigos Load-Use):** Identifica dependências imediatas de leitura da memória (`lw`), inserindo automaticamente **1 ciclo de bolha** (*stall* de hardware com congelamento do `PC` e do registrador `IF/ID`).
3. **Resolução de Desvios e Saltos:** Controle de fluxo com pulsos síncronos de *flush* nos registradores de estágio para descarte de instruções especulativas em desvios tomados (`beq`, `bne`) e saltos incondicionais (`j`, `jal`, `jr`).

A validação de ponta a ponta é executada em regime puramente *bare-metal* sobre o algoritmo canônico de ordenação **Bubble Sort** (`sort.s` $\to$ `sort.bin`), obedecendo rigorosamente à alocação MIPS ABI estipulada pela disciplina.

---

## Arquitetura do Pipeline

```text
       ┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
       │    IF    │ ───► │    ID    │ ───► │    EX    │ ───► │   MEM    │ ───► │    WB    │
       │ (Fetch)  │      │ (Decode) │      │(Execute) │      │ (Memory) │      │(Wr-Back) │
       └────┬─────┘      └────┬─────┘      └────┬─────┘      └────┬─────┘      └────┬─────┘
            │   pipe_if_id    │   pipe_id_ex    │   pipe_ex_mem   │   pipe_mem_wb    │
            └─────────────────┴─────────────────┴─────────────────┴──────────────────┘
                              ▲                 ▲                 ▲
                     ┌────────┴────────┐ ┌──────┴────────┐        │
                     │ Hazard Detect   │ │  Forwarding   │────────┘
                     │ Unit (Stalls)   │ │  Unit (RAW)   │
                     └─────────────────┘ └───────────────┘
```

### Registradores entre Estágios (`src/pipeline/`)
* **`pipe_if_id.v`:** Amostra `PC+4` e a instrução buscada da ROM. Possui controle de `enable` (para congelamento em stall) e `flush` (para descarte em desvios).
* **`pipe_id_ex.v`:** Amostra operandos decodificados, imediato com extensão de sinal, índices dos registradores (`rs`, `rt`, `rd`) e empacota os sinais de controle dos estágios `EX`, `MEM` e `WB`.
* **`pipe_ex_mem.v`:** Amostra o resultado da ULA, dado de escrita para a RAM, endereço de destino do registrador (`WriteReg`), alvo de desvio e controles `MEM` e `WB`.
* **`pipe_mem_wb.v`:** Amostra o dado lido da RAM, resultado da ULA, endereço de destino (`WriteReg`) e sinais de controle do estágio `WB`.

---

## Estrutura do Repositório

```text
.
├── Makefile                     # Orquestrador de testes, simulação, síntese e relatórios
├── assembly-mips/              # Benchmark Bubble Sort (sort.s e sort.bin)
├── docs/                        # Documentação técnica e científica
│   ├── apresentacao/            # Roteiro, slides e link do vídeo da apresentação
│   └── relatorio/               # Artigo técnico no padrão IEEE Transactions (IEEEtran)
├── quartus/                     # Projeto de síntese física para FPGA Intel MAX 10 (.qpf/.qsf)
├── scripts/                     # Scripts bash para simulação, GTKWave e testes de regressão
├── src/                         # Código-fonte Verilog HDL (IEEE Std 1364-2005)
│   ├── control/                 # Unidade de Controle Principal e Controle da ALU
│   ├── datapath/                # ALU, RegFile, PC com enable, Somadores e Multiplexadores
│   ├── hazard/                  # Forwarding Unit e Hazard Detection Unit
│   ├── memory/                  # ROM instr_mem e RAM data_mem (Harvard)
│   ├── pipeline/                # Registradores síncronos entre estágios (pipe_*.v)
│   └── mips_pipeline_top.v      # Módulo Top-Level estrutural integrando os 5 estágios
└── tb/                          # Suíte de bancadas de teste unitárias e integradas
```

---

## Repertório de Instruções Suportado

O repertório implementado cobre todas as operações aritméticas, lógicas, de memória e fluxo de controle necessárias para o benchmark `sort`:

| Formato | Instruções | Função na Arquitetura e no Benchmark |
| :---: | :--- | :--- |
| **Tipo-R** | `add`, `sub`, `and`, `or`, `nor`, `xor`, `slt` | Operações da ULA e comparações de índice com sinal |
| **Tipo-R** | `sll` | Deslocamento lógico à esquerda para indexação de palavras ($j \times 4$) |
| **Tipo-R** | `jr` | Retorno de procedimento via `$ra` (função folha `swap`) |
| **Tipo-I** | `lw`, `sw` | Carga e armazenamento de elementos do vetor na RAM de dados |
| **Tipo-I** | `addi`, `slti` | Manipulação de ponteiro de pilha (`$sp`), decrementos e condição de parada |
| **Tipo-I** | `andi`, `ori` | Operações lógicas com imediatos estendidos |
| **Tipo-I** | `beq`, `bne` | Desvios condicionais com descarte de instruções especulativas |
| **Tipo-J** | `j`, `jal` | Salto incondicional e chamada de sub-rotina com salvamento de `PC+4` em `$ra` |

---

## Convenção Estrita de Registradores (Benchmark Bubble Sort)

Em conformidade rigorosa com a especificação da disciplina e a MIPS ABI:
* `$a0` (`$4`): Endereço base do vetor `v` na RAM de dados
* `$a1` (`$5`): Tamanho do vetor `n` ou parâmetro de troca `k`
* `$s0` (`$16`): Variável de índice `i` do laço externo
* `$s1` (`$17`): Variável de índice `j` do laço interno
* `$sp` (`$29`): Ponteiro da pilha de execução
* `$ra` (`$31`): Endereço de retorno de sub-rotina (`swap`)

---

## Guia Rápido de Execução

Todo o fluxo de compilação, simulação, síntese e documentação é encapsulado no `Makefile`:

```bash
# Executa a suíte de testes de regressão completa (testbenches unitários e de integração)
make test

# Simula o processador top-level executando o algoritmo sort.bin via Icarus Verilog
make top

# Abre as formas de onda da última simulação no GTKWave para validação visual
make waves-top

# Executa a síntese física completa no Intel Quartus Prime para a placa DE10-Lite
make quartus-build

# Grava o bitstream (.sof) no FPGA MAX 10 via cabo USB-Blaster
make quartus-pgm

# Compila o relatório técnico IEEE em PDF via Tectonic
make relatorio
```

---

## Validação e Métricas de Desempenho

* **Simulação RTL Automatizada (Icarus Verilog):** Testbenches cobrindo cada módulo individualmente e o Top-Level com 100% de aprovação.
* **Validação do Algoritmo de Ordenação:** Vetor inicial `[88, 15, 42, 7, 99]` reordenado para `[7, 15, 42, 88, 99]` na RAM de dados, com correta inserção de bolhas de *load-use* e adiantamentos da *forwarding unit*.
* **Síntese Física (Intel MAX 10 `10M50DAF484C7G`):**
  * Lógica 100% síncrona sem *latches* transparentes espúrios.
  * Distribuição global de relógio através de redes dedicadas `CLKCTRL`.
  * Ganho de frequência de operação ($F_{\max}$) em relação ao processador monociclo da Entrega 02 devido à redução do caminho crítico por estágio.
* **Documentação Técnica IEEE:** Relatório detalhado no formato IEEEtran de 6 páginas em [`docs/relatorio/`](docs/relatorio/).
