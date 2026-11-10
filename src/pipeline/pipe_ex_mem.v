// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Módulo: pipe_ex_mem — Registrador de Pipeline EX/MEM
// Descrição: Registrador entre os estágios de Execução (EX) e Memória (MEM).
//            Armazena resultado da ULA, dado de escrita na RAM, endereço do
//            registrador destino, alvo e flag de branch, pc_plus_4 e sinais
//            de controle (MEM e WB). Suporta flush e enable.
// ============================================================================

`timescale 1ns / 1ps

module pipe_ex_mem #(
    parameter DATA_WIDTH     = 32,
    parameter ADDR_WIDTH     = 32,
    parameter REG_ADDR_WIDTH = 5
) (
    input  wire                      clk,
    input  wire                      rst,
    input  wire                      enable,
    input  wire                      flush,

    // Controle - MEM
    input  wire                      branch_in,
    input  wire                      bne_in,
    input  wire                      mem_read_in,
    input  wire                      mem_write_in,
    output reg                       branch_out,
    output reg                       bne_out,
    output reg                       mem_read_out,
    output reg                       mem_write_out,

    // Controle - WB
    input  wire                      reg_write_in,
    input  wire [1:0]                mem_to_reg_in,
    output reg                       reg_write_out,
    output reg  [1:0]                mem_to_reg_out,

    // Dados
    input  wire [ADDR_WIDTH-1:0]     pc_plus_4_in,
    input  wire [ADDR_WIDTH-1:0]     branch_target_in,
    input  wire                      zero_in,
    input  wire [DATA_WIDTH-1:0]     alu_result_in,
    input  wire [DATA_WIDTH-1:0]     write_data_in,
    input  wire [REG_ADDR_WIDTH-1:0] write_reg_in,

    output reg  [ADDR_WIDTH-1:0]     pc_plus_4_out,
    output reg  [ADDR_WIDTH-1:0]     branch_target_out,
    output reg                       zero_out,
    output reg  [DATA_WIDTH-1:0]     alu_result_out,
    output reg  [DATA_WIDTH-1:0]     write_data_out,
    output reg  [REG_ADDR_WIDTH-1:0] write_reg_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            branch_out        <= 1'b0;
            bne_out           <= 1'b0;
            mem_read_out      <= 1'b0;
            mem_write_out     <= 1'b0;
            reg_write_out     <= 1'b0;
            mem_to_reg_out    <= 2'b00;

            pc_plus_4_out     <= {ADDR_WIDTH{1'b0}};
            branch_target_out <= {ADDR_WIDTH{1'b0}};
            zero_out          <= 1'b0;
            alu_result_out    <= {DATA_WIDTH{1'b0}};
            write_data_out    <= {DATA_WIDTH{1'b0}};
            write_reg_out     <= {REG_ADDR_WIDTH{1'b0}};
        end else if (flush) begin
            branch_out        <= 1'b0;
            bne_out           <= 1'b0;
            mem_read_out      <= 1'b0;
            mem_write_out     <= 1'b0;
            reg_write_out     <= 1'b0;
            mem_to_reg_out    <= 2'b00;

            pc_plus_4_out     <= {ADDR_WIDTH{1'b0}};
            branch_target_out <= {ADDR_WIDTH{1'b0}};
            zero_out          <= 1'b0;
            alu_result_out    <= {DATA_WIDTH{1'b0}};
            write_data_out    <= {DATA_WIDTH{1'b0}};
            write_reg_out     <= {REG_ADDR_WIDTH{1'b0}};
        end else if (enable) begin
            branch_out        <= branch_in;
            bne_out           <= bne_in;
            mem_read_out      <= mem_read_in;
            mem_write_out     <= mem_write_in;
            reg_write_out     <= reg_write_in;
            mem_to_reg_out    <= mem_to_reg_in;

            pc_plus_4_out     <= pc_plus_4_in;
            branch_target_out <= branch_target_in;
            zero_out          <= zero_in;
            alu_result_out    <= alu_result_in;
            write_data_out    <= write_data_in;
            write_reg_out     <= write_reg_in;
        end
    end

endmodule
