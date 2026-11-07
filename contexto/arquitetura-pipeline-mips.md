# Arquitetura e Especificação Técnica: MIPS 5 Estágios com Pipeline

Este documento estabelece o modelo arquitetural detalhado para o processador MIPS com pipeline de 5 estágios a ser desenvolvido para a **Terceira Avaliação Parcial** da disciplina de **Arquitetura de Sistemas Digitais e Laboratório (UFAM)**.

---

## 1. Visão Geral da Arquitetura Pipeline

O processador MIPS Pipeline divide a execução de instruções em 5 estágios síncronos clássicos (baseado em Patterson & Hennessy, *Computer Organization and Design*):

1. **IF (Instruction Fetch - Busca da Instrução):**
   - Leitura da instrução da memória de instruções (`instr_mem`) no endereço apontado por `PC`.
   - Cálculo sequencial do próximo endereço: `PC_plus_4 = PC + 4`.
   - Seleção do próximo PC via multiplexador (sequencial, desvio tomado ou salto).
   - Suporte a sinal `PC_Write` para controle de bolhas/stalls.

2. **ID (Instruction Decode / Register Read - Decodificação e Leitura de Registradores):**
   - Decodificação dos campos da instrução: `opcode` [31:26], `rs` [25:21], `rt` [20:16], `rd` [15:11], `shamt` [10:6], `funct` [5:0].
   - Leitura simultânea dos dois operandos no banco de registradores (`reg_file`).
   - Extensão de sinal do campo imediato de 16 bits para 32 bits (`sign_extend`).
   - Unidade de Controle Principal (`main_control`) gerando sinais para os estágios seguintes.
   - Detecção de perigos (*Hazard Detection Unit*) operando neste estágio.

3. **EX (Execute / Address Calculation - Execução e Cálculo de Endereços):**
   - Operações aritméticas e lógicas na ULA (`alu`).
   - Controle da ULA (`alu_control`) a partir de `ALUOp` e campo `funct`.
   - Multiplexadores de adiantamento (*Forwarding Muxes*) para selecionar entre operando do banco ou valores adiantados de `EX/MEM` e `MEM/WB`.
   - Multiplexador para selecionar entre dado de registrador ou imediato estendido (`ALUSrc`).
   - Cálculo do endereço de destino para instruções de desvio (`PC_branch = PC_plus_4 + (imm << 2)`).
   - Seleção do registrador de destino (`RegDst`: entre `rt` e `rd`, ou `$31` no caso de `jal`).

4. **MEM (Memory Access - Acesso à Memória de Dados):**
   - Escrita na memória de dados (`data_mem`) em instruções `sw`.
   - Leitura da memória de dados em instruções `lw`.
   - Resolução final de desvios condicionais (`Branch` e `Zero`), gerando sinal `PCSrc` e sinal de `Flush` (caso o desvio não seja adiantado para o estágio ID).

5. **WB (Write Back - Escrita no Banco de Registradores):**
   - Seleção do dado final a ser gravado no banco de registradores através de `MemtoReg`:
     - Dado vindo da memória (`ReadData`).
     - Resultado vindo da ULA (`ALUResult`).
     - Endereço de retorno `PC+4` (para `jal`).
   - Gravação síncrona no registrador especificado por `WriteReg` sob controle de `RegWrite`.

---

## 2. Registradores entre Estágios (Pipeline Registers)

Entre cada estágio sequencial, registradores de barramento síncronos capturam dados e sinais de controle na borda de subida do clock:

### 2.1. Registrador IF/ID (`pipe_if_id.v`)
- **Entradas:** `clk`, `rst`, `enable` (para stall via `IF_ID_Write`), `flush` (para descarte em branch/jump), `pc_plus_4_in`, `instr_in`.
- **Saídas:** `pc_plus_4_out`, `instr_out`.

### 2.2. Registrador ID/EX (`pipe_id_ex.v`)
- **Entradas de Controle:**
  - WB: `RegWrite`, `MemtoReg`.
  - MEM: `MemRead`, `MemWrite`, `Branch`, `BranchNE`.
  - EX: `ALUSrc`, `ALUOp`, `RegDst`.
- **Entradas de Dados:** `pc_plus_4_in`, `read_data1_in`, `read_data2_in`, `sign_ext_imm_in`, `rs_in`, `rt_in`, `rd_in`.
- **Sinal de Controle:** `flush` (zera sinais de controle para inserir bolha em perigo load-use).

### 2.3. Registrador EX/MEM (`pipe_ex_mem.v`)
- **Entradas de Controle:** WB (`RegWrite`, `MemtoReg`), MEM (`MemRead`, `MemWrite`, `Branch`, `BranchNE`).
- **Entradas de Dados:** `branch_target_in`, `zero_in`, `alu_result_in`, `write_data_in`, `write_reg_in`.

### 2.4. Registrador MEM/WB (`pipe_mem_wb.v`)
- **Entradas de Controle:** WB (`RegWrite`, `MemtoReg`).
- **Entradas de Dados:** `mem_read_data_in`, `alu_result_in`, `write_reg_in`.

---

## 3. Tratamento de Riscos (Hazards)

### 3.1. Riscos de Dados (RAW - Read After Write) & Forwarding Unit
Ocorre quando uma instrução precisa do resultado de uma instrução anterior que ainda não atingiu o estágio WB:
- **Encaminhamento EX/MEM para EX:**
  - Se `EX/MEM.RegWrite` ativo e `EX/MEM.WriteReg != 0` e `EX/MEM.WriteReg == ID/EX.rs` -> Encaminha `EX/MEM.ALUResult` para entrada A da ULA.
  - Se `EX/MEM.RegWrite` ativo e `EX/MEM.WriteReg != 0` e `EX/MEM.WriteReg == ID/EX.rt` -> Encaminha `EX/MEM.ALUResult` para entrada B da ULA.
- **Encaminhamento MEM/WB para EX:**
  - Se `MEM/WB.RegWrite` ativo e `MEM/WB.WriteReg != 0` e não satisfeito pelo encaminhamento anterior e `MEM/WB.WriteReg == ID/EX.rs` -> Encaminha dado de WB para entrada A da ULA.
  - Se `MEM/WB.RegWrite` ativo e `MEM/WB.WriteReg != 0` e não satisfeito pelo encaminhamento anterior e `MEM/WB.WriteReg == ID/EX.rt` -> Encaminha dado de WB para entrada B da ULA.

### 3.2. Risco de Dados com Carga (Load-Use Hazard) & Hazard Detection Unit
Ocorre quando uma instrução logo após um `lw` necessita do dado lido da memória. Como o dado só está disponível ao final do estágio MEM, é necessária a inserção de **1 ciclo de stall (bolha)**:
- **Condição de Detecção:**
  ```verilog
  if (ID_EX_MemRead && ((ID_EX_rt == IF_ID_rs) || (ID_EX_rt == IF_ID_rt))) begin
      // Stall
      PC_Write = 1'b0;        // Congela PC
      IF_ID_Write = 1'b0;     // Congela registrador IF/ID
      Control_Mux_Sel = 1'b1; // Zera sinais de controle enviados a ID/EX (insere NOP)
  end
  ```

### 3.3. Riscos de Controle (Branches e Jumps)
- **Branch (Desvio Condicional):** Quando o desvio é tomado (`PCSrc = 1`), a instrução buscada especulativamente deve ser descartada gerando sinal de `flush` no registrador `IF/ID`.
- **Jump / JAL / JR (Salto Incondicional):** O salto altera o fluxo no estágio ID/EX; instruções já carregadas no estágio IF devem sofrer `flush`.

---

## 4. Conjunto de Instruções Alvo

O caminho de dados com pipeline suporta integralmente as instruções necessárias para o algoritmo do benchmark:

| Categoria | Instruções Suportadas |
|---|---|
| **Tipo R** | `add`, `sub`, `and`, `or`, `slt`, `xor`, `nor`, `jr` |
| **Tipo I (Memória)** | `lw`, `sw` |
| **Tipo I (Imediatos)** | `addi`, `andi`, `ori`, `slti` |
| **Tipo I (Desvios)** | `beq`, `bne` |
| **Tipo J (Saltos)** | `j`, `jal` |

---

## 5. Mapeamento dos Registradores do Benchmark (Bubble Sort)

- `$a0` (`$4`): Endereço base do vetor `v`
- `$a1` (`$5`): Tamanho `n` ou argumento `k`
- `$s0` (`$16`): Índice do laço externo `i`
- `$s1` (`$17`): Índice do laço interno `j`
- `$sp` (`$29`): Ponteiro da pilha (inicializado em `0x000000FF` ou conforme o mapeamento)
- `$ra` (`$31`): Endereço de retorno de sub-rotina (`swap`)
