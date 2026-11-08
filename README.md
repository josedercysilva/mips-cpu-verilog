# Processador MIPS de 32 bits com Pipeline de 5 Estágios

> **Terceira Entrega** da disciplina de **Arquitetura de Sistemas Digitais e Laboratório**  
> **Universidade Federal do Amazonas (UFAM)** — Faculdade de Engenharia Elétrica e da Computação (FEEC)  
> **Mantenedor:** José Dercy Vieira da Silva Filho ([@josedercysilva](https://github.com/josedercysilva))  
> **Equipe do Projeto (UFAM):** José Dercy Vieira da Silva Filho e Vinicius Menezes  
> **Plataforma Alvo:** FPGA Intel MAX 10 (`10M50DAF484C7G`) — Placa Terasic DE10-Lite  
> **Prazo da Entrega:** 13/11/2026, até às 13:59h (Pontuação Total: 8,0 pontos)  

> [!IMPORTANT]
> **Status da Branch (Em Desenvolvimento — WIP):** Esta árvore evolui de forma incremental a partir da base estável Monociclo (`v1.0-monociclo` na branch `main`). Atualmente encontram-se concluídos e validados em RTL os **Passos 1 a 3** (documentação arquitetural, suporte a *stall* no `PC` e registrador de barreira `IF/ID`). Consulte o [Roadmap de Implementação](#status-e-roadmap-de-implementação) abaixo para acompanhar cada etapa.

---

## Visão Geral

Implementação em Verilog HDL (IEEE Std 1364-2005) de um processador **MIPS de 32 bits**, evoluindo da microarquitetura Monociclo validada em FPGA para a **arquitetura em Pipeline clássica de 5 estágios** (`IF`, `ID`, `EX`, `MEM`, `WB`), baseada no modelo de Patterson & Hennessy (*Computer Organization and Design*).

O processador adota arquitetura **Harvard** com subsistemas desacoplados para instruções (ROM) e dados (RAM), garantindo isolamento estrutural. O projeto da microarquitetura em pipeline prevê unidades dedicadas para resolução completa de perigos (*hazards*):

1. **Forwarding Unit (Encaminhamento de Dados — *Planejado no Passo 7*):** Resolve conflitos de dados RAW (*Read-After-Write*) adiantando resultados dos estágios `EX/MEM` e `MEM/WB` diretamente para as entradas da ULA no estágio `EX`.
2. **Hazard Detection Unit (Detecção Load-Use — *Planejado no Passo 8*):** Identifica dependências imediatas de leitura da memória (`lw`), inserindo automaticamente **1 ciclo de bolha** (*stall* de hardware com congelamento do `PC` e do registrador `IF/ID`).
3. **Resolução de Desvios e Saltos:** Controle de fluxo com pulsos síncronos de *flush* nos registradores de estágio para descarte de instruções especulativas em desvios tomados (`beq`, `bne`) e saltos incondicionais (`j`, `jal`, `jr`).

A validação de ponta a ponta é executada em regime puramente *bare-metal* sobre o algoritmo canônico de ordenação **Bubble Sort** (`sort.s` $\to$ `sort.bin`), obedecendo rigorosamente à alocação MIPS ABI estipulada pela disciplina.

---

## Arquitetura Alvo do Pipeline

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
* **`pipe_if_id.v` *(Implementado)*:** Amostra `PC+4` e a instrução buscada da ROM. Possui controle síncrono de `enable` (congelamento em *stall*) e `flush` prioritário (descarte em desvios).
* **`pipe_id_ex.v` *(Em fila — Passo 4)*:** Amostra operandos decodificados, imediato com extensão de sinal, índices dos registradores (`rs`, `rt`, `rd`) e empacota os sinais de controle dos estágios `EX`, `MEM` e `WB`.
* **`pipe_ex_mem.v` *(Em fila — Passo 5)*:** Amostra o resultado da ULA, dado de escrita para a RAM, endereço de destino do registrador (`WriteReg`), alvo de desvio e controles `MEM` e `WB`.
* **`pipe_mem_wb.v` *(Em fila — Passo 6)*:** Amostra o dado lido da RAM, resultado da ULA, endereço de destino (`WriteReg`) e sinais de controle do estágio `WB`.

---

## Status e Roadmap de Implementação

O desenvolvimento na branch tronco `feat/mips-pipeline-core` segue integração atômica por funcionalidade (`--no-ff`) com validação unitária obrigatória antes de cada merge:

- [x] **Base (`v1.0-monociclo`):** Processador MIPS Monociclo completo, sintetizado no MAX 10 e validado com `sort.bin`.
- [x] **Passo 1:** Inicialização do contexto, especificações arquiteturais e documentação da Entrega 03.
- [x] **Passo 2 (`src/datapath/pc.v`):** Adição da porta `enable` no Program Counter para congelamento sob *stall* (`tb_datapath_aux.v`).
- [x] **Passo 3 (`src/pipeline/pipe_if_id.v`):** Implementação e verificação do registrador `IF/ID` com `enable` e `flush` (`tb_pipe_if_id.v`).
- [ ] **Passo 4 (`src/pipeline/pipe_id_ex.v`):** Registrador `ID/EX` com transporte de sinais de controle e injeção de bolha (`flush`).
- [ ] **Passo 5 (`src/pipeline/pipe_ex_mem.v`):** Registrador `EX/MEM` para dados da ULA, escrita na RAM e desvios.
- [ ] **Passo 6 (`src/pipeline/pipe_mem_wb.v`):** Registrador `MEM/WB` para estágio de escrita no banco de registradores.
- [ ] **Passo 7 (`src/hazard/forwarding_unit.v`):** Unidade de adiantamento (*Forwarding*) para resolução de perigos RAW.
- [ ] **Passo 8 (`src/hazard/hazard_detection_unit.v`):** Unidade de detecção de perigos *Load-Use* e geração de *stalls*.
- [ ] **Passo 9 (`src/mips_pipeline_top.v`):** Integração estrutural Top-Level dos 5 estágios e expansão das instruções `xor`, `andi` e `ori`.
- [ ] **Passo 10–11:** Validação completa do benchmark Bubble Sort no pipeline e atualização da suíte de regressão (`make test`).
- [ ] **Passo 12–13:** Síntese física na FPGA Intel MAX 10 (DE10-Lite), relatório técnico IEEE (`relatorio_terceira_entrega.pdf`) e vídeo.

---

## Estrutura Atual do Repositório

```text
.
├── Makefile                     # Orquestrador de testes, simulação, síntese e relatórios
├── assembly-mips/               # Benchmark Bubble Sort (sort.s, sort-teste.s e sort.bin)
├── contexto/                    # Especificações técnicas e diretrizes arquiteturais do projeto
├── docs/                        # Documentação técnica e científica
│   ├── apresentacao/            # Slides em LaTeX Beamer (base Entrega 02)
│   └── relatorio/               # Artigo técnico no padrão IEEE (IEEEtran)
├── quartus/                     # Projeto de síntese física para FPGA Intel MAX 10 (.qpf/.qsf)
├── scripts/                     # Scripts bash para simulação, GTKWave e testes de regressão
├── src/                         # Código-fonte Verilog HDL (IEEE Std 1364-2005)
│   ├── control/                 # Controle Principal (main_control), ALU Control e Control Unit
│   ├── datapath/                # ALU, RegFile, PC com enable, Somadores, Muxes e Datapath base
│   ├── memory/                  # Subsistema Harvard (ROM instr_mem e RAM data_mem)
│   ├── pipeline/                # Registradores entre estágios (atualmente: pipe_if_id.v)
│   └── mips_monociclo_top.v     # Top-Level Monociclo ativo (mips_pipeline_top.v no Passo 9)
└── tb/                          # 8 bancadas de teste unitárias e de integração ativas
```

---

## Repertório de Instruções

O caminho de dados atual já implementa e valida **16 instruções** suficientes para o benchmark `sort`, com expansão prevista de mais 3 operações lógicas na integração do pipeline:

| Formato | Instruções | Status Atual | Função na Arquitetura e no Benchmark |
| :---: | :--- | :---: | :--- |
| **Tipo-R** | `add`, `sub`, `and`, `or`, `nor`, `slt` | Implementado | Operações da ULA e comparações de índice com sinal |
| **Tipo-R** | `sll` | Implementado | Deslocamento lógico à esquerda para indexação de palavras ($j \times 4$) |
| **Tipo-R** | `jr` | Implementado | Retorno de procedimento via `$ra` (função folha `swap`) |
| **Tipo-I** | `lw`, `sw` | Implementado | Carga e armazenamento de elementos do vetor na RAM de dados |
| **Tipo-I** | `addi`, `slti` | Implementado | Manipulação de ponteiro de pilha (`$sp`), decrementos e condição de parada |
| **Tipo-I** | `beq`, `bne` | Implementado | Desvios condicionais por igualdade e diferença nos laços |
| **Tipo-J** | `j`, `jal` | Implementado | Salto incondicional e chamada de sub-rotina com salvamento de `PC+4` em `$ra` |
| **Tipo-R / I** | `xor`, `andi`, `ori` | Planejado (Passo 9) | Expansão do repertório lógico para a versão em Pipeline |

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
# Executa a suíte de testes de regressão ativa (8 bancadas: blocos base + PC enable + pipe_if_id)
make test

# Executa individualmente o testbench do registrador de pipeline IF/ID
make pipe_if_id

# Simula o processador top-level atual (mips_monociclo_top) executando sort.bin via Icarus Verilog
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

## Validação Atual e Baseline de Desempenho

* **Simulação RTL Automatizada (Icarus Verilog):** **8 de 8 bancadas aprovadas (0 falhas)** via `./scripts/run_all_tests.sh`, cobrindo ALU, módulos auxiliares com `pc` habilitável (`enable`), banco de registradores, unidade de controle, memórias ROM/RAM, registrador `pipe_if_id` (stall/flush) e integração Top-Level.
* **Baseline Funcional e Física (`v1.0-monociclo`):**
  * Ordenação *bare-metal* comprovada na RAM de dados: `[88, 15, 42, 7, 99]` $\to$ `[7, 15, 42, 88, 99]`.
  * Síntese validada no FPGA Intel MAX 10 (`10M50DAF484C7G`) com **17.089 LEs**, **0 latches transparentes espúrios** e redes dedicadas `CLKCTRL_G3`/`CLKCTRL_G4` — servindo de referência direta para a análise comparativa de ciclos, IPC e $F_{\max}$ do Pipeline.
* **Documentação Técnica IEEE:** Relatório baseline de 6 páginas compilado em [`docs/relatorio/relatorio_segunda_entrega.pdf`](docs/relatorio/relatorio_segunda_entrega.pdf) (relatório comparativo do Pipeline previsto no Passo 13).

---

## Ambiente de Desenvolvimento e Ferramental

* **Síntese Lógica e Mapeamento FPGA:** Intel Quartus Prime Lite Edition 20.1 (MAX 10 / DE10-Lite)
* **Simulação Comportamental RTL:** Icarus Verilog (`iverilog`)
* **Inspeção e Depuração de Formas de Onda:** GTKWave
* **Documentação Científica e Tipografia:** LaTeX (`IEEEtran` / Tectonic) e Typst
* **Ambiente de Engenharia e Pair Programming:** Google Antigravity (Google DeepMind)
