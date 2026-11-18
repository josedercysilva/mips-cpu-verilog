// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Módulo: formal_forwarding_unit — Verificação Formal da Forwarding Unit (SVA)
// Descrição: Propriedades matemáticas e assertivas formais (assert) para provar:
//            1. Proteção irrestrita do registrador $zero ($0).
//            2. Prioridade temporal de EX/MEM sobre MEM/WB.
//            3. Dependência estrita do sinal RegWrite.
//            4. Ausência de falsos adiantamentos (no spurious forwarding).
//            5. Ausência de código de controle reservado/inválido (2'b11).
// ============================================================================

`timescale 1ns / 1ps

module formal_forwarding_unit #(
    parameter REG_ADDR_WIDTH = 5
) (
    input  wire [REG_ADDR_WIDTH-1:0] id_ex_rs,
    input  wire [REG_ADDR_WIDTH-1:0] id_ex_rt,
    input  wire                      ex_mem_reg_write,
    input  wire [REG_ADDR_WIDTH-1:0] ex_mem_write_reg,
    input  wire                      mem_wb_reg_write,
    input  wire [REG_ADDR_WIDTH-1:0] mem_wb_write_reg
);

    wire [1:0] forward_a;
    wire [1:0] forward_b;

    // Instancia a Unidade de Encaminhamento sob verificação formal
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

    always @(*) begin
        // --------------------------------------------------------------------
        // PROPRIEDADE 1: Proteção Absoluta do Registrador $zero ($0)
        // O registrador $0 é constante em 0 no MIPS; jamais deve ser adiantado.
        // --------------------------------------------------------------------
        if (ex_mem_write_reg == {REG_ADDR_WIDTH{1'b0}}) begin
            assert (forward_a != 2'b10);
            assert (forward_b != 2'b10);
        end

        if (mem_wb_write_reg == {REG_ADDR_WIDTH{1'b0}}) begin
            assert (forward_a != 2'b01);
            assert (forward_b != 2'b01);
        end

        // --------------------------------------------------------------------
        // PROPRIEDADE 2: Prioridade Temporal de EX/MEM sobre MEM/WB
        // Quando ambas as instruções anteriores escrevem no mesmo registrador,
        // o hardware DEVE adiantar o valor mais recente (estágio EX/MEM).
        // --------------------------------------------------------------------
        if (ex_mem_reg_write && (ex_mem_write_reg != {REG_ADDR_WIDTH{1'b0}}) && (ex_mem_write_reg == id_ex_rs) &&
            mem_wb_reg_write && (mem_wb_write_reg != {REG_ADDR_WIDTH{1'b0}}) && (mem_wb_write_reg == id_ex_rs)) begin
            assert (forward_a == 2'b10);
        end

        if (ex_mem_reg_write && (ex_mem_write_reg != {REG_ADDR_WIDTH{1'b0}}) && (ex_mem_write_reg == id_ex_rt) &&
            mem_wb_reg_write && (mem_wb_write_reg != {REG_ADDR_WIDTH{1'b0}}) && (mem_wb_write_reg == id_ex_rt)) begin
            assert (forward_b == 2'b10);
        end

        // --------------------------------------------------------------------
        // PROPRIEDADE 3: Condição Necessária de Habilitação de Escrita
        // Se a instrução não grava no registrador (RegWrite=0), não há adiantamento.
        // --------------------------------------------------------------------
        if (!ex_mem_reg_write) begin
            assert (forward_a != 2'b10);
            assert (forward_b != 2'b10);
        end

        if (!mem_wb_reg_write) begin
            assert (forward_a != 2'b01);
            assert (forward_b != 2'b01);
        end

        // --------------------------------------------------------------------
        // PROPRIEDADE 4: Exclusão Mútua e Coerência de Adiantamento
        // Se forward_a == 2'b10, o registrador EX/MEM DEVE ser o causador legítimo.
        // Se forward_a == 2'b01, o registrador MEM/WB DEVE ser o causador legítimo
        // e EX/MEM não pode ser concorrente no mesmo registrador.
        // --------------------------------------------------------------------
        if (forward_a == 2'b10) begin
            assert (ex_mem_reg_write == 1'b1);
            assert (ex_mem_write_reg != {REG_ADDR_WIDTH{1'b0}});
            assert (ex_mem_write_reg == id_ex_rs);
        end

        if (forward_a == 2'b01) begin
            assert (mem_wb_reg_write == 1'b1);
            assert (mem_wb_write_reg != {REG_ADDR_WIDTH{1'b0}});
            assert (mem_wb_write_reg == id_ex_rs);
            assert (!(ex_mem_reg_write && (ex_mem_write_reg != {REG_ADDR_WIDTH{1'b0}}) && (ex_mem_write_reg == id_ex_rs)));
        end

        if (forward_b == 2'b10) begin
            assert (ex_mem_reg_write == 1'b1);
            assert (ex_mem_write_reg != {REG_ADDR_WIDTH{1'b0}});
            assert (ex_mem_write_reg == id_ex_rt);
        end

        if (forward_b == 2'b01) begin
            assert (mem_wb_reg_write == 1'b1);
            assert (mem_wb_write_reg != {REG_ADDR_WIDTH{1'b0}});
            assert (mem_wb_write_reg == id_ex_rt);
            assert (!(ex_mem_reg_write && (ex_mem_write_reg != {REG_ADDR_WIDTH{1'b0}}) && (ex_mem_write_reg == id_ex_rt)));
        end

        // --------------------------------------------------------------------
        // PROPRIEDADE 5: Ausência de Códigos Reservados / Inválidos
        // O valor 2'b11 é reservado para expansões futuras e nunca deve ser emitido.
        // --------------------------------------------------------------------
        assert (forward_a != 2'b11);
        assert (forward_b != 2'b11);
    end

endmodule
