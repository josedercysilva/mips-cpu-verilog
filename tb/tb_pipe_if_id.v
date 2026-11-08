// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho <josedercysilva@gmail.com>
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// Desenvolvido com auxílio de: Google Antigravity (Google DeepMind) — Gemini 3.8 Flash
// ----------------------------------------------------------------------------
// Testbench: tb_pipe_if_id — Validação do Registrador de Pipeline IF/ID
// Descrição: Valida a transferência síncrona, reset assíncrono, congelamento
//            sob stall (enable=0) e limpeza sob flush (flush=1).
// ============================================================================

`timescale 1ns / 1ps

module tb_pipe_if_id;

    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;

    // Sinais de estímulo
    reg                  clk;
    reg                  rst;
    reg                  enable;
    reg                  flush;
    reg [ADDR_WIDTH-1:0] pc_plus_4_in;
    reg [DATA_WIDTH-1:0] instr_in;

    // Sinais de monitoramento
    wire [ADDR_WIDTH-1:0] pc_plus_4_out;
    wire [DATA_WIDTH-1:0] instr_out;

    integer tests  = 0;
    integer errors = 0;

    // Instanciação da UUT (Unit Under Test)
    pipe_if_id #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .flush(flush),
        .pc_plus_4_in(pc_plus_4_in),
        .instr_in(instr_in),
        .pc_plus_4_out(pc_plus_4_out),
        .instr_out(instr_out)
    );

    // Gerador de Clock (período de 10ns -> 100MHz)
    always #5 clk = ~clk;

    initial begin
        // Configuração de dump para GTKWave
        $dumpfile("build/pipe_if_id.vcd");
        $dumpvars(0, tb_pipe_if_id);

        // Inicialização de sinais
        clk          = 0;
        rst          = 1;
        enable       = 1;
        flush        = 0;
        pc_plus_4_in = 32'h0000_0000;
        instr_in     = 32'h0000_0000;

        $display("==========================================================");
        $display("   Iniciando Testbench do Registrador IF/ID (Passo 3)     ");
        $display("==========================================================");

        // --------------------------------------------------------------------
        // Teste 1: Reset Assíncrono Ativo
        // --------------------------------------------------------------------
        #7; // Tempo intermediário antes da borda
        tests = tests + 1;
        if (pc_plus_4_out === 32'h0 && instr_out === 32'h0) begin
            $display("[PASS 1] Reset assíncrono inicial zerou saídas com sucesso.");
        end else begin
            $display("[ERRO 1] Reset falhou! pc_plus_4=0x%08h, instr=0x%08h", pc_plus_4_out, instr_out);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Teste 2: Desativação do Reset e Carga Normal 1
        // Instrução: addi $t0, $zero, 5 (0x20080005) com PC+4 = 0x00400004
        // --------------------------------------------------------------------
        rst          = 0;
        enable       = 1;
        flush        = 0;
        pc_plus_4_in = 32'h0040_0004;
        instr_in     = 32'h2008_0005;
        #10; // Avança 1 ciclo completo de clock

        tests = tests + 1;
        if (pc_plus_4_out === 32'h0040_0004 && instr_out === 32'h2008_0005) begin
            $display("[PASS 2] Carga normal ciclo 1 aprovada: PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
        end else begin
            $display("[ERRO 2] Carga normal ciclo 1 falhou! Obtido PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Teste 3: Carga Normal Ciclo 2
        // Instrução: lw $t1, 0($t0) (0x8D090000) com PC+4 = 0x00400008
        // --------------------------------------------------------------------
        pc_plus_4_in = 32'h0040_0008;
        instr_in     = 32'h8D09_0000;
        #10;

        tests = tests + 1;
        if (pc_plus_4_out === 32'h0040_0008 && instr_out === 32'h8D09_0000) begin
            $display("[PASS 3] Carga normal ciclo 2 aprovada: PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
        end else begin
            $display("[ERRO 3] Carga normal ciclo 2 falhou! Obtido PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Teste 4: Congelamento sob Stall (enable = 0)
        // Novas entradas na porta: add $t2, $t1, $t0 (0x01285020) com PC+4 = 0x0040000C
        // Como enable = 0, as saídas DEVEM manter o valor do Ciclo 2!
        // --------------------------------------------------------------------
        enable       = 0;
        pc_plus_4_in = 32'h0040_000C;
        instr_in     = 32'h0128_5020;
        #10;

        tests = tests + 1;
        if (pc_plus_4_out === 32'h0040_0008 && instr_out === 32'h8D09_0000) begin
            $display("[PASS 4] Congelamento sob Stall (enable=0) comprovado: PC+4 retido=0x%08h, Instr retida=0x%08h", pc_plus_4_out, instr_out);
        end else begin
            $display("[ERRO 4] Falha no stall! Saída alterou indevidamente para PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Teste 5: Retenção Multi-Ciclo durante Stall Prolongado
        // Altera entradas mais uma vez com enable ainda em 0
        // --------------------------------------------------------------------
        pc_plus_4_in = 32'h0040_0010;
        instr_in     = 32'h0000_0000;
        #10;

        tests = tests + 1;
        if (pc_plus_4_out === 32'h0040_0008 && instr_out === 32'h8D09_0000) begin
            $display("[PASS 5] Retenção em múltiplos ciclos de stall mantida com sucesso.");
        end else begin
            $display("[ERRO 5] Falha na retenção de stall prolongado! Obtido PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Teste 6: Retomada do Fluxo Normal Pós-Stall (enable = 1)
        // --------------------------------------------------------------------
        enable       = 1;
        pc_plus_4_in = 32'h0040_000C;
        instr_in     = 32'h0128_5020;
        #10;

        tests = tests + 1;
        if (pc_plus_4_out === 32'h0040_000C && instr_out === 32'h0128_5020) begin
            $display("[PASS 6] Retomada de avanço (enable=1) após stall aprovada: PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
        end else begin
            $display("[ERRO 6] Retomada após stall falhou! Obtido PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Teste 7: Limpeza Síncrona sob Flush (flush = 1, enable = 1)
        // Simula branch tomado: instrução buscada indevidamente deve ser descartada
        // --------------------------------------------------------------------
        flush        = 1;
        pc_plus_4_in = 32'h0040_0010;
        instr_in     = 32'h0149_5820; // add $t3, $t2, $t1
        #10;

        tests = tests + 1;
        if (pc_plus_4_out === 32'h0 && instr_out === 32'h0) begin
            $display("[PASS 7] Limpeza sob Flush (flush=1) aprovada: saídas zeradas (NOP injetado).");
        end else begin
            $display("[ERRO 7] Flush falhou! Esperado 0, obtido PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Teste 8: Recuperação Normal após Flush (flush = 0, enable = 1)
        // Alvo do branch chega no registrador
        // --------------------------------------------------------------------
        flush        = 0;
        pc_plus_4_in = 32'h0040_0080;
        instr_in     = 32'h2002_0001; // addi $v0, $zero, 1
        #10;

        tests = tests + 1;
        if (pc_plus_4_out === 32'h0040_0080 && instr_out === 32'h2002_0001) begin
            $display("[PASS 8] Retorno à operação normal pós-flush aprovado.");
        end else begin
            $display("[ERRO 8] Retorno pós-flush falhou! Obtido PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Teste 9: Prioridade de Flush sobre Stall (flush = 1, enable = 0)
        // Se houver conflito simultâneo de flush e stall, o descarte prevalece
        // --------------------------------------------------------------------
        flush        = 1;
        enable       = 0;
        pc_plus_4_in = 32'h0040_0084;
        instr_in     = 32'h2003_0002;
        #10;

        tests = tests + 1;
        if (pc_plus_4_out === 32'h0 && instr_out === 32'h0) begin
            $display("[PASS 9] Prioridade de Flush sobre Stall (flush=1, enable=0) comprovada.");
        end else begin
            $display("[ERRO 9] Flush não teve prioridade sobre Stall! Obtido PC+4=0x%08h, Instr=0x%08h", pc_plus_4_out, instr_out);
            errors = errors + 1;
        end

        // --------------------------------------------------------------------
        // Relatório Final do Testbench
        // --------------------------------------------------------------------
        $display("==========================================================");
        $display("Resumo: %0d testes executados, %0d erros encontrados.", tests, errors);
        $display("==========================================================");

        if (errors === 0) begin
            $display(">>> TESTE DO REGISTRADOR IF/ID (pipe_if_id) APROVADO COM 100%% DE SUCESSO! <<<");
        end else begin
            $display(">>> FALHAS DETECTADAS NO REGISTRADOR IF/ID! <<<");
        end

        #5 $finish;
    end

endmodule
