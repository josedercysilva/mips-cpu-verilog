// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Testbench Top-Level: tb_pipeline_isa_hazards
// Descrição: Validação integrada no mips_pipeline_top dos firmwares
//            teste_isa.bin (todas as 16 instruções) e teste_hazards.bin
//            (forwarding EX/MEM e MEM/WB, proteção $zero, Load-Use, flushes,
//            retorno imediato jal -> jr $ra e recursão dupla fib(7)).
// ============================================================================

`timescale 1ns / 1ps

module tb_pipeline_isa_hazards;

    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;
    localparam MEM_DEPTH  = 256;

    reg clk;
    reg reset;

    wire [ADDR_WIDTH-1:0] pc_isa, instr_isa, alu_isa, dmem_isa;
    wire                  we_isa;

    wire [ADDR_WIDTH-1:0] pc_haz, instr_haz, alu_haz, dmem_haz;
    wire                  we_haz;

    integer cycles = 0;
    integer tests  = 0;
    integer errors = 0;

    mips_pipeline_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE("assembly-mips/teste_isa.bin")
    ) uut_isa (
        .clk(clk),
        .reset(reset),
        .pc(pc_isa),
        .instr(instr_isa),
        .alu_result(alu_isa),
        .dmem_data(dmem_isa),
        .dmem_write_enable(we_isa)
    );

    mips_pipeline_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE("assembly-mips/teste_hazards.bin")
    ) uut_haz (
        .clk(clk),
        .reset(reset),
        .pc(pc_haz),
        .instr(instr_haz),
        .alu_result(alu_haz),
        .dmem_data(dmem_haz),
        .dmem_write_enable(we_haz)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset) cycles <= cycles + 1;
    end

    task check_word;
        input integer        idx;
        input signed [31:0]  actual;
        input signed [31:0]  expected;
        input [255:0]        label;
        begin
            tests = tests + 1;
            if (actual !== expected) begin
                $display("[FALHA] %0s ram[%0d] = %0d (esperado: %0d)", label, idx, actual, expected);
                errors = errors + 1;
            end else begin
                $display("[OK] %0s ram[%0d] = %0d", label, idx, actual);
            end
        end
    endtask

    initial begin
        $dumpfile("build/pipeline_isa_hazards.vcd");
        $dumpvars(0, tb_pipeline_isa_hazards);

        clk   = 0;
        reset = 1;

        $display("============================================================================");
        $display("   Simulação Integrada Top-Level: teste_isa.bin & teste_hazards.bin         ");
        $display("============================================================================");

        #20;
        @(posedge clk);
        #1;
        reset = 0;

        while (!((uut_isa.data_mem_inst.ram[26] === 32'h00007ACE &&
                  uut_haz.data_mem_inst.ram[40] === 32'h00005AFE) || (cycles >= 1500))) begin
            @(posedge clk);
        end
        repeat (5) @(posedge clk);

        $display("\n--- Verificação teste_isa.bin ---");
        check_word(16, $signed(uut_isa.data_mem_inst.ram[16]), 32'sd10,    "ISA add");
        check_word(17, $signed(uut_isa.data_mem_inst.ram[17]), 32'sd20,    "ISA sub");
        check_word(18, $signed(uut_isa.data_mem_inst.ram[18]), 32'sd40,    "ISA sll");
        check_word(19, $signed(uut_isa.data_mem_inst.ram[19]), 32'sd15,    "ISA and");
        check_word(20, $signed(uut_isa.data_mem_inst.ram[20]), 32'sd4095,  "ISA or");
        check_word(21, $signed(uut_isa.data_mem_inst.ram[21]), -32'sd4096, "ISA nor");
        check_word(22, $signed(uut_isa.data_mem_inst.ram[22]), 32'sd3,     "ISA slt/slti");
        check_word(23, $signed(uut_isa.data_mem_inst.ram[23]), 32'sd4095,  "ISA sw");
        check_word(24, $signed(uut_isa.data_mem_inst.ram[24]), 32'sd4096,  "ISA lw+addi");
        check_word(25, $signed(uut_isa.data_mem_inst.ram[25]), 32'sd1150,  "ISA beq/bne/jal/jr/j");
        check_word(26, $signed(uut_isa.data_mem_inst.ram[26]), 32'sd31438, "ISA assinatura");

        $display("\n--- Verificação teste_hazards.bin ---");
        check_word(32, $signed(uut_haz.data_mem_inst.ram[32]), 32'sd190,   "HAZ forwarding/dupla");
        check_word(33, $signed(uut_haz.data_mem_inst.ram[33]), 32'sd1,     "HAZ protecao $zero");
        check_word(34, $signed(uut_haz.data_mem_inst.ram[34]), 32'sd90,    "HAZ Load-Use");
        check_word(35, $signed(uut_haz.data_mem_inst.ram[35]), 32'sd25,    "HAZ lw -> sw");
        check_word(36, $signed(uut_haz.data_mem_inst.ram[36]), 32'sd60,    "HAZ flushes beq/bne/j");
        check_word(37, $signed(uut_haz.data_mem_inst.ram[37]), 32'sd15,    "HAZ jal -> jr imediato");
        check_word(38, $signed(uut_haz.data_mem_inst.ram[38]), 32'sd128,   "HAZ lw $ra -> jr $ra");
        check_word(39, $signed(uut_haz.data_mem_inst.ram[39]), 32'sd13,    "HAZ recursao fib(7)");
        check_word(40, $signed(uut_haz.data_mem_inst.ram[40]), 32'sd23294, "HAZ assinatura");

        $display("\n============================================================================");
        $display("Resumo: %0d/%0d verificações em %0d ciclos | Erros: %0d", tests - errors, tests, cycles, errors);
        $display("============================================================================");

        if (errors === 0) begin
            $display(">>> SUITE INTEGRADA ISA & HAZARDS APROVADA COM 100%% DE SUCESSO! <<<");
            $finish;
        end else begin
            $display(">>> FALHA NA SUITE INTEGRADA ISA & HAZARDS! <<<");
            $fatal(1, "Suite integrada falhou com %0d erro(s).", errors);
        end
    end

endmodule
