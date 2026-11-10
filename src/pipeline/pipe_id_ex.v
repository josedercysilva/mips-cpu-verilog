// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Módulo: pipe_id_ex — Registrador de Pipeline ID/EX
// Descrição: Registrador entre os estágios de Decodificação (ID) e Execução (EX).
//            Armazena operandos, imediato, shamt, endereços de registradores
//            e sinais de controle (EX, MEM, WB). Suporta flush e enable.
// ============================================================================

`timescale 1ns / 1ps

module pipe_id_ex #(
    parameter DATA_WIDTH     = 32,
    parameter ADDR_WIDTH     = 32,
    parameter REG_ADDR_WIDTH = 5,
    parameter ALU_OP_WIDTH   = 2
) (
    input  wire                      clk,
    input  wire                      rst,
    input  wire                      enable,
    input  wire                      flush,

    // Controle - EX
    input  wire [1:0]                reg_dst_in,
    input  wire [ALU_OP_WIDTH-1:0]   alu_op_in,
    input  wire                      alu_src_in,
    output reg  [1:0]                reg_dst_out,
    output reg  [ALU_OP_WIDTH-1:0]   alu_op_out,
    output reg                       alu_src_out,

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
    input  wire [DATA_WIDTH-1:0]     read_data1_in,
    input  wire [DATA_WIDTH-1:0]     read_data2_in,
    input  wire [DATA_WIDTH-1:0]     sign_ext_imm_in,
    input  wire [4:0]                shamt_in,
    input  wire [REG_ADDR_WIDTH-1:0] rs_in,
    input  wire [REG_ADDR_WIDTH-1:0] rt_in,
    input  wire [REG_ADDR_WIDTH-1:0] rd_in,

    output reg  [ADDR_WIDTH-1:0]     pc_plus_4_out,
    output reg  [DATA_WIDTH-1:0]     read_data1_out,
    output reg  [DATA_WIDTH-1:0]     read_data2_out,
    output reg  [DATA_WIDTH-1:0]     sign_ext_imm_out,
    output reg  [4:0]                shamt_out,
    output reg  [REG_ADDR_WIDTH-1:0] rs_out,
    output reg  [REG_ADDR_WIDTH-1:0] rt_out,
    output reg  [REG_ADDR_WIDTH-1:0] rd_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_dst_out      <= 2'b00;
            alu_op_out       <= {ALU_OP_WIDTH{1'b0}};
            alu_src_out      <= 1'b0;
            branch_out       <= 1'b0;
            bne_out          <= 1'b0;
            mem_read_out     <= 1'b0;
            mem_write_out    <= 1'b0;
            reg_write_out    <= 1'b0;
            mem_to_reg_out   <= 2'b00;

            pc_plus_4_out    <= {ADDR_WIDTH{1'b0}};
            read_data1_out   <= {DATA_WIDTH{1'b0}};
            read_data2_out   <= {DATA_WIDTH{1'b0}};
            sign_ext_imm_out <= {DATA_WIDTH{1'b0}};
            shamt_out        <= 5'b00000;
            rs_out           <= {REG_ADDR_WIDTH{1'b0}};
            rt_out           <= {REG_ADDR_WIDTH{1'b0}};
            rd_out           <= {REG_ADDR_WIDTH{1'b0}};
        end else if (flush) begin
            reg_dst_out      <= 2'b00;
            alu_op_out       <= {ALU_OP_WIDTH{1'b0}};
            alu_src_out      <= 1'b0;
            branch_out       <= 1'b0;
            bne_out          <= 1'b0;
            mem_read_out     <= 1'b0;
            mem_write_out    <= 1'b0;
            reg_write_out    <= 1'b0;
            mem_to_reg_out   <= 2'b00;

            pc_plus_4_out    <= {ADDR_WIDTH{1'b0}};
            read_data1_out   <= {DATA_WIDTH{1'b0}};
            read_data2_out   <= {DATA_WIDTH{1'b0}};
            sign_ext_imm_out <= {DATA_WIDTH{1'b0}};
            shamt_out        <= 5'b00000;
            rs_out           <= {REG_ADDR_WIDTH{1'b0}};
            rt_out           <= {REG_ADDR_WIDTH{1'b0}};
            rd_out           <= {REG_ADDR_WIDTH{1'b0}};
        end else if (enable) begin
            reg_dst_out      <= reg_dst_in;
            alu_op_out       <= alu_op_in;
            alu_src_out      <= alu_src_in;
            branch_out       <= branch_in;
            bne_out          <= bne_in;
            mem_read_out     <= mem_read_in;
            mem_write_out    <= mem_write_in;
            reg_write_out    <= reg_write_in;
            mem_to_reg_out   <= mem_to_reg_in;

            pc_plus_4_out    <= pc_plus_4_in;
            read_data1_out   <= read_data1_in;
            read_data2_out   <= read_data2_in;
            sign_ext_imm_out <= sign_ext_imm_in;
            shamt_out        <= shamt_in;
            rs_out           <= rs_in;
            rt_out           <= rt_in;
            rd_out           <= rd_in;
        end
    end

endmodule
