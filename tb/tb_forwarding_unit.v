// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Testbench: tb_forwarding_unit — Validação da Unidade de Encaminhamento
// Descrição: Valida os adiantamentos EX/MEM (2'b10), MEM/WB (2'b01), prioridade
//            em conflitos duplos e proteção contra adiantamento em $0.
// ============================================================================

`timescale 1ns / 1ps

module tb_forwarding_unit;

    localparam REG_ADDR_WIDTH = 5;

    reg  [REG_ADDR_WIDTH-1:0] id_ex_rs;
    reg  [REG_ADDR_WIDTH-1:0] id_ex_rt;
    reg                       ex_mem_reg_write;
    reg  [REG_ADDR_WIDTH-1:0] ex_mem_write_reg;
    reg                       mem_wb_reg_write;
    reg  [REG_ADDR_WIDTH-1:0] mem_wb_write_reg;

    wire [1:0]                forward_a;
    wire [1:0]                forward_b;

    integer tests  = 0;
    integer errors = 0;

    forwarding_unit #(
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    ) uut (
        .id_ex_rs(id_ex_rs),
        .id_ex_rt(id_ex_rt),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_write_reg(ex_mem_write_reg),
        .mem_wb_reg_write(mem_wb_reg_write),
        .mem_wb_write_reg(mem_wb_write_reg),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    initial begin
        $dumpfile("build/forwarding_unit.vcd");
        $dumpvars(0, tb_forwarding_unit);

        id_ex_rs          = 5'd0;
        id_ex_rt          = 5'd0;
        ex_mem_reg_write  = 1'b0;
        ex_mem_write_reg  = 5'd0;
        mem_wb_reg_write  = 1'b0;
        mem_wb_write_reg  = 5'd0;

        $display("==========================================================");
        $display("   Iniciando Testbench da Forwarding Unit (Passo 7)       ");
        $display("==========================================================");

        // Teste 1: Sem dependencias
        #10;
        id_ex_rs = 5'd1;
        id_ex_rt = 5'd2;
        #1;
        tests = tests + 1;
        if (forward_a === 2'b00 && forward_b === 2'b00) begin
            $display("[PASS 1] Sem hazard: ForwardA=00 e ForwardB=00.");
        end else begin
            $display("[ERRO 1] Falha quando nao ha hazard! A=%b, B=%b", forward_a, forward_b);
            errors = errors + 1;
        end

        // Teste 2: Hazard EX/MEM no operando A
        id_ex_rs          = 5'd8; // $t0
        id_ex_rt          = 5'd2;
        ex_mem_reg_write  = 1'b1;
        ex_mem_write_reg  = 5'd8; // $t0
        mem_wb_reg_write  = 1'b0;
        mem_wb_write_reg  = 5'd0;
        #1;
        tests = tests + 1;
        if (forward_a === 2'b10 && forward_b === 2'b00) begin
            $display("[PASS 2] Hazard EX/MEM em rs aprovado (ForwardA=10).");
        end else begin
            $display("[ERRO 2] Falha no hazard EX/MEM em rs! A=%b, B=%b", forward_a, forward_b);
            errors = errors + 1;
        end

        // Teste 3: Hazard EX/MEM no operando B
        id_ex_rs          = 5'd1;
        id_ex_rt          = 5'd9; // $t1
        ex_mem_reg_write  = 1'b1;
        ex_mem_write_reg  = 5'd9; // $t1
        #1;
        tests = tests + 1;
        if (forward_a === 2'b00 && forward_b === 2'b10) begin
            $display("[PASS 3] Hazard EX/MEM em rt aprovado (ForwardB=10).");
        end else begin
            $display("[ERRO 3] Falha no hazard EX/MEM em rt! A=%b, B=%b", forward_a, forward_b);
            errors = errors + 1;
        end

        // Teste 4: Hazard MEM/WB no operando A
        id_ex_rs          = 5'd10; // $t2
        id_ex_rt          = 5'd1;
        ex_mem_reg_write  = 1'b0;
        ex_mem_write_reg  = 5'd0;
        mem_wb_reg_write  = 1'b1;
        mem_wb_write_reg  = 5'd10; // $t2
        #1;
        tests = tests + 1;
        if (forward_a === 2'b01 && forward_b === 2'b00) begin
            $display("[PASS 4] Hazard MEM/WB em rs aprovado (ForwardA=01).");
        end else begin
            $display("[ERRO 4] Falha no hazard MEM/WB em rs! A=%b, B=%b", forward_a, forward_b);
            errors = errors + 1;
        end

        // Teste 5: Hazard MEM/WB no operando B
        id_ex_rs          = 5'd1;
        id_ex_rt          = 5'd11; // $t3
        mem_wb_reg_write  = 1'b1;
        mem_wb_write_reg  = 5'd11; // $t3
        #1;
        tests = tests + 1;
        if (forward_a === 2'b00 && forward_b === 2'b01) begin
            $display("[PASS 5] Hazard MEM/WB em rt aprovado (ForwardB=01).");
        end else begin
            $display("[ERRO 5] Falha no hazard MEM/WB em rt! A=%b, B=%b", forward_a, forward_b);
            errors = errors + 1;
        end

        // Teste 6: Prioridade de EX/MEM sobre MEM/WB (Double Data Hazard)
        id_ex_rs          = 5'd16; // $s0
        id_ex_rt          = 5'd16; // $s0
        ex_mem_reg_write  = 1'b1;
        ex_mem_write_reg  = 5'd16; // $s0 (Mais recente)
        mem_wb_reg_write  = 1'b1;
        mem_wb_write_reg  = 5'd16; // $s0 (Mais antigo)
        #1;
        tests = tests + 1;
        if (forward_a === 2'b10 && forward_b === 2'b10) begin
            $display("[PASS 6] Prioridade de EX/MEM sobre MEM/WB aprovada (10 tem precedencia sobre 01).");
        end else begin
            $display("[ERRO 6] Falha de prioridade em double data hazard! A=%b, B=%b", forward_a, forward_b);
            errors = errors + 1;
        end

        // Teste 7: Protecao contra adiantamento no registrador $0 ($zero)
        id_ex_rs          = 5'd0; // $zero
        id_ex_rt          = 5'd0; // $zero
        ex_mem_reg_write  = 1'b1;
        ex_mem_write_reg  = 5'd0; // Escrita ficticia em $zero
        mem_wb_reg_write  = 1'b1;
        mem_wb_write_reg  = 5'd0; // Escrita ficticia em $zero
        #1;
        tests = tests + 1;
        if (forward_a === 2'b00 && forward_b === 2'b00) begin
            $display("[PASS 7] Protecao do registrador $0 aprovada: nunca adianta $0.");
        end else begin
            $display("[ERRO 7] $0 foi adiantado indevidamente! A=%b, B=%b", forward_a, forward_b);
            errors = errors + 1;
        end

        // Teste 8: RegWrite inativo (ex: sw ou branch com destino coincidente)
        id_ex_rs          = 5'd17;
        id_ex_rt          = 5'd18;
        ex_mem_reg_write  = 1'b0; // Nao grava!
        ex_mem_write_reg  = 5'd17;
        mem_wb_reg_write  = 1'b0; // Nao grava!
        mem_wb_write_reg  = 5'd18;
        #1;
        tests = tests + 1;
        if (forward_a === 2'b00 && forward_b === 2'b00) begin
            $display("[PASS 8] RegWrite inativo respeitado: sem adiantamentos indevidos.");
        end else begin
            $display("[ERRO 8] Adiantamento com RegWrite=0 falhou! A=%b, B=%b", forward_a, forward_b);
            errors = errors + 1;
        end

        // Teste 9: Encaminhamento misto (rs de EX/MEM e rt de MEM/WB)
        id_ex_rs          = 5'd4;  // $a0
        id_ex_rt          = 5'd5;  // $a1
        ex_mem_reg_write  = 1'b1;
        ex_mem_write_reg  = 5'd4;  // $a0
        mem_wb_reg_write  = 1'b1;
        mem_wb_write_reg  = 5'd5;  // $a1
        #1;
        tests = tests + 1;
        if (forward_a === 2'b10 && forward_b === 2'b01) begin
            $display("[PASS 9] Encaminhamento misto simultaneo aprovado (ForwardA=10, ForwardB=01).");
        end else begin
            $display("[ERRO 9] Encaminhamento misto falhou! A=%b, B=%b", forward_a, forward_b);
            errors = errors + 1;
        end

        $display("==========================================================");
        $display("Resumo: %0d testes executados, %0d erros encontrados.", tests, errors);
        $display("==========================================================");

        if (errors === 0) begin
            $display(">>> TESTE DA FORWARDING UNIT (forwarding_unit) APROVADO COM 100%% DE SUCESSO! <<<");
        end else begin
            $display(">>> FALHAS DETECTADAS NA FORWARDING UNIT! <<<");
        end

        #5 $finish;
    end

endmodule
