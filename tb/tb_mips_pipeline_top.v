// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Testbench Top-Level: tb_mips_pipeline_top — Benchmark Bubble Sort (Passo 10)
// Descrição: Execução do algoritmo canônico Bubble Sort (sort.bin) no processador
//            MIPS com Pipeline de 5 estágios. Coleta métricas de desempenho
//            (ciclos, stalls, flushes, adiantamentos) e valida a ordenação do
//            vetor de 5 elementos na memória de dados RAM.
// ============================================================================

`timescale 1ns / 1ps

module tb_mips_pipeline_top;

    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;
    localparam MEM_DEPTH  = 256;

    reg clk;
    reg reset;

    wire [ADDR_WIDTH-1:0] pc;
    wire [DATA_WIDTH-1:0] instr;
    wire [DATA_WIDTH-1:0] alu_result;
    wire [DATA_WIDTH-1:0] dmem_data;
    wire                  dmem_write_enable;

    // Métricas de Desempenho e Telemetria
    integer cycles             = 0;
    integer stall_cycles       = 0;
    integer flush_cycles       = 0;
    integer fwd_a_ex_mem_count = 0;
    integer fwd_a_mem_wb_count = 0;
    integer fwd_b_ex_mem_count = 0;
    integer fwd_b_mem_wb_count = 0;
    integer errors             = 0;

    mips_pipeline_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .instr(instr),
        .alu_result(alu_result),
        .dmem_data(dmem_data),
        .dmem_write_enable(dmem_write_enable)
    );

    // Gerador de Clock (Período: 10ns -> 100 MHz)
    always #5 clk = ~clk;

    // Monitoramento síncrono ciclo a ciclo
    always @(posedge clk) begin
        if (!reset) begin
            cycles <= cycles + 1;

            // Contagem de stalls da Hazard Detection Unit
            if (uut.control_mux_sel) begin
                stall_cycles <= stall_cycles + 1;
            end

            // Contagem de flushes por desvios/saltos
            if (uut.if_id_flush) begin
                flush_cycles <= flush_cycles + 1;
            end

            // Contagem de adiantamentos na entrada A da ULA
            if (uut.forward_a == 2'b10) fwd_a_ex_mem_count <= fwd_a_ex_mem_count + 1;
            if (uut.forward_a == 2'b01) fwd_a_mem_wb_count <= fwd_a_mem_wb_count + 1;

            // Contagem de adiantamentos na entrada B da ULA / escrita da RAM
            if (uut.forward_b == 2'b10) fwd_b_ex_mem_count <= fwd_b_ex_mem_count + 1;
            if (uut.forward_b == 2'b01) fwd_b_mem_wb_count <= fwd_b_mem_wb_count + 1;
        end
    end

    initial begin
        $dumpfile("build/pipeline_top.vcd");
        $dumpvars(0, tb_mips_pipeline_top);

        clk   = 0;
        reset = 1;

        $display("============================================================================");
        $display("   UFAM / FEEC - Processador MIPS com Pipeline de 5 Estágios                ");
        $display("   Simulação Top-Level: Benchmark Bubble Sort (Passo 10)                    ");
        $display("============================================================================");

        $display("\n[ESTADO INICIAL DA MEMÓRIA RAM] Vetor Desordenado (Tempo 0):");
        $display("  ram[0] (0x00) = %0d", uut.data_mem_inst.ram[0]);
        $display("  ram[1] (0x04) = %0d", uut.data_mem_inst.ram[1]);
        $display("  ram[2] (0x08) = %0d", uut.data_mem_inst.ram[2]);
        $display("  ram[3] (0x0C) = %0d", uut.data_mem_inst.ram[3]);
        $display("  ram[4] (0x10) = %0d", uut.data_mem_inst.ram[4]);

        // Pulso de reset por 2 ciclos
        #20;
        @(posedge clk);
        #1;
        reset = 0;

        // Aguarda ordenação do vetor na RAM ou timeout de segurança (2000 ciclos)
        while (!((uut.data_mem_inst.ram[0] == 32'd7  &&
                  uut.data_mem_inst.ram[1] == 32'd15 &&
                  uut.data_mem_inst.ram[2] == 32'd42 &&
                  uut.data_mem_inst.ram[3] == 32'd88 &&
                  uut.data_mem_inst.ram[4] == 32'd99) || (cycles >= 2000))) begin
            @(posedge clk);
        end

        // Aguarda estabilização final do pipeline
        repeat (10) @(posedge clk);

        $display("\n[ESTADO FINAL DA MEMÓRIA RAM] Vetor Ordenado (Fim em %0d ciclos):", cycles);
        $display("  ram[0] (0x00) = %0d (Esperado:  7)", uut.data_mem_inst.ram[0]);
        $display("  ram[1] (0x04) = %0d (Esperado: 15)", uut.data_mem_inst.ram[1]);
        $display("  ram[2] (0x08) = %0d (Esperado: 42)", uut.data_mem_inst.ram[2]);
        $display("  ram[3] (0x0C) = %0d (Esperado: 88)", uut.data_mem_inst.ram[3]);
        $display("  ram[4] (0x10) = %0d (Esperado: 99)", uut.data_mem_inst.ram[4]);

        // Validações do Vetor
        if (uut.data_mem_inst.ram[0] !== 32'd7)  errors = errors + 1;
        if (uut.data_mem_inst.ram[1] !== 32'd15) errors = errors + 1;
        if (uut.data_mem_inst.ram[2] !== 32'd42) errors = errors + 1;
        if (uut.data_mem_inst.ram[3] !== 32'd88) errors = errors + 1;
        if (uut.data_mem_inst.ram[4] !== 32'd99) errors = errors + 1;

        // Validação da Convenção de Registradores MIPS ABI (GEMINI.md - Seção 3)
        $display("\n[CONVENÇÃO DE REGISTRADORES MIPS ABI]");
        $display("  $a0 ($4)  [Base do Vetor]   : 0x%08h (%0d)", uut.reg_file_inst.registers[4], uut.reg_file_inst.registers[4]);
        $display("  $a1 ($5)  [Tamanho n / k]   : 0x%08h (%0d)", uut.reg_file_inst.registers[5], uut.reg_file_inst.registers[5]);
        $display("  $s0 ($16) [Índice i externo]: 0x%08h (%0d)", uut.reg_file_inst.registers[16], uut.reg_file_inst.registers[16]);
        $display("  $s1 ($17) [Índice j interno]: 0x%08h (%0d)", uut.reg_file_inst.registers[17], uut.reg_file_inst.registers[17]);
        $display("  $sp ($29) [Ponteiro Pilha]  : 0x%08h (%0d)", uut.reg_file_inst.registers[29], uut.reg_file_inst.registers[29]);
        $display("  $ra ($31) [Retorno swap]    : 0x%08h", uut.reg_file_inst.registers[31]);

        // Relatório de Métricas de Desempenho do Pipeline
        $display("\n============================================================================");
        $display("   RELATÓRIO DE DESEMPENHO DO PIPELINE (Passo 10)                          ");
        $display("============================================================================");
        $display("  Total de Ciclos de Clock          : %0d", cycles);
        $display("  Período de Clock (T_clk)          : 10.0 ns (F_clk = 100 MHz)");
        $display("  Tempo Total de Execução           : %0d ns (%.3f us)", cycles * 10, (cycles * 10.0) / 1000.0);
        $display("  Ciclos de Congelamento (Stalls)   : %0d", stall_cycles);
        $display("  Ciclos de Esvaziamento (Flushes)  : %0d", flush_cycles);
        $display("  Total de Adiantamentos (Forwarding):");
        $display("    - Operando A (EX/MEM): %0d", fwd_a_ex_mem_count);
        $display("    - Operando A (MEM/WB): %0d", fwd_a_mem_wb_count);
        $display("    - Operando B (EX/MEM): %0d", fwd_b_ex_mem_count);
        $display("    - Operando B (MEM/WB): %0d", fwd_b_mem_wb_count);
        $display("============================================================================");

        if (errors === 0) begin
            $display(">>> BENCHMARK BUBBLE SORT CONCLUÍDO COM 100%% DE SUCESSO! <<<");
            $display("    Vetor ordenado com perfeição: [7, 15, 42, 88, 99]");
        end else begin
            $display(">>> FALHA NO BENCHMARK BUBBLE SORT! %0d erros detectados. <<<", errors);
        end
        $display("============================================================================");

        #10;
        $finish;
    end

endmodule
