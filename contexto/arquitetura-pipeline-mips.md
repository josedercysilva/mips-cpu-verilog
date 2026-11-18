# Arquitetura Implementada: Processador MIPS Pipeline de 5 Estágios

Este documento descreve **com fidelidade ao RTL existente** a arquitetura do processador MIPS com pipeline implementada em `src/`, servindo de referência técnica direta para desenvolvimento, depuração, testbenches e redação do relatório IEEE.

---

## 1. Visão Geral dos 5 Estágios (`src/mips_pipeline_top.v`)

A microarquitetura segue o modelo clássico de Patterson & Hennessy com arquitetura **Harvard** (ROM de instruções e RAM de dados separadas), dividida em 5 estágios síncronos:

1. **IF (*Instruction Fetch*):**
   - `pc` (`src/datapath/pc.v`): registra `if_pc` (inicia em `32'd0` no `reset`), com entrada `enable` controlada por `pc_write`.
   - `pc_adder_inst` (`src/datapath/adder.v`): calcula `if_pc_plus_4 = if_pc + 4`.
   - `instr_mem_inst` (`src/memory/instr_mem.v`): leitura combinacional de `rom[addr[9:2]]` carregada via `$readmemb("assembly-mips/sort.bin", rom)`.
   - Seleção de `next_pc` por prioridade:
     1. `ex_branch_taken` → `ex_branch_target`
     2. `ex_jr` → `ex_forward_a_data`
     3. `id_jump_taken` (`id_jump & ~control_mux_sel`) → `id_pc_jump`
     4. Padrão → `if_pc_plus_4`

2. **ID (*Instruction Decode / Register Read*):**
   - Decodifica `id_instr` vinda de `pipe_if_id`.
   - `main_control` (`src/control/main_control.v`) gera os sinais de controle a partir de `id_opcode`; `id_is_jr` desabilita `id_reg_write` quando a instrução é `jr` (`opcode == 000000` e `funct == 001000`).
   - `hazard_detection_unit` (`src/hazard/hazard_detection_unit.v`) verifica conflito *Load-Use* com o estágio EX (`id_ex_mem_read` e `id_ex_rt != 0` coincidindo com `if_id_rs` ou `if_id_rt`). Quando ativo, zera `pc_write`, `if_id_write` e coloca `control_mux_sel = 1` (zerando os sinais de controle enviados para `pipe_id_ex` e suprimindo `id_jump_taken`).
   - `reg_file` (`src/datapath/reg_file.v`): leitura combinacional em `id_rs`/`id_rt` e escrita síncrona em `wb_write_reg`, com **write-through interno WB → ID** em `mips_pipeline_top.v` (se `wb_reg_write && wb_write_reg != 0` coincidir com `id_rs` ou `id_rt`, repassa `wb_write_data` imediatamente).
   - No `reset`, `reg_file` inicializa `$sp = 256`, `$a0 = 0` e `$a1 = 5` (bootloader bare-metal para o benchmark `sort.bin`).
   - `sign_extend` (`src/datapath/sign_extend.v`) estende `id_imm16` para 32 bits.
   - Calcula `id_pc_jump = {id_pc_plus_4[31:28], id_target, 2'b00}` para `j` e `jal`.

3. **EX (*Execute / Address & Branch Resolution*):**
   - `forwarding_unit` (`src/hazard/forwarding_unit.v`) gera `forward_a` e `forward_b`:
     - `2'b10`: adianta `mem_alu_result` de `EX/MEM` (maior prioridade).
     - `2'b01`: adianta `wb_write_data` de `MEM/WB`.
     - `2'b00`: usa `ex_read_data1` / `ex_read_data2` de `ID/EX`.
     - Protege `$0`: nunca adianta quando `write_reg == 0`.
   - `ex_alu_src_b`: mux entre `ex_forward_b_data` e `ex_sign_ext_imm` (via `ex_alu_src`).
   - `alu_control` (`src/control/alu_control.v`): recebe `ex_alu_op` e `funct = ex_sign_ext_imm[5:0]` e gera `ex_alu_ctrl` e `ex_jr`.
   - `alu` (`src/datapath/alu.v`): executa `AND`, `OR`, `ADD`, `SLL`, `SUB`, `SLT`, `NOR` e gera a flag `ex_zero`.
   - **Resolução de desvios no estágio EX:**
     - `branch_adder_inst` calcula `ex_branch_target = ex_pc_plus_4 + (ex_sign_ext_imm << 2)`.
     - `ex_branch_taken = (ex_branch & ex_zero) | (ex_bne & ~ex_zero)`.
     - Quando `ex_branch_taken` ou `ex_jr` é ativo, gera `if_id_flush` e `id_ex_flush` para descartar as instruções especulativas nos estágios anteriores.
   - Seleção do registrador destino `ex_write_reg`: `ex_rd` (`2'b01`), `$31/$ra` (`2'b10`, para `jal`) ou `ex_rt` (`default`).

4. **MEM (*Memory Access*):**
   - `data_mem` (`src/memory/data_mem.v`): leitura combinacional protegida por `mem_mem_read` e escrita síncrona em `posedge clk` quando `mem_mem_write == 1`, indexada por `mem_alu_result[9:2]`.
   - Inicialização de hardware para o benchmark: `ram[0..4] = {88, 15, 42, 7, 99}`.

5. **WB (*Write Back*):**
   - Seleciona `wb_write_data` via `wb_mem_to_reg`:
     - `2'b01`: `wb_read_data` (`lw`)
     - `2'b10`: `wb_pc_plus_4` (`jal`)
     - `default` (`2'b00`): `wb_alu_result` (Tipo-R, `addi`, `slti`)
   - Escreve em `reg_file` na borda de subida do clock se `wb_reg_write == 1` e `wb_write_reg != 0`.

---

## 2. Registradores de Pipeline (`src/pipeline/`)

Todos possuem `clk`, `rst` (assíncrono ativo alto), `enable` e `flush` (síncrono prioritário sobre `enable`):
* **`pipe_if_id.v`**: `pc_plus_4`, `instr`.
* **`pipe_id_ex.v`**: controles EX (`reg_dst`, `alu_op`, `alu_src`), MEM (`branch`, `bne`, `mem_read`, `mem_write`), WB (`reg_write`, `mem_to_reg`) + dados (`pc_plus_4`, `read_data1`, `read_data2`, `sign_ext_imm`, `shamt`, `rs`, `rt`, `rd`).
* **`pipe_ex_mem.v`**: controles MEM/WB + dados (`pc_plus_4`, `branch_target`, `zero`, `alu_result`, `write_data`, `write_reg`).
* **`pipe_mem_wb.v`**: controles WB + dados (`pc_plus_4`, `mem_read_data`, `alu_result`, `write_reg`).

---

## 3. Conjunto de Instruções Suportadas (16 Instruções)

O hardware implementa exatamente as **16 instruções** necessárias ao MIPS clássico e ao algoritmo *Bubble Sort* (`assembly-mips/sort.s`):

| Categoria | Instruções | Observações |
|---|---|---|
| **Tipo R (ALU / Shift)** | `add`, `sub`, `and`, `or`, `slt`, `nor`, `sll` | `nop` = `0x00000000` (`sll $0, $0, 0`) |
| **Tipo R (Salto)** | `jr` | Desvio para registrador `rs`; suprime `reg_write` |
| **Tipo I (Memória)** | `lw`, `sw` | Endereçamento por palavra via `addr[9:2]` |
| **Tipo I (Imediatos)** | `addi`, `slti` | Imediato com extensão de sinal (`sign_extend`) |
| **Tipo I (Desvios)** | `beq`, `bne` | Resolvidos no estágio EX |
| **Tipo J (Saltos)** | `j`, `jal` | Alvo calculado em ID; `jal` grava `PC+4` em `$31` (`$ra`) |

*(Nota: o projeto **não** inclui nem requer instruções fora dessa lista, como `xor`, `andi` ou `ori`.)*

---

## 4. Mapeamento dos Registradores no Benchmark (`sort.s`)

* `$a0` (`$4`): endereço base do vetor `v` (`0`)
* `$a1` (`$5`): tamanho do vetor `n` (`5`) ou argumento `k`
* `$s0` (`$16`): índice externo `i`
* `$s1` (`$17`): índice interno `j`
* `$sp` (`$29`): ponteiro de pilha (inicia em `256`)
* `$ra` (`$31`): endereço de retorno de sub-rotina (`swap`)
