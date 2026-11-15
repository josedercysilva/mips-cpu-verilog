// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Módulo: mips_pipeline_top — Top-Level do Processador MIPS com Pipeline
// Descrição: Integração estrutural dos 5 estágios (IF, ID, EX, MEM, WB),
//            dos 4 registradores de pipeline, das unidades de Forwarding
//            e Hazard Detection, e das memórias de instrução e dados.
// ============================================================================

`timescale 1ns / 1ps

module mips_pipeline_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_DEPTH  = 256,
    parameter INIT_FILE  = "assembly-mips/sort.bin"
) (
    input  wire                  clk,
    input  wire                  reset,
    output wire [ADDR_WIDTH-1:0] pc,
    output wire [DATA_WIDTH-1:0] instr,
    output wire [DATA_WIDTH-1:0] alu_result,
    output wire [DATA_WIDTH-1:0] dmem_data,
    output wire                  dmem_write_enable
);

    // ========================================================================
    // SINAIS DE CONTROLE DE FLUXO GLOBAL (Flush e Next PC)
    // ========================================================================
    wire                  if_id_flush;
    wire                  id_ex_flush;
    reg  [ADDR_WIDTH-1:0] next_pc;

    // ========================================================================
    // ESTÁGIO 1: BUSCA DE INSTRUÇÃO (IF - Instruction Fetch)
    // ========================================================================
    wire [ADDR_WIDTH-1:0] if_pc;
    wire [ADDR_WIDTH-1:0] if_pc_plus_4;
    wire [DATA_WIDTH-1:0] if_instr;
    wire                  pc_write;
    wire                  if_id_write;

    pc #(.DATA_WIDTH(ADDR_WIDTH)) pc_inst (
        .clk(clk),
        .reset(reset),
        .enable(pc_write),
        .pc_in(next_pc),
        .pc_out(if_pc)
    );

    adder #(.DATA_WIDTH(ADDR_WIDTH)) pc_adder_inst (
        .a(if_pc),
        .b({{(ADDR_WIDTH-3){1'b0}}, 3'd4}),
        .result(if_pc_plus_4)
    );

    instr_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE(INIT_FILE)
    ) instr_mem_inst (
        .addr(if_pc),
        .instr(if_instr)
    );

    // ========================================================================
    // REGISTRADOR DE PIPELINE IF/ID
    // ========================================================================
    wire [ADDR_WIDTH-1:0] id_pc_plus_4;
    wire [DATA_WIDTH-1:0] id_instr;

    pipe_if_id #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) pipe_if_id_inst (
        .clk(clk),
        .rst(reset),
        .enable(if_id_write),
        .flush(if_id_flush),
        .pc_plus_4_in(if_pc_plus_4),
        .instr_in(if_instr),
        .pc_plus_4_out(id_pc_plus_4),
        .instr_out(id_instr)
    );

    // ========================================================================
    // ESTÁGIO 2: DECODIFICAÇÃO E BANCO DE REGISTRADORES (ID)
    // ========================================================================
    wire [5:0]  id_opcode = id_instr[31:26];
    wire [4:0]  id_rs     = id_instr[25:21];
    wire [4:0]  id_rt     = id_instr[20:16];
    wire [4:0]  id_rd     = id_instr[15:11];
    wire [4:0]  id_shamt  = id_instr[10:6];
    wire [5:0]  id_funct  = id_instr[5:0];
    wire [15:0] id_imm16  = id_instr[15:0];
    wire [25:0] id_target = id_instr[25:0];

    wire [1:0] id_reg_dst;
    wire       id_jump;
    wire       id_jal;
    wire       id_branch;
    wire       id_bne;
    wire       id_mem_read;
    wire [1:0] id_mem_to_reg;
    wire [1:0] id_alu_op;
    wire       id_mem_write;
    wire       id_alu_src;
    wire       id_reg_write_raw;

    main_control #(
        .OPCODE_WIDTH(6),
        .ALU_OP_WIDTH(2)
    ) main_ctrl_inst (
        .opcode(id_opcode),
        .reg_dst(id_reg_dst),
        .jump(id_jump),
        .jal(id_jal),
        .branch(id_branch),
        .bne(id_bne),
        .mem_read(id_mem_read),
        .mem_to_reg(id_mem_to_reg),
        .alu_op(id_alu_op),
        .mem_write(id_mem_write),
        .alu_src(id_alu_src),
        .reg_write(id_reg_write_raw)
    );

    // Instrução JR não deve escrever no Banco de Registradores
    wire id_is_jr = (id_opcode == 6'b000000) && (id_funct == 6'b001000);
    wire id_reg_write = id_reg_write_raw & ~id_is_jr;

    // Unidade de Detecção de Riscos (Hazard Detection Unit)
    wire [4:0] ex_rt;
    wire       ex_mem_read;
    wire       control_mux_sel;

    hazard_detection_unit #(
        .REG_ADDR_WIDTH(5)
    ) hazard_unit_inst (
        .id_ex_rt(ex_rt),
        .id_ex_mem_read(ex_mem_read),
        .if_id_rs(id_rs),
        .if_id_rt(id_rt),
        .pc_write(pc_write),
        .if_id_write(if_id_write),
        .control_mux_sel(control_mux_sel)
    );

    // MUX de inserção de Bolha (NOP) quando houver Stall de Load-Use
    wire [1:0] id_reg_dst_mux    = control_mux_sel ? 2'b00 : id_reg_dst;
    wire [1:0] id_alu_op_mux     = control_mux_sel ? 2'b00 : id_alu_op;
    wire       id_alu_src_mux    = control_mux_sel ? 1'b0  : id_alu_src;
    wire       id_branch_mux     = control_mux_sel ? 1'b0  : id_branch;
    wire       id_bne_mux        = control_mux_sel ? 1'b0  : id_bne;
    wire       id_mem_read_mux   = control_mux_sel ? 1'b0  : id_mem_read;
    wire       id_mem_write_mux  = control_mux_sel ? 1'b0  : id_mem_write;
    wire       id_reg_write_mux  = control_mux_sel ? 1'b0  : id_reg_write;
    wire [1:0] id_mem_to_reg_mux = control_mux_sel ? 2'b00 : id_mem_to_reg;

    // Banco de Registradores
    wire                  wb_reg_write;
    wire [4:0]            wb_write_reg;
    reg  [DATA_WIDTH-1:0] wb_write_data;
    wire [DATA_WIDTH-1:0] id_raw_read_data1;
    wire [DATA_WIDTH-1:0] id_raw_read_data2;

    reg_file #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_REGS(32),
        .ADDR_WIDTH(5)
    ) reg_file_inst (
        .clk(clk),
        .reset(reset),
        .reg_write(wb_reg_write),
        .read_reg1(id_rs),
        .read_reg2(id_rt),
        .write_reg(wb_write_reg),
        .write_data(wb_write_data),
        .read_data1(id_raw_read_data1),
        .read_data2(id_raw_read_data2)
    );

    // Encaminhamento interno WB -> ID (Write-Through)
    wire [DATA_WIDTH-1:0] id_read_data1 = (wb_reg_write && (wb_write_reg != 5'd0) && (wb_write_reg == id_rs)) ?
                                          wb_write_data : id_raw_read_data1;
    wire [DATA_WIDTH-1:0] id_read_data2 = (wb_reg_write && (wb_write_reg != 5'd0) && (wb_write_reg == id_rt)) ?
                                          wb_write_data : id_raw_read_data2;

    // Extensor de Sinal
    wire [DATA_WIDTH-1:0] id_sign_ext_imm;
    sign_extend #(
        .IN_WIDTH(16),
        .OUT_WIDTH(DATA_WIDTH)
    ) sign_ext_inst (
        .in(id_imm16),
        .out(id_sign_ext_imm)
    );

    // Endereço de Salto Incondicional (J / JAL)
    wire [ADDR_WIDTH-1:0] id_pc_jump    = {id_pc_plus_4[31:28], id_target, 2'b00};
    wire                  id_jump_taken = id_jump & ~control_mux_sel;

    // ========================================================================
    // REGISTRADOR DE PIPELINE ID/EX
    // ========================================================================
    wire [1:0]            ex_reg_dst;
    wire [1:0]            ex_alu_op;
    wire                  ex_alu_src;
    wire                  ex_branch;
    wire                  ex_bne;
    wire                  ex_mem_write;
    wire                  ex_reg_write;
    wire [1:0]            ex_mem_to_reg;

    wire [ADDR_WIDTH-1:0] ex_pc_plus_4;
    wire [DATA_WIDTH-1:0] ex_read_data1;
    wire [DATA_WIDTH-1:0] ex_read_data2;
    wire [DATA_WIDTH-1:0] ex_sign_ext_imm;
    wire [4:0]            ex_shamt;
    wire [4:0]            ex_rs;
    wire [4:0]            ex_rd;

    pipe_id_ex #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .REG_ADDR_WIDTH(5),
        .ALU_OP_WIDTH(2)
    ) pipe_id_ex_inst (
        .clk(clk),
        .rst(reset),
        .enable(1'b1),
        .flush(id_ex_flush),
        
        .reg_dst_in(id_reg_dst_mux),
        .alu_op_in(id_alu_op_mux),
        .alu_src_in(id_alu_src_mux),
        .branch_in(id_branch_mux),
        .bne_in(id_bne_mux),
        .mem_read_in(id_mem_read_mux),
        .mem_write_in(id_mem_write_mux),
        .reg_write_in(id_reg_write_mux),
        .mem_to_reg_in(id_mem_to_reg_mux),
        
        .reg_dst_out(ex_reg_dst),
        .alu_op_out(ex_alu_op),
        .alu_src_out(ex_alu_src),
        .branch_out(ex_branch),
        .bne_out(ex_bne),
        .mem_read_out(ex_mem_read),
        .mem_write_out(ex_mem_write),
        .reg_write_out(ex_reg_write),
        .mem_to_reg_out(ex_mem_to_reg),
        
        .pc_plus_4_in(id_pc_plus_4),
        .read_data1_in(id_read_data1),
        .read_data2_in(id_read_data2),
        .sign_ext_imm_in(id_sign_ext_imm),
        .shamt_in(id_shamt),
        .rs_in(id_rs),
        .rt_in(id_rt),
        .rd_in(id_rd),
        
        .pc_plus_4_out(ex_pc_plus_4),
        .read_data1_out(ex_read_data1),
        .read_data2_out(ex_read_data2),
        .sign_ext_imm_out(ex_sign_ext_imm),
        .shamt_out(ex_shamt),
        .rs_out(ex_rs),
        .rt_out(ex_rt),
        .rd_out(ex_rd)
    );

    // ========================================================================
    // ESTÁGIO 3: EXECUÇÃO (EX)
    // ========================================================================
    wire                  mem_reg_write;
    wire [4:0]            mem_write_reg;
    wire [DATA_WIDTH-1:0] mem_alu_result;
    wire [1:0]            mem_mem_to_reg;
    wire [ADDR_WIDTH-1:0] mem_pc_plus_4;
    wire [1:0]            forward_a;
    wire [1:0]            forward_b;

    // Unidade de Encaminhamento (Forwarding Unit)
    forwarding_unit #(
        .REG_ADDR_WIDTH(5)
    ) forwarding_unit_inst (
        .id_ex_rs(ex_rs),
        .id_ex_rt(ex_rt),
        .ex_mem_reg_write(mem_reg_write),
        .ex_mem_write_reg(mem_write_reg),
        .mem_wb_reg_write(wb_reg_write),
        .mem_wb_write_reg(wb_write_reg),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    // Dado encaminhado do estagio EX/MEM (usa PC+4 quando a instrucao for JAL)
    wire [DATA_WIDTH-1:0] mem_forward_data = (mem_mem_to_reg == 2'b10) ? mem_pc_plus_4 : mem_alu_result;

    // Multiplexador de Forwarding A
    reg [DATA_WIDTH-1:0] ex_forward_a_data;
    always @(*) begin
        case (forward_a)
            2'b10:   ex_forward_a_data = mem_forward_data;
            2'b01:   ex_forward_a_data = wb_write_data;
            default: ex_forward_a_data = ex_read_data1;
        endcase
    end

    // Multiplexador de Forwarding B
    reg [DATA_WIDTH-1:0] ex_forward_b_data;
    always @(*) begin
        case (forward_b)
            2'b10:   ex_forward_b_data = mem_forward_data;
            2'b01:   ex_forward_b_data = wb_write_data;
            default: ex_forward_b_data = ex_read_data2;
        endcase
    end

    // Seleção entre Dado Forwarded e Imediato para a entrada B da ULA
    wire [DATA_WIDTH-1:0] ex_alu_src_b = ex_alu_src ? ex_sign_ext_imm : ex_forward_b_data;

    // Unidade de Controle da ALU
    wire [3:0] ex_alu_ctrl;
    wire       ex_jr;

    alu_control #(
        .ALU_OP_WIDTH(2),
        .FUNCT_WIDTH(6),
        .ALU_CTRL_WIDTH(4)
    ) alu_ctrl_inst (
        .alu_op(ex_alu_op),
        .funct(ex_sign_ext_imm[5:0]),
        .alu_ctrl(ex_alu_ctrl),
        .jr(ex_jr)
    );

    // Unidade Lógica e Aritmética (ALU)
    wire [DATA_WIDTH-1:0] ex_alu_result;
    wire                  ex_zero;

    alu #(
        .DATA_WIDTH(DATA_WIDTH),
        .ALU_CTRL_WIDTH(4)
    ) alu_inst (
        .src_a(ex_forward_a_data),
        .src_b(ex_alu_src_b),
        .shamt(ex_shamt),
        .alu_ctrl(ex_alu_ctrl),
        .alu_result(ex_alu_result),
        .zero(ex_zero)
    );

    // Somador de Endereço de Branch
    wire [ADDR_WIDTH-1:0] ex_branch_offset = {ex_sign_ext_imm[ADDR_WIDTH-3:0], 2'b00};
    wire [ADDR_WIDTH-1:0] ex_branch_target;

    adder #(.DATA_WIDTH(ADDR_WIDTH)) branch_adder_inst (
        .a(ex_pc_plus_4),
        .b(ex_branch_offset),
        .result(ex_branch_target)
    );

    // Condição de Desvio Tomado
    wire ex_branch_taken = (ex_branch & ex_zero) | (ex_bne & ~ex_zero);

    // Multiplexador de Seleção de Registrador Destino (RegDst)
    reg [4:0] ex_write_reg;
    always @(*) begin
        case (ex_reg_dst)
            2'b01:   ex_write_reg = ex_rd;
            2'b10:   ex_write_reg = 5'd31; // $ra para JAL
            default: ex_write_reg = ex_rt;
        endcase
    end

    // ========================================================================
    // REGISTRADOR DE PIPELINE EX/MEM
    // ========================================================================
    wire                  mem_branch;
    wire                  mem_bne;
    wire                  mem_mem_read;
    wire                  mem_mem_write;
    wire [ADDR_WIDTH-1:0] mem_branch_target;
    wire                  mem_zero;
    wire [DATA_WIDTH-1:0] mem_write_data;

    pipe_ex_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .REG_ADDR_WIDTH(5)
    ) pipe_ex_mem_inst (
        .clk(clk),
        .rst(reset),
        .enable(1'b1),
        .flush(1'b0),
        
        .branch_in(ex_branch),
        .bne_in(ex_bne),
        .mem_read_in(ex_mem_read),
        .mem_write_in(ex_mem_write),
        .reg_write_in(ex_reg_write),
        .mem_to_reg_in(ex_mem_to_reg),
        
        .branch_out(mem_branch),
        .bne_out(mem_bne),
        .mem_read_out(mem_mem_read),
        .mem_write_out(mem_mem_write),
        .reg_write_out(mem_reg_write),
        .mem_to_reg_out(mem_mem_to_reg),
        
        .pc_plus_4_in(ex_pc_plus_4),
        .branch_target_in(ex_branch_target),
        .zero_in(ex_zero),
        .alu_result_in(ex_alu_result),
        .write_data_in(ex_forward_b_data),
        .write_reg_in(ex_write_reg),
        
        .pc_plus_4_out(mem_pc_plus_4),
        .branch_target_out(mem_branch_target),
        .zero_out(mem_zero),
        .alu_result_out(mem_alu_result),
        .write_data_out(mem_write_data),
        .write_reg_out(mem_write_reg)
    );

    // ========================================================================
    // ESTÁGIO 4: ACESSO À MEMÓRIA (MEM)
    // ========================================================================
    wire [DATA_WIDTH-1:0] mem_read_data;

    data_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH)
    ) data_mem_inst (
        .clk(clk),
        .mem_read(mem_mem_read),
        .mem_write(mem_mem_write),
        .addr(mem_alu_result),
        .write_data(mem_write_data),
        .read_data(mem_read_data)
    );

    // ========================================================================
    // REGISTRADOR DE PIPELINE MEM/WB
    // ========================================================================
    wire [1:0]            wb_mem_to_reg;
    wire [ADDR_WIDTH-1:0] wb_pc_plus_4;
    wire [DATA_WIDTH-1:0] wb_read_data;
    wire [DATA_WIDTH-1:0] wb_alu_result;

    pipe_mem_wb #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .REG_ADDR_WIDTH(5)
    ) pipe_mem_wb_inst (
        .clk(clk),
        .rst(reset),
        .enable(1'b1),
        .flush(1'b0),
        
        .reg_write_in(mem_reg_write),
        .mem_to_reg_in(mem_mem_to_reg),
        
        .reg_write_out(wb_reg_write),
        .mem_to_reg_out(wb_mem_to_reg),
        
        .pc_plus_4_in(mem_pc_plus_4),
        .mem_read_data_in(mem_read_data),
        .alu_result_in(mem_alu_result),
        .write_reg_in(mem_write_reg),
        
        .pc_plus_4_out(wb_pc_plus_4),
        .mem_read_data_out(wb_read_data),
        .alu_result_out(wb_alu_result),
        .write_reg_out(wb_write_reg)
    );

    // ========================================================================
    // ESTÁGIO 5: ESCRITA NO BANCO (WB - Write Back)
    // ========================================================================
    always @(*) begin
        case (wb_mem_to_reg)
            2'b01:   wb_write_data = wb_read_data;
            2'b10:   wb_write_data = wb_pc_plus_4;
            default: wb_write_data = wb_alu_result;
        endcase
    end

    // ========================================================================
    // CONTROLE DE FLUXO: ESVAZIAMENTO (FLUSH) E PRÓXIMO PC
    // ========================================================================
    assign if_id_flush = ex_branch_taken | ex_jr | id_jump_taken;
    assign id_ex_flush = ex_branch_taken | ex_jr;

    always @(*) begin
        if (ex_branch_taken) begin
            next_pc = ex_branch_target;
        end else if (ex_jr) begin
            next_pc = ex_forward_a_data;
        end else if (id_jump_taken) begin
            next_pc = id_pc_jump;
        end else begin
            next_pc = if_pc_plus_4;
        end
    end

    // ========================================================================
    // SAÍDAS TOP-LEVEL
    // ========================================================================
    assign pc                = if_pc;
    assign instr             = if_instr;
    assign alu_result        = mem_alu_result;
    assign dmem_data         = mem_write_data;
    assign dmem_write_enable = mem_mem_write;

endmodule
