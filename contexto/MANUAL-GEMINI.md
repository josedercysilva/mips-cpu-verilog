# Manual de Contexto Rápido para Novos Chats (Gemini / Antigravity)

Leia este guia antes de propor alterações, responder dúvidas ou editar código neste repositório.

---

## 1. O que é este projeto
* **Disciplina:** Arquitetura de Sistemas Digitais e Laboratório (UFAM / FEEC) — Prof. Thiago Brito Bezerra.
* **Equipe:** José Dercy Vieira da Silva Filho ([@josedercysilva](https://github.com/josedercysilva)) e Vinicius Menezes.
* **Objetivo da Entrega 03:** Implementar, testar e documentar um **processador MIPS 32 bits com Pipeline de 5 estágios** (`IF`, `ID`, `EX`, `MEM`, `WB`) em **Verilog HDL**, com todos os módulos parametrizados (`parameter`), testbenches individuais e top-level, síntese em FPGA **Intel MAX 10 / Terasic DE10-Lite** (`10M50DAF484C7G`), relatório técnico no padrão **IEEE (`IEEEtran`)** e vídeo no YouTube (~10 min).
* **Prazo oficial do Classroom:** **18/11/2026 até às 13:59h** (vale 8,0 pontos).
* **Texto original do Classroom:** `contexto/arquivo-original-classroom.md`.
* **Especificação C/Assembly do benchmark:** `contexto/projeto-arquitetura-integra.md` *(não modificar este arquivo)*.

---

## 2. Estado Atual do Repositório (Onde Estamos)

1. **Hardware RTL (`src/`) — Implementado e Funcional:**
   - Todos os 20 módulos em `src/` já existem e são parametrizados.
   - O Top-Level `src/mips_pipeline_top.v` integra os 5 estágios, os 4 registradores de pipeline (`src/pipeline/`), `forwarding_unit.v` e `hazard_detection_unit.v` (`src/hazard/`).
   - O conjunto de instruções suportado tem **16 instruções** (`add`, `sub`, `and`, `or`, `slt`, `nor`, `sll`, `jr`, `lw`, `sw`, `addi`, `slti`, `beq`, `bne`, `j`, `jal`).
   - **Não invente instruções extras** (`xor`, `andi`, `ori` foram apenas notas antigas e **não** fazem parte da especificação do professor).
   - *Observação técnica conhecida em `src/mips_pipeline_top.v`:* atualmente `if_id_flush = ex_branch_taken | ex_jr` (não dá flush em `id_jump_taken`, o que funciona em `sort.bin` porque `assembly-mips/sort.s` tem `nop` após `j`/`jal`; se testar código sem `nop` após `j`/`jal`, convém incluir `id_jump_taken` em `if_id_flush` e encaminhar `mem_pc_plus_4` em `EX/MEM` para `jal`).

2. **Simulação e Testbenches (`tb/`, `scripts/`, `Makefile`) — 13/13 Passando:**
   - `make test` roda `./scripts/run_all_tests.sh` no Icarus Verilog (`iverilog -g2012 -Wall`) e aprova todas as 13 bancadas.
   - `tb/tb_mips_pipeline_top.v` valida o benchmark *Bubble Sort* (`assembly-mips/sort.bin`), ordenando `[88, 15, 42, 7, 99]` → `[7, 15, 42, 88, 99]` em **205 ciclos**.
   - **Pendências pequenas nos TBs/scripts:** 4 testbenches (`tb_datapath_aux.v`, `tb_reg_file.v`, `tb_instr_mem.v`, `tb_data_mem.v`) ainda não geram `.vcd`; `tb_alu.v` tem warning de `shamt` flutuante; `tb_control_unit.v` não conecta `bne`; `scripts/run_simulation.sh` tem mensagem de ajuda antiga na linha 116.

3. **Arquitetura Legada Isolada (`monociclo/`):**
   - Contém a versão Monociclo da Entrega 02 (`make -C monociclo run`), preservada para comparação de métricas (ciclos/IPC/área) no relatório.

4. **Documentação, Quartus e Entrega — O que ainda falta:**
   - Atualizar `README.md` raiz e `assembly-mips/README.md` (atualmente desatualizados).
   - Rodar síntese do pipeline no Intel Quartus Prime (`quartus/mips_pipeline.qpf` / `.qsf`, `make quartus-build`) em máquina com Quartus instalado para coletar LEs e $F_{\max}$.
   - Escrever o relatório IEEE da Entrega 03 em `docs/relatorio/` (hoje lá ainda está o `relatorio_segunda_entrega.tex`).
   - Atualizar os slides em `docs/apresentacao/slides_apresentacao.tex`, gravar o vídeo no YouTube e integrar via Pull Request na branch `main`.

---

## 3. Mapa Rápido de Arquivos

```text
.
├── AGENTS.md / GEMINI.md        -> Regras obrigatórias de engenharia (AGENTS / .gemini/rules.md)
├── Makefile                     -> Alvos: test, pipeline_top, waves-pipeline, quartus*, relatorio, clean
├── assembly-mips/               -> Firmwares bare-metal (sort.s, sort.bin, teste_isa.s) e mars/
├── contexto/                    -> Especificação do Classroom, arquitetura real e este manual
├── docs/                        -> Relatório LaTeX (IEEEtran + Tectonic) e slides Beamer
├── formal_test/                 -> Verificação formal SVA (forwarding_unit e control_unit)
├── monociclo/                   -> Baseline Monociclo da Entrega 02 (para comparação)
├── notas/                       -> Anotações locais e checklists (ignorado pelo Git)
├── quartus/                     -> Projeto Quartus MAX 10 (mips_pipeline.qpf / .qsf)
├── scripts/                     -> run_simulation.sh, run_all_tests.sh, view_waves.sh, clean.sh, *.gtkw
├── src/                         -> Código Verilog HDL parametrizado (control, datapath, hazard, memory, pipeline)
└── tb/                          -> 13 testbenches unitários e top-level
```

---

## 4. Comandos Mais Úteis

```bash
make test              # Roda todas as 13 simulações no Icarus Verilog
make pipeline_top      # Simula apenas o Top-Level do pipeline com sort.bin
make waves-pipeline    # Abre build/pipeline_top.vcd com scripts/pipeline_top.gtkw
make -C monociclo run  # Roda o baseline Monociclo da Entrega 02
make clean             # Remove build/, .vvp, .vcd e temporários do Quartus
make relatorio         # Compila relatório LaTeX via Tectonic
make quartus           # Analysis & Elaboration no Quartus (requer Quartus no PATH/QUARTUS_BIN_DIR)
```

---

## 5. Regras de Ouro ao Trabalhar Aqui

1. **Nunca dê push direto na branch `main`:** desenvolva em branches de trabalho (a partir de `feat/mips-pipeline-core`) e integre via PR após revisão de `@josedercysilva`.
2. **Mantenha todos os módulos parametrizados:** nunca remova ou deixe de usar `parameter` em módulos de `src/`.
3. **Respeite o escopo de instruções:** use apenas as **16 instruções** descritas em `contexto/arquitetura-pipeline-mips.md` (não adicione novas instruções sem pedido explícito do usuário).
4. **Não toque nos arquivos originais da disciplina:** preserve `contexto/arquivo-original-classroom.md` e `contexto/projeto-arquitetura-integra.md`.
5. **Não execute comandos `git` sem autorização expressa:** mesmo em autonomia total, não rode nenhum comando `git`; o usuário utiliza Git + Antigravity manualmente para depurar e revisar todas as mudanças. Além disso, mantenha o repositório limpo (sem `.vcd`, `.vvp`, `build/` ou temporários do Quartus).
6. **Sempre valide após editar Verilog:** rode `make test` (ou `./scripts/run_simulation.sh <alvo>`) e reporte apenas o que realmente foi executado e observado.
