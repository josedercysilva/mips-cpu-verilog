// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Testbench Top-Level: tb_mips_pipeline_top — Integração Completa do Pipeline
// Descrição: Valida a execução completa do processador MIPS com pipeline de
//            5 estágios executando o benchmark Bubble Sort (sort.bin).
//            Verifica a ordenação do vetor de 5 elementos na memória RAM.
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

    integer cycles = 0;
    integer errors = 0;

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

    // Contador de ciclos após desativação do reset
    always @(posedge clk) begin
        if (!reset) begin
            cycles <= cycles + 1;
        end
    end

    initial begin
        $dumpfile("build/pipeline_top.vcd");
        $dumpvars(0, tb_mips_pipeline_top);

        clk   = 0;
        reset = 1;

        $display("==========================================================");
        $display("  Iniciando Simulação Top-Level MIPS Pipeline (Passo 9)   ");
        $display("==========================================================");

        $display("\n[ANTES DA ORDENAÇÃO] Vetor na RAM (Tempo 0):");
        $display("Posicao 0: %0d", uut.data_mem_inst.ram[0]);
        $display("Posicao 1: %0d", uut.data_mem_inst.ram[1]);
        $display("Posicao 2: %0d", uut.data_mem_inst.ram[2]);
        $display("Posicao 3: %0d", uut.data_mem_inst.ram[3]);
        $display("Posicao 4: %0d", uut.data_mem_inst.ram[4]);

        // Pulso de reset por 2 ciclos
        #20;
        @(posedge clk);
        #1;
        reset = 0;

        // Aguarda execução do algoritmo Bubble Sort (ou até atingir limite máximo de ciclos)
        while (!((uut.data_mem_inst.ram[0] == 32'd7  &&
                  uut.data_mem_inst.ram[1] == 32'd15 &&
                  uut.data_mem_inst.ram[2] == 32'd42 &&
                  uut.data_mem_inst.ram[3] == 32'd88 &&
                  uut.data_mem_inst.ram[4] == 32'd99) || (cycles >= 2000))) begin
            @(posedge clk);
        end

        // Aguarda mais alguns ciclos para estabilização final
        repeat (10) @(posedge clk);

        $display("\n[DEPOIS DA ORDENAÇÃO] Vetor na RAM (Fim da Execução em %0d ciclos):", cycles);
        $display("Posicao 0: %0d (Esperado:  7)", uut.data_mem_inst.ram[0]);
        $display("Posicao 1: %0d (Esperado: 15)", uut.data_mem_inst.ram[1]);
        $display("Posicao 2: %0d (Esperado: 42)", uut.data_mem_inst.ram[2]);
        $display("Posicao 3: %0d (Esperado: 88)", uut.data_mem_inst.ram[3]);
        $display("Posicao 4: %0d (Esperado: 99)", uut.data_mem_inst.ram[4]);

        if (uut.data_mem_inst.ram[0] !== 32'd7)  errors = errors + 1;
        if (uut.data_mem_inst.ram[1] !== 32'd15) errors = errors + 1;
        if (uut.data_mem_inst.ram[2] !== 32'd42) errors = errors + 1;
        if (uut.data_mem_inst.ram[3] !== 32'd88) errors = errors + 1;
        if (uut.data_mem_inst.ram[4] !== 32'd99) errors = errors + 1;

        $display("\n==========================================================");
        if (errors === 0) begin
            $display(">>> TESTE DO PIPELINE TOP-LEVEL (SORT) CONCLUÍDO COM SUCESSO! <<<");
            $display("    Total de Ciclos: %0d", cycles);
        end else begin
            $display(">>> FALHA NA ORDENAÇÃO DO VETOR PELO PIPELINE! Erros: %0d <<<", errors);
        end
        $display("==========================================================");

        #10;
        $finish;
    end

endmodule
