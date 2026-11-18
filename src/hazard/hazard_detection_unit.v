// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Módulo: hazard_detection_unit — Unidade de Detecção de Riscos (Hazards)
// Descrição: Circuito combinacional para detecção de conflitos Load-Use.
//            Quando uma instrução no estágio ID depende do dado de uma instrução
//            lw no estágio EX, gera sinais para congelar PC e IF/ID e injetar
//            uma bolha (NOP) no estágio ID/EX.
// ============================================================================

`timescale 1ns / 1ps

module hazard_detection_unit #(
    parameter REG_ADDR_WIDTH = 5
) (
    input  wire [REG_ADDR_WIDTH-1:0] id_ex_rt,
    input  wire                      id_ex_mem_read,
    input  wire [REG_ADDR_WIDTH-1:0] if_id_rs,
    input  wire [REG_ADDR_WIDTH-1:0] if_id_rt,
    output reg                       pc_write,
    output reg                       if_id_write,
    output reg                       control_mux_sel
);

    always @(*) begin
        if (id_ex_mem_read && (id_ex_rt != {REG_ADDR_WIDTH{1'b0}}) &&
            ((id_ex_rt == if_id_rs) || (id_ex_rt == if_id_rt))) begin
            pc_write        = 1'b0;
            if_id_write     = 1'b0;
            control_mux_sel = 1'b1;
        end else begin
            pc_write        = 1'b1;
            if_id_write     = 1'b1;
            control_mux_sel = 1'b0;
        end
    end

endmodule
