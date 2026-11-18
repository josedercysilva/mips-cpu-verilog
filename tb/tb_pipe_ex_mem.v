// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Testbench: tb_pipe_ex_mem — Validação do Registrador de Pipeline EX/MEM
// Descrição: Valida a transferência síncrona dos sinais de controle e dados,
//            reset assíncrono, retenção sob stall (enable=0) e zeramento
//            sob flush (flush=1).
// ============================================================================

`timescale 1ns / 1ps

module tb_pipe_ex_mem;

    localparam DATA_WIDTH     = 32;
    localparam ADDR_WIDTH     = 32;
    localparam REG_ADDR_WIDTH = 5;

    reg clk;
    reg rst;
    reg enable;
    reg flush;

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
    reg  [ADDR_WIDTH-1:0]     branch_target_in;
    reg                       zero_in;
    reg  [DATA_WIDTH-1:0]     alu_result_in;
    reg  [DATA_WIDTH-1:0]     write_data_in;
    reg  [REG_ADDR_WIDTH-1:0] write_reg_in;

    wire [ADDR_WIDTH-1:0]     pc_plus_4_out;
    wire [ADDR_WIDTH-1:0]     branch_target_out;
    wire                      zero_out;
    wire [DATA_WIDTH-1:0]     alu_result_out;
    wire [DATA_WIDTH-1:0]     write_data_out;
    wire [REG_ADDR_WIDTH-1:0] write_reg_out;

    integer tests  = 0;
    integer errors = 0;

    pipe_ex_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .flush(flush),

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
        .branch_target_in(branch_target_in),
        .zero_in(zero_in),
        .alu_result_in(alu_result_in),
        .write_data_in(write_data_in),
        .write_reg_in(write_reg_in),

        .pc_plus_4_out(pc_plus_4_out),
        .branch_target_out(branch_target_out),
        .zero_out(zero_out),
        .alu_result_out(alu_result_out),
        .write_data_out(write_data_out),
        .write_reg_out(write_reg_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/pipe_ex_mem.vcd");
        $dumpvars(0, tb_pipe_ex_mem);

        clk              = 0;
        rst              = 1;
        enable           = 1;
        flush            = 0;

        branch_in        = 1'b0;
        bne_in           = 1'b0;
        mem_read_in      = 1'b0;
        mem_write_in     = 1'b0;
        reg_write_in     = 1'b0;
        mem_to_reg_in    = 2'b00;

        pc_plus_4_in     = 32'h0;
        branch_target_in = 32'h0;
        zero_in          = 1'b0;
        alu_result_in    = 32'h0;
        write_data_in    = 32'h0;
        write_reg_in     = 5'd0;

        $display("==========================================================");
        $display("   Iniciando Testbench do Registrador EX/MEM (Passo 5)    ");
        $display("==========================================================");

        // Teste 1: Reset Assincrono
        #7;
        tests = tests + 1;
        if (reg_write_out === 1'b0 && mem_write_out === 1'b0 && mem_read_out === 1'b0 &&
            branch_out === 1'b0 && alu_result_out === 32'h0 && pc_plus_4_out === 32'h0) begin
            $display("[PASS 1] Reset assincrono inicial zerou controles e dados.");
        end else begin
            $display("[ERRO 1] Reset assincrono falhou!");
            errors = errors + 1;
        end

        // Teste 2: Carga de Instrucao Tipo-R (ex: add)
        rst              = 0;
        enable           = 1;
        flush            = 0;
        branch_in        = 1'b0;
        bne_in           = 1'b0;
        mem_read_in      = 1'b0;
        mem_write_in     = 1'b0;
        reg_write_in     = 1'b1;
        mem_to_reg_in    = 2'b00;

        pc_plus_4_in     = 32'h0040_0014;
        branch_target_in = 32'h0040_0020;
        zero_in          = 1'b0;
        alu_result_in    = 32'h0000_002A;
        write_data_in    = 32'h0000_0000;
        write_reg_in     = 5'd18; // $s2
        #10;

        tests = tests + 1;
        if (reg_write_out === 1'b1 && mem_to_reg_out === 2'b00 && mem_write_out === 1'b0 &&
            alu_result_out === 32'h2A && write_reg_out === 5'd18 && pc_plus_4_out === 32'h0040_0014) begin
            $display("[PASS 2] Carga normal de Tipo-R aprovada.");
        end else begin
            $display("[ERRO 2] Carga Tipo-R falhou!");
            errors = errors + 1;
        end

        // Teste 3: Carga de Memoria (sw)
        branch_in        = 1'b0;
        bne_in           = 1'b0;
        mem_read_in      = 1'b0;
        mem_write_in     = 1'b1;
        reg_write_in     = 1'b0;
        mem_to_reg_in    = 2'b00;

        pc_plus_4_in     = 32'h0040_0028;
        branch_target_in = 32'h0;
        zero_in          = 1'b0;
        alu_result_in    = 32'h0000_0080; // Endereco RAM
        write_data_in    = 32'hDEAD_BEEF; // Dado a gravar
        write_reg_in     = 5'd0;
        #10;

        tests = tests + 1;
        if (mem_write_out === 1'b1 && reg_write_out === 1'b0 &&
            alu_result_out === 32'h80 && write_data_out === 32'hDEAD_BEEF) begin
            $display("[PASS 3] Carga de gravacao de memoria (sw) aprovada.");
        end else begin
            $display("[ERRO 3] Carga de sw falhou!");
            errors = errors + 1;
        end

        // Teste 4: Carga de Branch com Zero Flag
        branch_in        = 1'b1;
        bne_in           = 1'b0;
        mem_read_in      = 1'b0;
        mem_write_in     = 1'b0;
        reg_write_in     = 1'b0;
        mem_to_reg_in    = 2'b00;

        pc_plus_4_in     = 32'h0040_0030;
        branch_target_in = 32'h0040_0050;
        zero_in          = 1'b1;
        alu_result_in    = 32'h0000_0000;
        write_data_in    = 32'h0;
        write_reg_in     = 5'd0;
        #10;

        tests = tests + 1;
        if (branch_out === 1'b1 && zero_out === 1'b1 &&
            branch_target_out === 32'h0040_0050) begin
            $display("[PASS 4] Carga de branch condicional (beq com zero=1) aprovada.");
        end else begin
            $display("[ERRO 4] Carga de branch falhou!");
            errors = errors + 1;
        end

        // Teste 5: Carga de jal (propagacao de pc_plus_4 para $ra)
        branch_in        = 1'b0;
        bne_in           = 1'b0;
        mem_read_in      = 1'b0;
        mem_write_in     = 1'b0;
        reg_write_in     = 1'b1;
        mem_to_reg_in    = 2'b10; // PC+4 selecionado em WB

        pc_plus_4_in     = 32'h0040_0048;
        branch_target_in = 32'h0;
        zero_in          = 1'b0;
        alu_result_in    = 32'h0;
        write_data_in    = 32'h0;
        write_reg_in     = 5'd31; // $ra
        #10;

        tests = tests + 1;
        if (mem_to_reg_out === 2'b10 && reg_write_out === 1'b1 &&
            write_reg_out === 5'd31 && pc_plus_4_out === 32'h0040_0048) begin
            $display("[PASS 5] Propagacao de pc_plus_4 para jal aprovada.");
        end else begin
            $display("[ERRO 5] Propagacao para jal falhou!");
            errors = errors + 1;
        end

        // Teste 6: Flush (Injecao de Bolha)
        flush            = 1;
        mem_write_in     = 1'b1;
        reg_write_in     = 1'b1;
        alu_result_in    = 32'hFFFF_FFFF;
        #10;

        tests = tests + 1;
        if (mem_write_out === 1'b0 && reg_write_out === 1'b0 &&
            alu_result_out === 32'h0) begin
            $display("[PASS 6] Injecao de Bolha (Flush=1) comprovada: controles e dados zerados.");
        end else begin
            $display("[ERRO 6] Flush falhou em zerar controles!");
            errors = errors + 1;
        end

        // Teste 7: Retencao sob enable=0 (Stall)
        flush            = 0;
        enable           = 1;
        mem_read_in      = 1'b1;
        reg_write_in     = 1'b1;
        mem_to_reg_in    = 2'b01;
        alu_result_in    = 32'h0000_0010;
        write_reg_in     = 5'd10;
        #10;

        // Congela
        enable           = 0;
        mem_read_in      = 1'b0;
        reg_write_in     = 1'b0;
        alu_result_in    = 32'h0000_0099;
        write_reg_in     = 5'd25;
        #10;

        tests = tests + 1;
        if (mem_read_out === 1'b1 && reg_write_out === 1'b1 &&
            alu_result_out === 32'h10 && write_reg_out === 5'd10) begin
            $display("[PASS 7] Congelamento sob enable=0 comprovado.");
        end else begin
            $display("[ERRO 7] Congelamento sob enable=0 falhou!");
            errors = errors + 1;
        end

        // Teste 8: Prioridade de Flush sobre Enable=0
        flush  = 1;
        enable = 0;
        #10;

        tests = tests + 1;
        if (mem_read_out === 1'b0 && reg_write_out === 1'b0 && alu_result_out === 32'h0) begin
            $display("[PASS 8] Prioridade de Flush sobre Enable=0 comprovada.");
        end else begin
            $display("[ERRO 8] Flush nao teve prioridade sobre Enable=0!");
            errors = errors + 1;
        end

        $display("==========================================================");
        $display("Resumo: %0d testes executados, %0d erros encontrados.", tests, errors);
        $display("==========================================================");

        if (errors === 0) begin
            $display(">>> TESTE DO REGISTRADOR EX/MEM (pipe_ex_mem) APROVADO COM 100%% DE SUCESSO! <<<");
        end else begin
            $display(">>> FALHAS DETECTADAS NO REGISTRADOR EX/MEM! <<<");
        end

        #5 $finish;
    end

endmodule
