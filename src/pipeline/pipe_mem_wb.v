// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Módulo: pipe_mem_wb — Registrador de Pipeline MEM/WB
// Descrição: Registrador entre os estágios de Memória (MEM) e Escrita (WB).
//            Armazena dado lido da RAM, resultado da ULA, pc_plus_4, endereço
//            do registrador destino e sinais de controle de WB (RegWrite,
//            MemtoReg). Suporta flush e enable.
// ============================================================================

`timescale 1ns / 1ps

module pipe_mem_wb #(
    parameter DATA_WIDTH     = 32,
    parameter ADDR_WIDTH     = 32,
    parameter REG_ADDR_WIDTH = 5
) (
    input  wire                      clk,
    input  wire                      rst,
    input  wire                      enable,
    input  wire                      flush,

    // Controle - WB
    input  wire                      reg_write_in,
    input  wire [1:0]                mem_to_reg_in,
    output reg                       reg_write_out,
    output reg  [1:0]                mem_to_reg_out,

    // Dados
    input  wire [ADDR_WIDTH-1:0]     pc_plus_4_in,
    input  wire [DATA_WIDTH-1:0]     mem_read_data_in,
    input  wire [DATA_WIDTH-1:0]     alu_result_in,
    input  wire [REG_ADDR_WIDTH-1:0] write_reg_in,

    output reg  [ADDR_WIDTH-1:0]     pc_plus_4_out,
    output reg  [DATA_WIDTH-1:0]     mem_read_data_out,
    output reg  [DATA_WIDTH-1:0]     alu_result_out,
    output reg  [REG_ADDR_WIDTH-1:0] write_reg_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_write_out     <= 1'b0;
            mem_to_reg_out    <= 2'b00;

            pc_plus_4_out     <= {ADDR_WIDTH{1'b0}};
            mem_read_data_out <= {DATA_WIDTH{1'b0}};
            alu_result_out    <= {DATA_WIDTH{1'b0}};
            write_reg_out     <= {REG_ADDR_WIDTH{1'b0}};
        end else if (flush) begin
            reg_write_out     <= 1'b0;
            mem_to_reg_out    <= 2'b00;

            pc_plus_4_out     <= {ADDR_WIDTH{1'b0}};
            mem_read_data_out <= {DATA_WIDTH{1'b0}};
            alu_result_out    <= {DATA_WIDTH{1'b0}};
            write_reg_out     <= {REG_ADDR_WIDTH{1'b0}};
        end else if (enable) begin
            reg_write_out     <= reg_write_in;
            mem_to_reg_out    <= mem_to_reg_in;

            pc_plus_4_out     <= pc_plus_4_in;
            mem_read_data_out <= mem_read_data_in;
            alu_result_out    <= alu_result_in;
            write_reg_out     <= write_reg_in;
        end
    end

endmodule
