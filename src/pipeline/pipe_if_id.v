// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho <josedercysilva@gmail.com>
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// Desenvolvido com auxílio de: Google Antigravity (Google DeepMind) — Gemini 3.8 Flash
// ----------------------------------------------------------------------------
// Módulo: pipe_if_id — Registrador de Pipeline IF/ID
// Descrição: Registrador de barreira entre os estágios de Busca (IF) e
//            Decodificação (ID). Armazena pc_plus_4 e a palavra de instrução.
//            Suporta congelamento síncrono (enable = 0) para inserção de stall
//            na resolução de perigo Load-Use, e limpeza síncrona (flush = 1)
//            para descarte de instrução especulativa em desvios tomados.
// ============================================================================

`timescale 1ns / 1ps

module pipe_if_id #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  enable,
    input  wire                  flush,
    input  wire [ADDR_WIDTH-1:0] pc_plus_4_in,
    input  wire [DATA_WIDTH-1:0] instr_in,
    output reg  [ADDR_WIDTH-1:0] pc_plus_4_out,
    output reg  [DATA_WIDTH-1:0] instr_out
);

    // Reset assíncrono ativo em nível alto
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_plus_4_out <= {ADDR_WIDTH{1'b0}};
            instr_out     <= {DATA_WIDTH{1'b0}}; 
        end else if (flush) begin
            pc_plus_4_out <= {ADDR_WIDTH{1'b0}};
            instr_out     <= {DATA_WIDTH{1'b0}}; 
        end else if (enable) begin
            pc_plus_4_out <= pc_plus_4_in;
            instr_out     <= instr_in;
        end
    end

endmodule
