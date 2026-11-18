// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Testbench: tb_hazard_detection_unit — Validação da Unidade de Detecção de Riscos
// Descrição: Valida a detecção de conflitos Load-Use nos operandos rs e rt,
//            geração de sinais de stall (pc_write=0, if_id_write=0) e bolha
//            (control_mux_sel=1), bem como a proteção para o registrador $0.
// ============================================================================

`timescale 1ns / 1ps

module tb_hazard_detection_unit;

    localparam REG_ADDR_WIDTH = 5;

    reg  [REG_ADDR_WIDTH-1:0] id_ex_rt;
    reg                       id_ex_mem_read;
    reg  [REG_ADDR_WIDTH-1:0] if_id_rs;
    reg  [REG_ADDR_WIDTH-1:0] if_id_rt;

    wire                      pc_write;
    wire                      if_id_write;
    wire                      control_mux_sel;

    integer tests  = 0;
    integer errors = 0;

    hazard_detection_unit #(
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    ) uut (
        .id_ex_rt(id_ex_rt),
        .id_ex_mem_read(id_ex_mem_read),
        .if_id_rs(if_id_rs),
        .if_id_rt(if_id_rt),
        .pc_write(pc_write),
        .if_id_write(if_id_write),
        .control_mux_sel(control_mux_sel)
    );

    task check_outputs;
        input exp_pc_write;
        input exp_if_id_write;
        input exp_ctrl_mux;
        input [255:0] test_name;
        begin
            tests = tests + 1;
            #1;
            if ((pc_write === exp_pc_write) &&
                (if_id_write === exp_if_id_write) &&
                (control_mux_sel === exp_ctrl_mux)) begin
                $display("[PASS %0d] %0s -> pc_write=%b, if_id_write=%b, control_mux_sel=%b",
                         tests, test_name, pc_write, if_id_write, control_mux_sel);
            end else begin
                $display("[ERRO %0d] %0s -> Esperado: pc_w=%b, if_id_w=%b, ctrl_mux=%b | Obtido: pc_w=%b, if_id_w=%b, ctrl_mux=%b",
                         tests, test_name, exp_pc_write, exp_if_id_write, exp_ctrl_mux,
                         pc_write, if_id_write, control_mux_sel);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("build/hazard_detection_unit.vcd");
        $dumpvars(0, tb_hazard_detection_unit);

        id_ex_rt       = {REG_ADDR_WIDTH{1'b0}};
        id_ex_mem_read = 1'b0;
        if_id_rs       = {REG_ADDR_WIDTH{1'b0}};
        if_id_rt       = {REG_ADDR_WIDTH{1'b0}};

        $display("==========================================================");
        $display("   Iniciando Testbench da Hazard Detection Unit (Passo 8)  ");
        $display("==========================================================");

        // Teste 1: Operacao normal sem hazard (MemRead=0, registradores distintos)
        #10;
        id_ex_mem_read = 1'b0;
        id_ex_rt       = 5'd8;
        if_id_rs       = 5'd9;
        if_id_rt       = 5'd10;
        check_outputs(1'b1, 1'b1, 1'b0, "Normal sem hazard");

        // Teste 2: Registrador coincidente com MemRead=0 (R-Type em EX, resolvido por forwarding)
        #10;
        id_ex_mem_read = 1'b0;
        id_ex_rt       = 5'd8;
        if_id_rs       = 5'd8;
        if_id_rt       = 5'd10;
        check_outputs(1'b1, 1'b1, 1'b0, "Coincidencia com MemRead=0");

        // Teste 3: Load-Use Hazard no operando rs (MemRead=1, id_ex_rt == if_id_rs)
        #10;
        id_ex_mem_read = 1'b1;
        id_ex_rt       = 5'd4;
        if_id_rs       = 5'd4;
        if_id_rt       = 5'd5;
        check_outputs(1'b0, 1'b0, 1'b1, "Load-Use em rs");

        // Teste 4: Load-Use Hazard no operando rt (MemRead=1, id_ex_rt == if_id_rt)
        #10;
        id_ex_mem_read = 1'b1;
        id_ex_rt       = 5'd5;
        if_id_rs       = 5'd4;
        if_id_rt       = 5'd5;
        check_outputs(1'b0, 1'b0, 1'b1, "Load-Use em rt");

        // Teste 5: Load-Use Hazard em ambos rs e rt simultaneamente
        #10;
        id_ex_mem_read = 1'b1;
        id_ex_rt       = 5'd16;
        if_id_rs       = 5'd16;
        if_id_rt       = 5'd16;
        check_outputs(1'b0, 1'b0, 1'b1, "Load-Use em rs e rt");

        // Teste 6: Load em EX (MemRead=1), porem sem coincidencia de registradores
        #10;
        id_ex_mem_read = 1'b1;
        id_ex_rt       = 5'd2;
        if_id_rs       = 5'd17;
        if_id_rt       = 5'd18;
        check_outputs(1'b1, 1'b1, 1'b0, "Load sem coincidencia");

        // Teste 7: Protecao do registrador $0 com MemRead=1
        #10;
        id_ex_mem_read = 1'b1;
        id_ex_rt       = 5'd0;
        if_id_rs       = 5'd0;
        if_id_rt       = 5'd0;
        check_outputs(1'b1, 1'b1, 1'b0, "Protecao $0 (sem stall)");

        // Teste 8: Sequencia dinamica - stall e posterior liberacao
        #10;
        id_ex_mem_read = 1'b1;
        id_ex_rt       = 5'd12;
        if_id_rs       = 5'd12;
        if_id_rt       = 5'd13;
        check_outputs(1'b0, 1'b0, 1'b1, "Sequencia: entrada em stall");

        #10;
        id_ex_mem_read = 1'b0;
        check_outputs(1'b1, 1'b1, 1'b0, "Sequencia: liberacao pos-stall");

        $display("==========================================================");
        $display("Resumo: %0d testes executados, %0d erros encontrados.", tests, errors);
        $display("==========================================================");

        if (errors === 0) begin
            $display(">>> TESTE DA HAZARD DETECTION UNIT APROVADO COM 100%% DE SUCESSO! <<<");
        end else begin
            $display(">>> FALHAS DETECTADAS NA HAZARD DETECTION UNIT! <<<");
        end

        #5 $finish;
    end

endmodule
