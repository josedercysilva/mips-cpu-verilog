// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Módulo: instr_mem — Memória de Instruções Parametrizada — ROM
// Descrição: Armazena o código de máquina do programa a ser executado pelo
//            MIPS. Opera em leitura assíncrona, fornecendo a palavra de instrução
//            correspondente ao endereço requisitado pelo Program Counter.
//            Suporta carregamento estático de arquivos .hex via $readmemh.
// ============================================================================

`timescale 1ns / 1ps

module instr_mem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MEM_DEPTH  = 256,
    parameter INIT_FILE  = "assembly-mips/sort.bin"
) (
    input  wire [ADDR_WIDTH-1:0] addr,
    output wire [DATA_WIDTH-1:0] instr
);


    reg [DATA_WIDTH-1:0] rom [0:MEM_DEPTH-1];

    // Inicialização da ROM: preenche com NOP (0x00000000) e carrega o arquivo binário
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            rom[i] = {DATA_WIDTH{1'b0}};
        end
        $readmemb(INIT_FILE, rom);
    end


    assign instr = rom[addr[9:2]];

endmodule
