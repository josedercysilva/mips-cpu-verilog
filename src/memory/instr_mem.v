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

    // Array de memória ROM
    reg [DATA_WIDTH-1:0] rom [0:MEM_DEPTH-1];

    // Inicialização da ROM: preenche com NOP (0x00000000) e carrega o arquivo binário
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            rom[i] = {DATA_WIDTH{1'b0}};
        end
        $readmemb(INIT_FILE, rom);
    end

    // Leitura combinacional (assíncrona) indexada por palavra
    // Como os endereços do MIPS avançam de 4 em 4 bytes (0, 4, 8...),
    // e o MARS tenta usar a base 0x00400000, nós pegamos apenas os 
    // bits [9:2]. Isso joga a base alta no lixo e espelha a execução perfeitamente
    // dentro do nosso array de 256 palavras locais!
    assign instr = rom[addr[9:2]];

endmodule
