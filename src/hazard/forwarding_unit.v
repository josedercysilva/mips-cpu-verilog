// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Módulo: forwarding_unit — Unidade de Encaminhamento / Adiantamento de Dados
// Descrição: Circuito combinacional para resolução de perigos de dados RAW.
//            Compara os registradores fonte do estágio EX (rs, rt) com os
//            registradores destino de EX/MEM e MEM/WB, gerando ForwardA e ForwardB.
// ============================================================================

`timescale 1ns / 1ps

module forwarding_unit #(
    parameter REG_ADDR_WIDTH = 5
) (
    input  wire [REG_ADDR_WIDTH-1:0] id_ex_rs,
    input  wire [REG_ADDR_WIDTH-1:0] id_ex_rt,
    input  wire                      ex_mem_reg_write,
    input  wire [REG_ADDR_WIDTH-1:0] ex_mem_write_reg,
    input  wire                      mem_wb_reg_write,
    input  wire [REG_ADDR_WIDTH-1:0] mem_wb_write_reg,
    output reg  [1:0]                forward_a,
    output reg  [1:0]                forward_b
);

    always @(*) begin
        // Encaminhamento para o operando A (rs)
        if (ex_mem_reg_write && (ex_mem_write_reg != {REG_ADDR_WIDTH{1'b0}}) && (ex_mem_write_reg == id_ex_rs))
            forward_a = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_write_reg != {REG_ADDR_WIDTH{1'b0}}) && (mem_wb_write_reg == id_ex_rs))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // Encaminhamento para o operando B (rt)
        if (ex_mem_reg_write && (ex_mem_write_reg != {REG_ADDR_WIDTH{1'b0}}) && (ex_mem_write_reg == id_ex_rt))
            forward_b = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_write_reg != {REG_ADDR_WIDTH{1'b0}}) && (mem_wb_write_reg == id_ex_rt))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end

endmodule
