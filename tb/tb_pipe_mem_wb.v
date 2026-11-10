// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Testbench: tb_pipe_mem_wb — Validação do Registrador de Pipeline MEM/WB
// Descrição: Valida a transferência síncrona dos sinais de controle e dados
//            para o estágio de escrita no banco de registradores (WB), reset
//            assíncrono, retenção sob stall (enable=0) e zeramento sob flush.
// ============================================================================

`timescale 1ns / 1ps

module tb_pipe_mem_wb;

    localparam DATA_WIDTH     = 32;
    localparam ADDR_WIDTH     = 32;
    localparam REG_ADDR_WIDTH = 5;

    reg clk;
    reg rst;
    reg enable;
    reg flush;

    reg        reg_write_in;
    reg  [1:0] mem_to_reg_in;
    wire       reg_write_out;
    wire [1:0] mem_to_reg_out;

    reg  [ADDR_WIDTH-1:0]     pc_plus_4_in;
    reg  [DATA_WIDTH-1:0]     mem_read_data_in;
    reg  [DATA_WIDTH-1:0]     alu_result_in;
    reg  [REG_ADDR_WIDTH-1:0] write_reg_in;

    wire [ADDR_WIDTH-1:0]     pc_plus_4_out;
    wire [DATA_WIDTH-1:0]     mem_read_data_out;
    wire [DATA_WIDTH-1:0]     alu_result_out;
    wire [REG_ADDR_WIDTH-1:0] write_reg_out;

    integer tests  = 0;
    integer errors = 0;

    pipe_mem_wb #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .flush(flush),

        .reg_write_in(reg_write_in),
        .mem_to_reg_in(mem_to_reg_in),
        .reg_write_out(reg_write_out),
        .mem_to_reg_out(mem_to_reg_out),

        .pc_plus_4_in(pc_plus_4_in),
        .mem_read_data_in(mem_read_data_in),
        .alu_result_in(alu_result_in),
        .write_reg_in(write_reg_in),

        .pc_plus_4_out(pc_plus_4_out),
        .mem_read_data_out(mem_read_data_out),
        .alu_result_out(alu_result_out),
        .write_reg_out(write_reg_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/pipe_mem_wb.vcd");
        $dumpvars(0, tb_pipe_mem_wb);

        clk              = 0;
        rst              = 1;
        enable           = 1;
        flush            = 0;

        reg_write_in     = 1'b0;
        mem_to_reg_in    = 2'b00;

        pc_plus_4_in     = 32'h0;
        mem_read_data_in = 32'h0;
        alu_result_in    = 32'h0;
        write_reg_in     = 5'd0;

        $display("==========================================================");
        $display("   Iniciando Testbench do Registrador MEM/WB (Passo 6)    ");
        $display("==========================================================");

        // Teste 1: Reset Assincrono
        #7;
        tests = tests + 1;
        if (reg_write_out === 1'b0 && mem_to_reg_out === 2'b00 &&
            alu_result_out === 32'h0 && mem_read_data_out === 32'h0 &&
            pc_plus_4_out === 32'h0 && write_reg_out === 5'd0) begin
            $display("[PASS 1] Reset assincrono inicial zerou controles e dados.");
        end else begin
            $display("[ERRO 1] Reset assincrono falhou!");
            errors = errors + 1;
        end

        // Teste 2: Carga Tipo-R / ALU (ex: escrita do resultado de add em $s0)
        rst              = 0;
        enable           = 1;
        flush            = 0;
        reg_write_in     = 1'b1;
        mem_to_reg_in    = 2'b00; // ALU
        pc_plus_4_in     = 32'h0040_0014;
        alu_result_in    = 32'h0000_0058;
        mem_read_data_in = 32'h0000_0000;
        write_reg_in     = 5'd16; // $s0
        #10;

        tests = tests + 1;
        if (reg_write_out === 1'b1 && mem_to_reg_out === 2'b00 &&
            alu_result_out === 32'h58 && write_reg_out === 5'd16 &&
            pc_plus_4_out === 32'h0040_0014) begin
            $display("[PASS 2] Carga de resultado da ALU para WB aprovada.");
        end else begin
            $display("[ERRO 2] Carga de resultado da ALU falhou!");
            errors = errors + 1;
        end

        // Teste 3: Carga de Memoria (lw para $t0)
        reg_write_in     = 1'b1;
        mem_to_reg_in    = 2'b01; // Dado lido da RAM
        pc_plus_4_in     = 32'h0040_0028;
        alu_result_in    = 32'h0000_0080;
        mem_read_data_in = 32'h1234_5678;
        write_reg_in     = 5'd8;  // $t0
        #10;

        tests = tests + 1;
        if (reg_write_out === 1'b1 && mem_to_reg_out === 2'b01 &&
            mem_read_data_out === 32'h1234_5678 && write_reg_out === 5'd8) begin
            $display("[PASS 3] Carga de dado lido da RAM para WB aprovada.");
        end else begin
            $display("[ERRO 3] Carga de dado da RAM falhou!");
            errors = errors + 1;
        end

        // Teste 4: Carga de jal (retorno em $ra / $31)
        reg_write_in     = 1'b1;
        mem_to_reg_in    = 2'b10; // PC+4
        pc_plus_4_in     = 32'h0040_004C;
        alu_result_in    = 32'h0;
        mem_read_data_in = 32'h0;
        write_reg_in     = 5'd31; // $ra
        #10;

        tests = tests + 1;
        if (reg_write_out === 1'b1 && mem_to_reg_out === 2'b10 &&
            pc_plus_4_out === 32'h0040_004C && write_reg_out === 5'd31) begin
            $display("[PASS 4] Carga de endereco de retorno (jal) para $ra aprovada.");
        end else begin
            $display("[ERRO 4] Carga de jal falhou!");
            errors = errors + 1;
        end

        // Teste 5: Flush (Injecao de Bolha)
        flush            = 1;
        reg_write_in     = 1'b1;
        mem_to_reg_in    = 2'b01;
        alu_result_in    = 32'hFFFF_FFFF;
        write_reg_in     = 5'd20;
        #10;

        tests = tests + 1;
        if (reg_write_out === 1'b0 && mem_to_reg_out === 2'b00 &&
            alu_result_out === 32'h0 && write_reg_out === 5'd0) begin
            $display("[PASS 5] Injecao de Bolha (Flush=1) comprovada: controles e dados zerados.");
        end else begin
            $display("[ERRO 5] Flush falhou em zerar controles!");
            errors = errors + 1;
        end

        // Teste 6: Retencao sob enable=0 (Stall)
        flush            = 0;
        enable           = 1;
        reg_write_in     = 1'b1;
        mem_to_reg_in    = 2'b00;
        alu_result_in    = 32'h0000_0099;
        write_reg_in     = 5'd5;
        #10;

        // Congela
        enable           = 0;
        reg_write_in     = 1'b0;
        alu_result_in    = 32'h0000_0011;
        write_reg_in     = 5'd2;
        #10;

        tests = tests + 1;
        if (reg_write_out === 1'b1 && mem_to_reg_out === 2'b00 &&
            alu_result_out === 32'h99 && write_reg_out === 5'd5) begin
            $display("[PASS 6] Congelamento sob enable=0 comprovado.");
        end else begin
            $display("[ERRO 6] Congelamento sob enable=0 falhou!");
            errors = errors + 1;
        end

        // Teste 7: Prioridade de Flush sobre Enable=0
        flush  = 1;
        enable = 0;
        #10;

        tests = tests + 1;
        if (reg_write_out === 1'b0 && mem_to_reg_out === 2'b00 && alu_result_out === 32'h0) begin
            $display("[PASS 7] Prioridade de Flush sobre Enable=0 comprovada.");
        end else begin
            $display("[ERRO 7] Flush nao teve prioridade sobre Enable=0!");
            errors = errors + 1;
        end

        $display("==========================================================");
        $display("Resumo: %0d testes executados, %0d erros encontrados.", tests, errors);
        $display("==========================================================");

        if (errors === 0) begin
            $display(">>> TESTE DO REGISTRADOR MEM/WB (pipe_mem_wb) APROVADO COM 100%% DE SUCESSO! <<<");
        end else begin
            $display(">>> FALHAS DETECTADAS NO REGISTRADOR MEM/WB! <<<");
        end

        #5 $finish;
    end

endmodule
