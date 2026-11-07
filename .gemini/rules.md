# Diretrizes e Regras do Projeto MIPS com Pipeline (Entrega 03)

> **Autor das Regras e Mantenedor do Repositório (GitHub):** José Dercy Silva (<josedercysilva@gmail.com>) / [@josedercysilva](https://github.com/josedercysilva)

Este documento define o contexto operacional, convenções arquiteturais e restrições obrigatórias para o assistente **Antigravity** neste repositório.

---

## 1. Identificação do Projeto e Equipe
- **Disciplina:** Arquitetura de Sistemas Digitais e Laboratório (UFAM)
- **Professor:** Thiago Brito Bezerra
- **Autor e Mantenedor:** José Dercy Silva (<josedercysilva@gmail.com>)
- **Equipe:** José Dercy Vieira da Silva Filho, Vinicius Menezes.
- **Plataforma Alvo:** FPGA Intel MAX 10 / Altera DE10-Lite (10M50DAF484C7G)
- **Software de Síntese:** Intel Quartus Prime
- **Simulação RTL:** Icarus Verilog (`iverilog`) e GTKWave (`scripts/run_simulation.sh`, `scripts/run_all_tests.sh`)
- **Prazo da Entrega 03:** 13/11/2026, até às 13:59h (Pontuação Total: 8,0 pontos)

---

## 2. Regras Mandatórias de Hardware (Verilog HDL)
1. **Parametrização Obrigatória (Rubrica 3):**
   - Todo módulo deve obrigatoriamente declarar parâmetros para barramentos e dimensões (ex.: `parameter DATA_WIDTH = 32`, `ADDR_WIDTH = 32`). Módulos sem parametrização violam a rubrica de boas práticas e serão rejeitados.
2. **Modularização por Bibliotecas:**
   - **Caminho de Dados:** `src/datapath/` (ALU, Register File, Somadores, Multiplexadores parametrizados 2:1, 3:1, 4:1, Extensores de Sinal, Program Counter).
   - **Registradores de Pipeline:** `src/pipeline/` (`pipe_if_id.v`, `pipe_id_ex.v`, `pipe_ex_mem.v`, `pipe_mem_wb.v`) com sinais de habilitação (`enable` para stall) e reinicialização síncrona/assíncrona (`flush`/`rst`).
   - **Unidades de Resolução de Riscos (Hazards):** `src/hazard/` (`forwarding_unit.v` para adiantamentos de dados RAW; `hazard_detection_unit.v` para detecção de perigo Load-Use com geração de stalls/bolhas).
   - **Unidade de Controle:** `src/control/` (Unidade de Controle Principal `main_control.v` e Controle da ALU `alu_control.v`).
   - **Memória:** `src/memory/` (Memória de Instruções ROM `instr_mem.v` e Memória de Dados RAM `data_mem.v`).
   - **Top-Level:** `src/mips_pipeline_top.v` integrando os 5 estágios (IF, ID, EX, MEM, WB).
3. **Tratamento Rigoroso de Perigos (Hazards):**
   - **Riscos de Dados (RAW):** Resolvidos via *Forwarding Unit*, encaminhando resultados dos estágios EX/MEM e MEM/WB diretamente para as entradas da ULA sem paradas desnecessárias de pipeline.
   - **Risco Load-Use:** Resolvido pela *Hazard Detection Unit*, inserindo 1 ciclo de bolha (stall em `PC` e `IF/ID`, e zeramento dos sinais de controle em `ID/EX`).
   - **Riscos de Controle (Branches e Jumps):** Descarte correto de instruções especulativas através de pulsos de `flush` nos registradores de pipeline.
4. **Instruções Obrigatórias do Caminho de Dados:**
   - Tipo R: `add`, `sub`, `and`, `or`, `slt`, `xor`, `nor`, `jr`.
   - Tipo I: `lw`, `sw`, `addi`, `andi`, `ori`, `slti`, `beq`, `bne`.
   - Tipo J: `j`, `jal`.
5. **Testbenches Individuais e Top-Level (Rubrica 2):**
   - Todo componente deve ter seu testbench unitário em `tb/` (ex.: `tb_pipe_if_id.v`, `tb_forwarding_unit.v`, `tb_hazard_detection_unit.v`, `tb_mips_pipeline_top.v`).
   - Todos os testes devem compilar e executar via Icarus Verilog gerando formas de onda `.vcd` para validação no GTKWave.

---

## 3. Convenção de Registradores do Benchmark (Bubble Sort)
Para conformidade estrita com o roteiro da disciplina e o código C/Assembly oficial:
- `$a0` (`$4`): Endereço base do vetor `v`
- `$a1` (`$5`): Tamanho `n` ou argumento `k`
- `$s0` (`$16`): Variável `i` do laço externo
- `$s1` (`$17`): Variável `j` do laço interno
- `$sp` (`$29`): Ponteiro de pilha
- `$ra` (`$31`): Endereço de retorno de procedimento (`swap`)

---

## 4. Padrões do Relatório Técnico (LaTeX)
- Local: `docs/relatorio/`
- Arquivo principal: `relatorio_terceira_entrega.tex`
- Compilador padrão: **Tectonic** (`tectonic relatorio_terceira_entrega.tex` ou script local)
- Modelo obrigatório: **IEEE Conference (`IEEEtran`)**
- Conteúdo essencial: Descrição da arquitetura de 5 estágios, detalhamento dos registradores entre estágios, funcionamento do forwarding e hazard detection, comparação de métricas de desempenho (IPC e contagem de ciclos) contra o processador monociclo da Entrega 02, formas de onda do GTKWave comprovando a ordenação do vetor via Bubble Sort, e estimativas de recursos na FPGA Intel MAX 10.

---

## 5. Padrões da Apresentação em Vídeo (YouTube)
- **Duração:** Cerca de 10 minutos.
- **Plataforma:** YouTube (link listado ou público).
- **Conteúdo:** Apresentação da arquitetura, explicação da resolução de hazards (Forwarding e Stalls), execução da simulação do Bubble Sort no testbench do pipeline e análise das formas de onda no GTKWave.

---

## 6. Fluxo de Trabalho, Versionamento e Git
- **Gestão do Repositório (José Dercy):**
  - **Branch Protection:** Proibido push direto na branch `main`. Todo desenvolvimento deve ocorrer em branches de funcionalidade e ser integrado via Pull Request (PR).
  - **Contratos de Interface (Skeletons):** O desenvolvimento de qualquer módulo inicia pela definição das portas (`input`, `output`) e parâmetros (`DATA_WIDTH`, etc.) antes da implementação da lógica interna.
  - **Critérios de Aceitação de PR (conforme `.github/PULL_REQUEST_TEMPLATE.md`):**
    1. **Contrato de Interface:** Portas e parâmetros rigorosamente mantidos.
    2. **Testbench Unitário:** Testbench atualizado ou criado na pasta `tb/`.
    3. **Simulação RTL:** Compilação e execução local sem erros via Icarus Verilog (`iverilog`).
    4. **Validação Visual:** Inspeção das formas de onda no GTKWave demonstrando integridade lógica e ausência de glitches ou corridas.
    5. **Commit Limpo:** Proibido versionar arquivos gerados (`.vcd`, `.out`, `.vvp`, arquivos temporários do Quartus).
  - **Aprovação Mandatória:** Nenhum PR pode sofrer merge sem revisão e aprovação explícita do mantenedor (@josedercysilva).
