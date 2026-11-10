// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Testbench: tb_pipe_id_ex — Validação do Registrador de Pipeline ID/EX
// Descrição: Valida a transferência síncrona dos sinais de controle e dados,
//            reset assíncrono, retenção sob stall (enable=0) e zeramento
//            de controles sob flush (flush=1) para injeção de bolha / NOP.
// ============================================================================

`timescale 1ns / 1ps

module tb_pipe_id_ex;

    localparam DATA_WIDTH     = 32;
    localparam ADDR_WIDTH     = 32;
    localparam REG_ADDR_WIDTH = 5;
    localparam ALU_OP_WIDTH   = 2;

    reg clk;
    reg rst;
    reg enable;
    reg flush;

    reg  [1:0]              reg_dst_in;
    reg  [ALU_OP_WIDTH-1:0] alu_op_in;
    reg                     alu_src_in;
    wire [1:0]              reg_dst_out;
    wire [ALU_OP_WIDTH-1:0] alu_op_out;
    wire                    alu_src_out;

    reg  branch_in;
    reg  bne_in;
    reg  mem_read_in;
    reg  mem_write_in;
    wire branch_out;
    wire bne_out;
    wire mem_read_out;
    wire mem_write_out;

    reg        reg_write_in;
    reg  [1:0] mem_to_reg_in;
    wire       reg_write_out;
    wire [1:0] mem_to_reg_out;

    reg  [ADDR_WIDTH-1:0]     pc_plus_4_in;
    reg  [DATA_WIDTH-1:0]     read_data1_in;
    reg  [DATA_WIDTH-1:0]     read_data2_in;
    reg  [DATA_WIDTH-1:0]     sign_ext_imm_in;
    reg  [4:0]                shamt_in;
    reg  [REG_ADDR_WIDTH-1:0] rs_in;
    reg  [REG_ADDR_WIDTH-1:0] rt_in;
    reg  [REG_ADDR_WIDTH-1:0] rd_in;

    wire [ADDR_WIDTH-1:0]     pc_plus_4_out;
    wire [DATA_WIDTH-1:0]     read_data1_out;
    wire [DATA_WIDTH-1:0]     read_data2_out;
    wire [DATA_WIDTH-1:0]     sign_ext_imm_out;
    wire [4:0]                shamt_out;
    wire [REG_ADDR_WIDTH-1:0] rs_out;
    wire [REG_ADDR_WIDTH-1:0] rt_out;
    wire [REG_ADDR_WIDTH-1:0] rd_out;

    integer tests  = 0;
    integer errors = 0;

    pipe_id_ex #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
        .ALU_OP_WIDTH(ALU_OP_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .flush(flush),

        .reg_dst_in(reg_dst_in),
        .alu_op_in(alu_op_in),
        .alu_src_in(alu_src_in),
        .reg_dst_out(reg_dst_out),
        .alu_op_out(alu_op_out),
        .alu_src_out(alu_src_out),

        .branch_in(branch_in),
        .bne_in(bne_in),
        .mem_read_in(mem_read_in),
        .mem_write_in(mem_write_in),
        .branch_out(branch_out),
        .bne_out(bne_out),
        .mem_read_out(mem_read_out),
        .mem_write_out(mem_write_out),

        .reg_write_in(reg_write_in),
        .mem_to_reg_in(mem_to_reg_in),
        .reg_write_out(reg_write_out),
        .mem_to_reg_out(mem_to_reg_out),

        .pc_plus_4_in(pc_plus_4_in),
        .read_data1_in(read_data1_in),
        .read_data2_in(read_data2_in),
        .sign_ext_imm_in(sign_ext_imm_in),
        .shamt_in(shamt_in),
        .rs_in(rs_in),
        .rt_in(rt_in),
        .rd_in(rd_in),

        .pc_plus_4_out(pc_plus_4_out),
        .read_data1_out(read_data1_out),
        .read_data2_out(read_data2_out),
        .sign_ext_imm_out(sign_ext_imm_out),
        .shamt_out(shamt_out),
        .rs_out(rs_out),
        .rt_out(rt_out),
        .rd_out(rd_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/pipe_id_ex.vcd");
        $dumpvars(0, tb_pipe_id_ex);

        clk             = 0;
        rst             = 1;
        enable          = 1;
        flush           = 0;
        reg_dst_in      = 2'b00;
        alu_op_in       = 2'b00;
        alu_src_in      = 1'b0;
        branch_in       = 1'b0;
        bne_in          = 1'b0;
        mem_read_in     = 1'b0;
        mem_write_in    = 1'b0;
        reg_write_in    = 1'b0;
        mem_to_reg_in   = 2'b00;

        pc_plus_4_in    = 32'h0;
        read_data1_in   = 32'h0;
        read_data2_in   = 32'h0;
        sign_ext_imm_in = 32'h0;
        shamt_in        = 5'd0;
        rs_in           = 5'd0;
        rt_in           = 5'd0;
        rd_in           = 5'd0;

        $display("==========================================================");
        $display("   Iniciando Testbench do Registrador ID/EX (Passo 4)     ");
        $display("==========================================================");

        // Teste 1: Reset Assincrono
        #7;
        tests = tests + 1;
        if (reg_write_out === 1'b0 && mem_write_out === 1'b0 && mem_read_out === 1'b0 &&
            pc_plus_4_out === 32'h0 && read_data1_out === 32'h0 && read_data2_out === 32'h0) begin
            $display("[PASS 1] Reset assincrono inicial zerou controles e dados.");
        end else begin
            $display("[ERRO 1] Reset assincrono falhou!");
            errors = errors + 1;
        end

        // Teste 2: Carga Tipo-R
        rst             = 0;
        enable          = 1;
        flush           = 0;
        reg_dst_in      = 2'b01;
        alu_op_in       = 2'b10;
        alu_src_in      = 1'b0;
        branch_in       = 1'b0;
        bne_in          = 1'b0;
        mem_read_in     = 1'b0;
        mem_write_in    = 1'b0;
        reg_write_in    = 1'b1;
        mem_to_reg_in   = 2'b00;

        pc_plus_4_in    = 32'h0040_0014;
        read_data1_in   = 32'h0000_000A;
        read_data2_in   = 32'h0000_0000;
        sign_ext_imm_in = 32'h0000_0000;
        shamt_in        = 5'd0;
        rs_in           = 5'd4;
        rt_in           = 5'd0;
        rd_in           = 5'd18;
        #10;

        tests = tests + 1;
        if (reg_dst_out === 2'b01 && alu_op_out === 2'b10 && alu_src_out === 1'b0 &&
            reg_write_out === 1'b1 && mem_to_reg_out === 2'b00 &&
            pc_plus_4_out === 32'h0040_0014 && read_data1_out === 32'hA &&
            rs_out === 5'd4 && rt_out === 5'd0 && rd_out === 5'd18) begin
            $display("[PASS 2] Carga normal de instrucao Tipo-R aprovada.");
        end else begin
            $display("[ERRO 2] Carga normal Tipo-R falhou!");
            errors = errors + 1;
        end

        // Teste 3: Instrucao com Shamt e Imediato
        reg_dst_in      = 2'b01;
        alu_op_in       = 2'b10;
        alu_src_in      = 1'b0;
        branch_in       = 1'b0;
        bne_in          = 1'b0;
        mem_read_in     = 1'b0;
        mem_write_in    = 1'b0;
        reg_write_in    = 1'b1;
        mem_to_reg_in   = 2'b00;

        pc_plus_4_in    = 32'h0040_0034;
        read_data1_in   = 32'h0000_0000;
        read_data2_in   = 32'h0000_0003;
        sign_ext_imm_in = 32'h0000_0080;
        shamt_in        = 5'd2;
        rs_in           = 5'd0;
        rt_in           = 5'd17;
        rd_in           = 5'd9;
        #10;

        tests = tests + 1;
        if (shamt_out === 5'd2 && rt_out === 5'd17 && rd_out === 5'd9 &&
            pc_plus_4_out === 32'h0040_0034 && read_data2_out === 32'd3) begin
            $display("[PASS 3] Campo shamt e registradores para shift validados.");
        end else begin
            $display("[ERRO 3] Carga de instrucao com shamt falhou! shamt_out=%d", shamt_out);
            errors = errors + 1;
        end

        // Teste 4: Flush (Injecao de Bolha)
        flush           = 1;
        reg_dst_in      = 2'b00;
        alu_op_in       = 2'b00;
        alu_src_in      = 1'b1;
        branch_in       = 1'b1;
        bne_in          = 1'b0;
        mem_read_in     = 1'b1;
        mem_write_in    = 1'b1;
        reg_write_in    = 1'b1;
        mem_to_reg_in   = 2'b01;

        pc_plus_4_in    = 32'h0040_0038;
        read_data1_in   = 32'h1234_5678;
        read_data2_in   = 32'h9ABC_DEF0;
        sign_ext_imm_in = 32'h0000_0004;
        shamt_in        = 5'd0;
        rs_in           = 5'd29;
        rt_in           = 5'd8;
        rd_in           = 5'd0;
        #10;

        tests = tests + 1;
        if (reg_write_out === 1'b0 && mem_write_out === 1'b0 && mem_read_out === 1'b0 &&
            branch_out === 1'b0 && bne_out === 1'b0 && reg_dst_out === 2'b00 &&
            alu_src_out === 1'b0 && mem_to_reg_out === 2'b00 &&
            pc_plus_4_out === 32'h0) begin
            $display("[PASS 4] Injecao de Bolha (Flush=1) comprovada: controles zerados.");
        end else begin
            $display("[ERRO 4] Flush falhou em zerar controles!");
            errors = errors + 1;
        end

        // Teste 5: Retomada Pos-Flush
        flush           = 0;
        enable          = 1;
        reg_dst_in      = 2'b00;
        alu_op_in       = 2'b00;
        alu_src_in      = 1'b1;
        branch_in       = 1'b0;
        bne_in          = 1'b0;
        mem_read_in     = 1'b1;
        mem_write_in    = 1'b0;
        reg_write_in    = 1'b1;
        mem_to_reg_in   = 2'b01;

        pc_plus_4_in    = 32'h0040_003C;
        read_data1_in   = 32'h0000_0100;
        read_data2_in   = 32'h0000_0000;
        sign_ext_imm_in = 32'h0000_0008;
        shamt_in        = 5'd0;
        rs_in           = 5'd29;
        rt_in           = 5'd10;
        rd_in           = 5'd0;
        #10;

        tests = tests + 1;
        if (mem_read_out === 1'b1 && reg_write_out === 1'b1 && mem_to_reg_out === 2'b01 &&
            pc_plus_4_out === 32'h0040_003C && rt_out === 5'd10) begin
            $display("[PASS 5] Retomada de avanco pos-flush aprovada.");
        end else begin
            $display("[ERRO 5] Retomada pos-flush falhou!");
            errors = errors + 1;
        end

        // Teste 6: Retencao sob enable=0
        enable          = 0;
        mem_read_in     = 1'b0;
        reg_write_in    = 1'b0;
        pc_plus_4_in    = 32'h0040_0040;
        rt_in           = 5'd15;
        #10;

        tests = tests + 1;
        if (mem_read_out === 1'b1 && reg_write_out === 1'b1 && mem_to_reg_out === 2'b01 &&
            pc_plus_4_out === 32'h0040_003C && rt_out === 5'd10) begin
            $display("[PASS 6] Congelamento sob enable=0 comprovado.");
        end else begin
            $display("[ERRO 6] Falha no congelamento com enable=0!");
            errors = errors + 1;
        end

        // Teste 7: Prioridade de Flush sobre Enable=0
        flush  = 1;
        enable = 0;
        #10;

        tests = tests + 1;
        if (reg_write_out === 1'b0 && mem_read_out === 1'b0 && pc_plus_4_out === 32'h0) begin
            $display("[PASS 7] Prioridade de Flush sobre Enable=0 comprovada.");
        end else begin
            $display("[ERRO 7] Flush nao teve prioridade sobre Enable=0!");
            errors = errors + 1;
        end

        $display("==========================================================");
        $display("Resumo: %0d testes executados, %0d erros encontrados.", tests, errors);
        $display("==========================================================");

        if (errors === 0) begin
            $display(">>> TESTE DO REGISTRADOR ID/EX (pipe_id_ex) APROVADO COM 100%% DE SUCESSO! <<<");
        end else begin
            $display(">>> FALHAS DETECTADAS NO REGISTRADOR ID/EX! <<<");
        end

        #5 $finish;
    end

endmodule
