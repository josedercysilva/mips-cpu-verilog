module formal_top_control (
    input wire [5:0] opcode,
    input wire [5:0] funct
);
    wire [1:0] reg_dst;
    wire       jump;
    wire       jal;
    wire       branch;
    wire       bne;
    wire       mem_read;
    wire [1:0] mem_to_reg;
    wire [3:0] alu_ctrl;
    wire       mem_write;
    wire       alu_src;
    wire       reg_write;
    wire       jr;

    // Instancia a Unidade de Controle completa do Top-Level
    control_unit uut (
        .opcode(opcode),
        .funct(funct),
        .reg_dst(reg_dst),
        .jump(jump),
        .jal(jal),
        .branch(branch),
        .bne(bne),
        .mem_read(mem_read),
        .mem_to_reg(mem_to_reg),
        .alu_ctrl(alu_ctrl),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .reg_write(reg_write),
        .jr(jr)
    );

    always @(*) begin
        // -------------------------------------------------------------
        // INVARIANTE 1: Segurança de Barramento (Bus Contention Hazard)
        // A memória de dados NUNCA pode ter leitura e escrita ativas juntas.
        // Se isso ocorresse, o hardware elétrico entraria em curto/conflito.
        // -------------------------------------------------------------
        assert (!(mem_read && mem_write));

        // -------------------------------------------------------------
        // INVARIANTE 2: Exclusão Mútua de Controle de Fluxo
        // Uma instrução NUNCA pode ser Branch e Jump ao mesmo tempo.
        // -------------------------------------------------------------
        assert (!(branch && jump));
        assert (!(bne && jump));

        // -------------------------------------------------------------
        // INVARIANTE 3: Contrato do JAL (Jump and Link)
        // Se for 'jal', é MANDATÓRIO salvar o PC em $ra (registrador 31).
        // -------------------------------------------------------------
        if (jal) begin
            assert (reg_write == 1'b1);
            assert (reg_dst == 2'b10); // 2'b10 seleciona $ra (31) no mux
        end

        // -------------------------------------------------------------
        // INVARIANTE 4: Contrato do SW (Store Word)
        // Store Word escreve na RAM e NUNCA pode corromper registradores.
        // -------------------------------------------------------------
        if (opcode == 6'b101011) begin // sw
            assert (mem_write == 1'b1);
            assert (reg_write == 1'b0);
        end

        // -------------------------------------------------------------
        // INVARIANTE 5: Contrato do LW (Load Word)
        // Load Word tem que habilitar leitura e escrita de registrador.
        // -------------------------------------------------------------
        if (opcode == 6'b100011) begin // lw
            assert (mem_read == 1'b1);
            assert (reg_write == 1'b1);
            assert (mem_to_reg == 2'b01);
        end
    end
endmodule