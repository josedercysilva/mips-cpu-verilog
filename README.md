# Processador MIPS de 32 bits com Pipeline de 5 Estágios

> **Terceira Entrega** da disciplina de **Arquitetura de Sistemas Digitais e Laboratório**  
> **Universidade Federal do Amazonas (UFAM)** — Faculdade de Engenharia Elétrica e da Computação (FEEC)  
> **Mantenedor:** José Dercy Vieira da Silva Filho ([@josedercysilva](https://github.com/josedercysilva))  
> **Equipe do Projeto (UFAM):** José Dercy Vieira da Silva Filho e Vinicius Menezes  
> **Plataforma Alvo:** FPGA Intel MAX 10 (`10M50DAF484C7G`) — Placa Terasic DE10-Lite  
> **Prazo da Entrega:** 18/11/2026, até às 13:59h (Pontuação Total: 8,0 pontos)

---

## Visão Geral

Implementação em Verilog HDL (IEEE Std 1364-2005) de um processador **MIPS de 32 bits** com **arquitetura em Pipeline clássica de 5 estágios** (`IF`, `ID`, `EX`, `MEM`, `WB`), evoluindo sobre o baseline Monociclo (Entrega 02, preservado em [`monociclo/`](monociclo/)) com base no modelo de Patterson & Hennessy (*Computer Organization and Design*).

Todos os módulos RTL em [`src/`](src/) são parametrizados (`DATA_WIDTH`, `ADDR_WIDTH`, `MEM_DEPTH`, `REG_ADDR_WIDTH`) e adotam arquitetura **Harvard** desacoplada para instruções (ROM) e dados (RAM), com resolução completa de perigos (*hazards*) em hardware:

1. **Forwarding Unit ([`src/hazard/forwarding_unit.v`](src/hazard/forwarding_unit.v)):** Resolve conflitos de dados RAW (*Read-After-Write*) encaminhando resultados dos estágios `EX/MEM` e `MEM/WB` diretamente para as entradas da ULA no estágio `EX` (incluindo prioridade `EX/MEM > MEM/WB`, proteção do registrador `$zero` e forwarding de `PC+4` para `jal`).
2. **Hazard Detection Unit ([`src/hazard/hazard_detection_unit.v`](src/hazard/hazard_detection_unit.v)):** Detecta dependências imediatas *Load-Use* (`lw`) e injeta automaticamente **1 ciclo de bolha** (*stall* via congelamento de `pc` e `pipe_if_id`, com zeramento dos sinais de controle para `pipe_id_ex`).
3. **Resolução de Controle, Bypass WB $\to$ ID e Flushes:** Desvios condicionais (`beq`, `bne`) e `jr` resolvidos no estágio `EX`; saltos incondicionais (`j`, `jal`) resolvidos no estágio `ID`; encaminhamento interno `WB -> ID` (*write-through* no banco de registradores); e pulsos síncronos de `flush` (`if_id_flush` e `id_ex_flush`) descartando instruções especulativas sem necessidade de `nop`s.

A validação funcional ponta a ponta é executada em regime *bare-metal* sobre o benchmark oficial **Bubble Sort** (`sort.s` $\to$ `sort.bin`), complementada pelas suítes [`teste_isa.s`](assembly-mips/teste_isa.s) (todas as 16 instruções) e [`teste_hazards.s`](assembly-mips/teste_hazards.s) (forwarding, proteção de `$zero`, Load-Use, flushes, retorno imediato `jal -> jr $ra` e recursão dupla com `fib(7)`).

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

### Registradores entre Estágios ([`src/pipeline/`](src/pipeline/))
* **`pipe_if_id.v`:** Amostra `PC+4` e a instrução buscada da ROM, com `enable` (stall) e `flush` prioritário.
* **`pipe_id_ex.v`:** Amostra operandos lidos do banco, imediato estendido em 32 bits, `shamt`, índices (`rs`, `rt`, `rd`), `PC+4` e sinais de controle `EX`/`MEM`/`WB`, com `enable` e `flush` síncrono (bolha).
* **`pipe_ex_mem.v`:** Amostra resultado da ULA, dado de escrita para RAM (já após forwarding), registrador destino (`WriteReg`), alvo de desvio, flag `zero`, `PC+4` e controles `MEM`/`WB`.
* **`pipe_mem_wb.v`:** Amostra dado lido da RAM, resultado da ULA, `PC+4`, `WriteReg` e controles do estágio `WB`.

---

## Status e Roadmap de Implementação

- [x] **Base (`monociclo/`):** Processador MIPS Monociclo completo (Entrega 02), preservado isoladamente como baseline de comparação.
- [x] **RTL Completo (`src/`):** Caminho de dados parametrizado, unidade de controle, memórias ROM/RAM, 4 registradores de pipeline, `forwarding_unit`, `hazard_detection_unit` e integração [`mips_pipeline_top.v`](src/mips_pipeline_top.v).
- [x] **Validação Unitária e Top-Level (`tb/`):** Todas as **14 bancadas** aprovadas em `make test` (`0` warnings de compilação) com geração de `.vcd` em `build/`, incluindo Bubble Sort (`sort.bin` em **205 ciclos**), `teste_isa.bin` e `teste_hazards.bin` (`tb_pipeline_isa_hazards.v`).
- [x] **Programas Assembly e Espelhos MARS (`assembly-mips/`):** `sort.s/.bin`, `teste_isa.s/.bin`, `teste_hazards.s/.bin` e espelhos com `syscall` em [`assembly-mips/mars/`](assembly-mips/mars/).
- [x] **Cobertura de Testbenches (`tb/`):** Cobertura explícita das 16 instruções (`SLL`/`BNE`/`SLTI`), zero warnings em `tb_alu.v` e suíte integrada contínua de `teste_isa.bin`/`teste_hazards.bin`.
- [ ] **Síntese Física, Relatório IEEE e Apresentação:** Compilação Quartus na DE10-Lite (`MAX 10`), relatório técnico IEEE (`docs/relatorio/`), slides (`docs/apresentacao/`) e vídeo demonstrativo (~10 min).

---

## Estrutura do Repositório

```text
.
├── AGENTS.md / GEMINI.md        # Diretrizes operacionais e regras de arquitetura/testes
├── Makefile                     # Orquestrador de testes, simulação, GTKWave, Quartus e LaTeX
├── assembly-mips/               # Firmwares bare-metal (.s/.bin) e espelhos visuais em mars/
├── contexto/                    # Especificação oficial (Classroom), arquitetura e manual do projeto
├── docs/                        # Documentação técnica e científica
│   ├── apresentacao/            # Slides em LaTeX Beamer
│   └── relatorio/               # Artigo técnico IEEEtran (base Entrega 02 e Entrega 03)
├── formal_test/                 # Verificação formal SVA (forwarding_unit e controle top-level)
├── monociclo/                   # Baseline MIPS Monociclo isolado (Entrega 02)
├── notas/                       # Checklist de entregas, mapa da ISA e notas de estudo/relatório
├── quartus/                     # Projeto Intel Quartus Prime para FPGA MAX 10 (DE10-Lite)
├── scripts/                     # Scripts bash para Icarus Verilog, GTKWave e suíte completa
├── src/                         # Código-fonte Verilog HDL (IEEE Std 1364-2005)
│   ├── control/                 # main_control.v, alu_control.v e control_unit.v
│   ├── datapath/                # pc.v, alu.v, reg_file.v, adder.v, sign_extend.v e mux*
│   ├── hazard/                  # forwarding_unit.v e hazard_detection_unit.v
│   ├── memory/                  # Subsistema Harvard (instr_mem.v ROM e data_mem.v RAM)
│   ├── pipeline/                # pipe_if_id.v, pipe_id_ex.v, pipe_ex_mem.v e pipe_mem_wb.v
│   └── mips_pipeline_top.v      # Top-Level do Processador MIPS Pipeline de 5 estágios
└── tb/                          # 14 bancadas de teste unitárias e Top-Level (geram build/*.vcd)
```

---

## Repertório de Instruções (16 Instruções Suportadas)

O processador suporta exatamente as **16 instruções** exigidas pela especificação oficial da disciplina (documentadas em [`notas/zz-conjunto-instrucoes-suportadas.md`](notas/zz-conjunto-instrucoes-suportadas.md)):

| Formato | Instruções | Função na Arquitetura |
| :---: | :--- | :--- |
| **Tipo-R** | `add`, `sub`, `and`, `or`, `nor`, `slt` | Operações aritméticas/lógicas da ULA e comparação com sinal |
| **Tipo-R** | `sll` | Deslocamento lógico à esquerda (indexação de palavras $j \times 4$) |
| **Tipo-R** | `jr` | Retorno de sub-rotina via registrador (`$ra`) |
| **Tipo-I** | `lw`, `sw` | Carga e armazenamento de palavras na memória de dados (RAM) |
| **Tipo-I** | `addi`, `slti` | Operações com imediato estendido em sinal e comparação `slt` imediata |
| **Tipo-I** | `beq`, `bne` | Desvios condicionais por igualdade e desigualdade |
| **Tipo-J** | `j`, `jal` | Salto incondicional e chamada de procedimento (`$ra <- PC+4`) |

---

## Convenção de Registradores (Benchmark Bubble Sort)

Em conformidade com o roteiro da disciplina e a MIPS ABI:
* `$a0` (`$4`): Endereço base do vetor `v` na RAM de dados
* `$a1` (`$5`): Tamanho do vetor `n` ou argumento `k` em `swap`
* `$s0` (`$16`): Variável `i` do laço externo
* `$s1` (`$17`): Variável `j` do laço interno
* `$sp` (`$29`): Ponteiro da pilha de execução
* `$ra` (`$31`): Endereço de retorno de procedimento

---

## Guia Rápido de Execução

Todo o fluxo de simulação, visualização, baseline Monociclo, síntese e relatórios está centralizado no [`Makefile`](Makefile):

```bash
# Executa toda a suíte de regressão do Pipeline (14 bancadas unitárias + top-level)
make test

# Simula o processador MIPS Pipeline executando assembly-mips/sort.bin
make pipeline_top

# Simula a suíte integrada teste_isa.bin + teste_hazards.bin no mips_pipeline_top
make pipeline_isa_hazards

# Abre a última simulação do Pipeline no GTKWave
make waves-pipeline

# Executa o baseline Monociclo da Entrega 02 para comparação
make -C monociclo run

# Análise/elaboração rápida e compilação completa no Intel Quartus Prime (DE10-Lite)
make quartus
make quartus-build
make quartus-pgm

# Compila o relatório técnico IEEE em PDF (Tectonic) e slides
make relatorio
make apresentacao

# Remove artefatos temporários (.vvp, .vcd, Quartus)
make clean
```

---

## Validação Atual e Baseline Comparativo

* **Suíte RTL Automatizada (Icarus Verilog):** **14 de 14 bancadas aprovadas (0 falhas, 0 warnings de compilação)** via `make test` ([`scripts/run_all_tests.sh`](scripts/run_all_tests.sh)), todas gerando formas de onda `.vcd` em `build/`.
* **Benchmark Oficial no Pipeline (`sort.bin`):** Ordenação *bare-metal* de `[88, 15, 42, 7, 99]` $\to$ `[7, 15, 42, 88, 99]` concluída em **205 ciclos** (`11` stalls *Load-Use*, `22` flushes, `42+18` forwardings em A e `19+12` em B).
* **Estresse ISA e Hazards (`teste_isa.bin` e `teste_hazards.bin`):** Validados por equivalência entre o simulador MARS 4.5 e a simulação RTL no `mips_pipeline_top`, cobrindo as 16 instruções, proteção de `$zero`, *Load-Use* (`lw->addi/add/sw/jr`), *flushes* sem `nop` e recursão dupla com `fib(7) = 13`.
* **Baseline Monociclo (`monociclo/`):** Síntese validada na FPGA Intel MAX 10 (`10M50DAF484C7G`) com **17.089 LEs** e **0 latches transparentes espúrios** (relatório anterior em [`docs/relatorio/relatorio_segunda_entrega.pdf`](docs/relatorio/relatorio_segunda_entrega.pdf)).

---

## Ambiente de Desenvolvimento e Ferramental

* **Síntese Lógica e Mapeamento FPGA:** Intel Quartus Prime Lite Edition (MAX 10 / DE10-Lite)
* **Simulação Comportamental RTL:** Icarus Verilog (`iverilog`) e MARS 4.5
* **Inspeção de Formas de Onda:** GTKWave
* **Documentação Científica e Tipografia:** LaTeX (`IEEEtran` / Tectonic) e Typst
* **Ambiente de Engenharia e Pair Programming:** Google Antigravity
