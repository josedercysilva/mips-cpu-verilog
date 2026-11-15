// ============================================================================
// Universidade Federal do Amazonas - UFAM
// Faculdade de Engenharia Elétrica e da Computação - FEEC
// Disciplina: Arquitetura de Sistemas Digitais e Laboratório
// Manaus, Amazonas, Brasil
// Autor: José Dercy Vieira da Silva Filho
// Equipe: José Dercy Vieira da Silva Filho e Vinicius Menezes
// ----------------------------------------------------------------------------
// Módulo Auxiliar: pipeline_telemetry_probe
// Descrição: Coleta síncrona de eventos de hazard (stalls, flushes EX/ID,
//            adiantamentos na ULA e bypass WB -> ID) até o fim da execução.
// ============================================================================

`timescale 1ns / 1ps

module pipeline_telemetry_probe (
    input  wire       clk,
    input  wire       reset,
    input  wire       done,
    input  wire       stall,
    input  wire       flush_ex,
    input  wire       jump_id,
    input  wire [1:0] forward_a,
    input  wire [1:0] forward_b,
    input  wire       wb_reg_write,
    input  wire [4:0] wb_write_reg,
    input  wire [4:0] id_rs,
    input  wire [4:0] id_rt,
    output reg  [31:0] stalls_cnt,
    output reg  [31:0] flushes_ex_cnt,
    output reg  [31:0] flushes_id_cnt,
    output reg  [31:0] fwd_alu_cnt,
    output reg  [31:0] bypass_wbid_cnt
);
    always @(posedge clk) begin
        if (reset) begin
            stalls_cnt      <= 32'd0;
            flushes_ex_cnt  <= 32'd0;
            flushes_id_cnt  <= 32'd0;
            fwd_alu_cnt     <= 32'd0;
            bypass_wbid_cnt <= 32'd0;
        end else if (!done) begin
            if (stall)
                stalls_cnt <= stalls_cnt + 32'd1;

            if (flush_ex)
                flushes_ex_cnt <= flushes_ex_cnt + 32'd1;
            else if (jump_id)
                flushes_id_cnt <= flushes_id_cnt + 32'd1;

            if ((forward_a != 2'b00) && (forward_b != 2'b00))
                fwd_alu_cnt <= fwd_alu_cnt + 32'd2;
            else if ((forward_a != 2'b00) || (forward_b != 2'b00))
                fwd_alu_cnt <= fwd_alu_cnt + 32'd1;

            if (wb_reg_write && (wb_write_reg != 5'd0) &&
                ((wb_write_reg == id_rs) || (wb_write_reg == id_rt)))
                bypass_wbid_cnt <= bypass_wbid_cnt + 32'd1;
        end
    end
endmodule

// ============================================================================
// Testbench: tb_benchmark_comparativo
// Descrição: Executa sort.bin, teste_isa.bin e teste_hazards.bin no Monociclo
//            e no Pipeline, valida os resultados finais e grava métricas em
//            build/benchmark_metrics.{md,csv,tex} via $fopen/$fdisplay.
// ============================================================================

module tb_benchmark_comparativo;

    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;
    localparam MEM_DEPTH  = 256;

    // Períodos de clock extraídos do Intel Quartus Prime (MAX 10 10M50DAF484C7G):
    //   Monociclo Fmax = 45.31 MHz -> T_min = 22.07 ns
    //   Pipeline  Fmax = 58.25 MHz -> T_min = 17.17 ns
    parameter real T_MONO_NS  = 22.07;
    parameter real T_PIPE_NS  = 17.17;
    parameter real T_BOARD_NS = 20.00; // Clock base da placa DE10-Lite (50 MHz)

    reg clk   = 1'b0;
    reg reset = 1'b1;

    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // 1. Bubble Sort (assembly-mips/sort.bin)
    // ------------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] p_sort_pc, p_sort_instr, p_sort_alu, p_sort_dmem;
    wire                  p_sort_we;
    mips_pipeline_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE("assembly-mips/sort.bin")
    ) uut_p_sort (
        .clk(clk), .reset(reset), .pc(p_sort_pc), .instr(p_sort_instr),
        .alu_result(p_sort_alu), .dmem_data(p_sort_dmem), .dmem_write_enable(p_sort_we)
    );

    wire [ADDR_WIDTH-1:0] m_sort_pc, m_sort_instr, m_sort_alu, m_sort_dmem;
    wire                  m_sort_we;
    mips_monociclo_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE("assembly-mips/sort.bin")
    ) uut_m_sort (
        .clk(clk), .reset(reset), .pc(m_sort_pc), .instr(m_sort_instr),
        .alu_result(m_sort_alu), .dmem_data(m_sort_dmem), .dmem_write_enable(m_sort_we)
    );

    // ------------------------------------------------------------------------
    // 2. Cobertura ISA 16 instruções (assembly-mips/teste_isa.bin)
    // ------------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] p_isa_pc, p_isa_instr, p_isa_alu, p_isa_dmem;
    wire                  p_isa_we;
    mips_pipeline_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE("assembly-mips/teste_isa.bin")
    ) uut_p_isa (
        .clk(clk), .reset(reset), .pc(p_isa_pc), .instr(p_isa_instr),
        .alu_result(p_isa_alu), .dmem_data(p_isa_dmem), .dmem_write_enable(p_isa_we)
    );

    wire [ADDR_WIDTH-1:0] m_isa_pc, m_isa_instr, m_isa_alu, m_isa_dmem;
    wire                  m_isa_we;
    mips_monociclo_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE("assembly-mips/teste_isa.bin")
    ) uut_m_isa (
        .clk(clk), .reset(reset), .pc(m_isa_pc), .instr(m_isa_instr),
        .alu_result(m_isa_alu), .dmem_data(m_isa_dmem), .dmem_write_enable(m_isa_we)
    );

    // ------------------------------------------------------------------------
    // 3. Estresse de Hazards + Recursão fib(7) (assembly-mips/teste_hazards.bin)
    // ------------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] p_haz_pc, p_haz_instr, p_haz_alu, p_haz_dmem;
    wire                  p_haz_we;
    mips_pipeline_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE("assembly-mips/teste_hazards.bin")
    ) uut_p_haz (
        .clk(clk), .reset(reset), .pc(p_haz_pc), .instr(p_haz_instr),
        .alu_result(p_haz_alu), .dmem_data(p_haz_dmem), .dmem_write_enable(p_haz_we)
    );

    wire [ADDR_WIDTH-1:0] m_haz_pc, m_haz_instr, m_haz_alu, m_haz_dmem;
    wire                  m_haz_we;
    mips_monociclo_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE("assembly-mips/teste_hazards.bin")
    ) uut_m_haz (
        .clk(clk), .reset(reset), .pc(m_haz_pc), .instr(m_haz_instr),
        .alu_result(m_haz_alu), .dmem_data(m_haz_dmem), .dmem_write_enable(m_haz_we)
    );

    // ------------------------------------------------------------------------
    // Condições de conclusão e contadores
    // ------------------------------------------------------------------------
    integer cyc             = 0;
    integer errors          = 0;
    integer p_sort_ram_cyc  = 0;
    integer p_sort_ret_cyc  = 0;
    integer m_sort_ram_cyc  = 0;
    integer m_sort_ret_cyc  = 0;
    integer p_isa_cyc       = 0;
    integer m_isa_cyc       = 0;
    integer p_haz_cyc       = 0;
    integer m_haz_cyc       = 0;

    wire p_sort_sorted = (uut_p_sort.data_mem_inst.ram[0] == 32'd7  &&
                          uut_p_sort.data_mem_inst.ram[1] == 32'd15 &&
                          uut_p_sort.data_mem_inst.ram[2] == 32'd42 &&
                          uut_p_sort.data_mem_inst.ram[3] == 32'd88 &&
                          uut_p_sort.data_mem_inst.ram[4] == 32'd99);

    wire m_sort_sorted = (uut_m_sort.data_mem_inst.ram[0] == 32'd7  &&
                          uut_m_sort.data_mem_inst.ram[1] == 32'd15 &&
                          uut_m_sort.data_mem_inst.ram[2] == 32'd42 &&
                          uut_m_sort.data_mem_inst.ram[3] == 32'd88 &&
                          uut_m_sort.data_mem_inst.ram[4] == 32'd99);

    wire p_isa_ok = (uut_p_isa.data_mem_inst.ram[26] === 32'h00007ACE);
    wire m_isa_ok = (uut_m_isa.data_mem_inst.ram[26] === 32'h00007ACE);

    wire p_haz_ok = (uut_p_haz.data_mem_inst.ram[40] === 32'h00005AFE);
    wire m_haz_ok = (uut_m_haz.data_mem_inst.ram[40] === 32'h00005AFE);

    // Sondas de telemetria reutilizáveis
    wire [31:0] s195_stalls, s195_fex, s195_fid, s195_fwd, s195_wbid;
    pipeline_telemetry_probe probe_sort_ram (
        .clk(clk), .reset(reset), .done(p_sort_ram_cyc != 0),
        .stall(uut_p_sort.control_mux_sel),
        .flush_ex(uut_p_sort.ex_branch_taken | uut_p_sort.ex_jr),
        .jump_id(uut_p_sort.id_jump_taken),
        .forward_a(uut_p_sort.forward_a), .forward_b(uut_p_sort.forward_b),
        .wb_reg_write(uut_p_sort.wb_reg_write), .wb_write_reg(uut_p_sort.wb_write_reg),
        .id_rs(uut_p_sort.id_rs), .id_rt(uut_p_sort.id_rt),
        .stalls_cnt(s195_stalls), .flushes_ex_cnt(s195_fex), .flushes_id_cnt(s195_fid),
        .fwd_alu_cnt(s195_fwd), .bypass_wbid_cnt(s195_wbid)
    );

    wire [31:0] sret_stalls, sret_fex, sret_fid, sret_fwd, sret_wbid;
    pipeline_telemetry_probe probe_sort_ret (
        .clk(clk), .reset(reset), .done(p_sort_ret_cyc != 0),
        .stall(uut_p_sort.control_mux_sel),
        .flush_ex(uut_p_sort.ex_branch_taken | uut_p_sort.ex_jr),
        .jump_id(uut_p_sort.id_jump_taken),
        .forward_a(uut_p_sort.forward_a), .forward_b(uut_p_sort.forward_b),
        .wb_reg_write(uut_p_sort.wb_reg_write), .wb_write_reg(uut_p_sort.wb_write_reg),
        .id_rs(uut_p_sort.id_rs), .id_rt(uut_p_sort.id_rt),
        .stalls_cnt(sret_stalls), .flushes_ex_cnt(sret_fex), .flushes_id_cnt(sret_fid),
        .fwd_alu_cnt(sret_fwd), .bypass_wbid_cnt(sret_wbid)
    );

    wire [31:0] isa_stalls, isa_fex, isa_fid, isa_fwd, isa_wbid;
    pipeline_telemetry_probe probe_isa (
        .clk(clk), .reset(reset), .done(p_isa_cyc != 0),
        .stall(uut_p_isa.control_mux_sel),
        .flush_ex(uut_p_isa.ex_branch_taken | uut_p_isa.ex_jr),
        .jump_id(uut_p_isa.id_jump_taken),
        .forward_a(uut_p_isa.forward_a), .forward_b(uut_p_isa.forward_b),
        .wb_reg_write(uut_p_isa.wb_reg_write), .wb_write_reg(uut_p_isa.wb_write_reg),
        .id_rs(uut_p_isa.id_rs), .id_rt(uut_p_isa.id_rt),
        .stalls_cnt(isa_stalls), .flushes_ex_cnt(isa_fex), .flushes_id_cnt(isa_fid),
        .fwd_alu_cnt(isa_fwd), .bypass_wbid_cnt(isa_wbid)
    );

    wire [31:0] haz_stalls, haz_fex, haz_fid, haz_fwd, haz_wbid;
    pipeline_telemetry_probe probe_haz (
        .clk(clk), .reset(reset), .done(p_haz_cyc != 0),
        .stall(uut_p_haz.control_mux_sel),
        .flush_ex(uut_p_haz.ex_branch_taken | uut_p_haz.ex_jr),
        .jump_id(uut_p_haz.id_jump_taken),
        .forward_a(uut_p_haz.forward_a), .forward_b(uut_p_haz.forward_b),
        .wb_reg_write(uut_p_haz.wb_reg_write), .wb_write_reg(uut_p_haz.wb_write_reg),
        .id_rs(uut_p_haz.id_rs), .id_rt(uut_p_haz.id_rt),
        .stalls_cnt(haz_stalls), .flushes_ex_cnt(haz_fex), .flushes_id_cnt(haz_fid),
        .fwd_alu_cnt(haz_fwd), .bypass_wbid_cnt(haz_wbid)
    );

    always @(posedge clk) begin
        if (!reset) begin
            cyc <= cyc + 1;
            if (p_sort_ram_cyc == 0 && p_sort_sorted) p_sort_ram_cyc <= cyc;
            if (p_sort_ram_cyc != 0 && p_sort_ret_cyc == 0 && p_sort_pc == 32'd0) p_sort_ret_cyc <= cyc;
            if (m_sort_ram_cyc == 0 && m_sort_sorted) m_sort_ram_cyc <= cyc;
            if (m_sort_ram_cyc != 0 && m_sort_ret_cyc == 0 && m_sort_pc == 32'd0) m_sort_ret_cyc <= cyc;
            if (p_isa_cyc == 0 && p_isa_ok) p_isa_cyc <= cyc;
            if (m_isa_cyc == 0 && m_isa_ok) m_isa_cyc <= cyc;
            if (p_haz_cyc == 0 && p_haz_ok) p_haz_cyc <= cyc;
            if (m_haz_cyc == 0 && m_haz_ok) m_haz_cyc <= cyc;
        end
    end

    integer fd_md, fd_csv, fd_tex;

    task emit_row;
        input [8*36-1:0] label_txt;
        input [8*36-1:0] label_tex;
        input integer    m_cyc;
        input integer    p_cyc;
        input [31:0]     stalls;
        input [31:0]     fex;
        input [31:0]     fid;
        input [31:0]     fwd;
        input [31:0]     wbid;
        integer          wasted_slots;
        real             m_ns, p_ns, p_board_ns, cpi, ipc, speedup, wasted_pct;
        begin
            wasted_slots = stalls + (fex * 2) + fid;
            m_ns         = m_cyc * T_MONO_NS;
            p_ns         = p_cyc * T_PIPE_NS;
            p_board_ns   = p_cyc * T_BOARD_NS;
            cpi          = (m_cyc > 0) ? (1.0 * p_cyc / m_cyc) : 0.0;
            ipc          = (p_cyc > 0) ? (1.0 * m_cyc / p_cyc) : 0.0;
            speedup      = (p_ns > 0.0) ? (m_ns / p_ns) : 0.0;
            wasted_pct   = (p_cyc > 0) ? (100.0 * wasted_slots / p_cyc) : 0.0;

            $display("| %-28s | %5d | %7.1f ns | %5d | %7.1f ns | %4.2f / %4.2f | %5.3fx | %2d st + %2d*2 + %2d = %3d (%4.1f%%) | fwd=%3d, wb=%2d |",
                     label_txt, m_cyc, m_ns, p_cyc, p_ns, cpi, ipc, speedup,
                     stalls, fex, fid, wasted_slots, wasted_pct, fwd, wbid);

            $fdisplay(fd_md, "| %0s | %0d | %.1f ns | %0d | %.1f ns | %.1f ns | %.2f / %.2f | %.3fx | %0d | %0d (x2) + %0d (x1) | %0d (%.1f%%) | %0d + %0d |",
                      label_txt, m_cyc, m_ns, p_cyc, p_ns, p_board_ns, cpi, ipc, speedup,
                      stalls, fex, fid, wasted_slots, wasted_pct, fwd, wbid);

            $fdisplay(fd_csv, "%0s,%0d,%.2f,%0d,%.2f,%.2f,%.4f,%.4f,%.4f,%0d,%0d,%0d,%0d,%.2f,%0d,%0d",
                      label_txt, m_cyc, m_ns, p_cyc, p_ns, p_board_ns, cpi, ipc, speedup,
                      stalls, fex, fid, wasted_slots, wasted_pct, fwd, wbid);

            $fdisplay(fd_tex, "    %0s & %0d & %.1f~ns & %0d & %.1f~ns & %.2f & %.2f & %.3fx & %0d & %0d & %0d (%.1f\\%%) \\\\",
                      label_tex, m_cyc, m_ns, p_cyc, p_ns, cpi, ipc, speedup,
                      stalls, (fex * 2) + fid, wasted_slots, wasted_pct);
        end
    endtask

    initial begin
        $dumpfile("build/benchmark.vcd");
        $dumpvars(0, tb_benchmark_comparativo);

        #20;
        @(posedge clk);
        #1;
        reset = 1'b0;

        while (cyc < 1500 &&
               !(p_sort_ret_cyc != 0 && m_sort_ret_cyc != 0 &&
                 p_isa_cyc != 0 && m_isa_cyc != 0 &&
                 p_haz_cyc != 0 && m_haz_cyc != 0)) begin
            @(posedge clk);
        end
        repeat (4) @(posedge clk);

        // Validações funcionais de ambos os processadores
        if (!p_sort_sorted || !m_sort_sorted) errors = errors + 1;
        if (!p_isa_ok      || !m_isa_ok)      errors = errors + 1;
        if (!p_haz_ok      || !m_haz_ok)      errors = errors + 1;
        if (uut_p_haz.data_mem_inst.ram[39] !== 32'd13) errors = errors + 1;
        if (uut_m_haz.data_mem_inst.ram[39] !== 32'd13) errors = errors + 1;

        fd_md  = $fopen("build/benchmark_metrics.md", "w");
        fd_csv = $fopen("build/benchmark_metrics.csv", "w");
        fd_tex = $fopen("build/benchmark_metrics.tex", "w");

        if (fd_md == 0 || fd_csv == 0 || fd_tex == 0) begin
            $display("[ERRO] Falha ao abrir arquivos em build/benchmark_metrics.*");
            $fatal(1, "Erro de I/O ao criar arquivos de benchmark.");
        end

        $display("==================================================================================================================================");
        $display("  UFAM / FEEC — Benchmark Comparativo Monociclo (%.2f MHz) vs. Pipeline (%.2f MHz)",
                 1000.0 / T_MONO_NS, 1000.0 / T_PIPE_NS);
        $display("==================================================================================================================================");
        $display("| Firmware                     |  Mono |   T_mono   |  Pipe |   T_pipe   |  CPI / IPC  | Speedup| Desperdicio (st+EX*2+ID=slots) | Forwarding    |");
        $display("|------------------------------|-------|------------|-------|------------|-------------|--------|--------------------------------|---------------|");

        $fdisplay(fd_md, "# Benchmark Comparativo — Monociclo vs. Pipeline (5 Estágios)\n");
        $fdisplay(fd_md, "* **Monociclo ($F_{\\max}$ Quartus):** %.2f MHz ($T_{\\min} = %.2f$ ns)", 1000.0 / T_MONO_NS, T_MONO_NS);
        $fdisplay(fd_md, "* **Pipeline ($F_{\\max}$ Quartus):** %.2f MHz ($T_{\\min} = %.2f$ ns) | **Placa DE10-Lite:** 50.00 MHz ($20.00$ ns)\n", 1000.0 / T_PIPE_NS, T_PIPE_NS);
        $fdisplay(fd_md, "| Firmware | Mono (ciclos) | Tempo Mono (`Fmax`) | Pipe (ciclos) | Tempo Pipe (`Fmax`) | Tempo Pipe (`50 MHz`) | CPI / IPC | Speedup (`Fmax`) | Stalls | Flushes EX / ID | Slots Perdidos | Fwd ALU + WB->ID |");
        $fdisplay(fd_md, "| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |");

        $fdisplay(fd_csv, "firmware,mono_cycles,mono_time_ns,pipe_cycles,pipe_time_ns,pipe_50mhz_ns,cpi,ipc,speedup_fmax,stalls,flushes_ex,jumps_id,wasted_slots,wasted_pct,fwd_alu,bypass_wbid");

        $fdisplay(fd_tex, "%% Tabela gerada automaticamente via Verilog ($fopen) por tb/tb_benchmark_comparativo.v");
        $fdisplay(fd_tex, "\\begin{table*}[htbp]");
        $fdisplay(fd_tex, "  \\centering");
        $fdisplay(fd_tex, "  \\caption{Comparativo de Desempenho RTL e Tempo Real ($F_{\\max}$ Quartus) --- Monociclo vs. Pipeline}");
        $fdisplay(fd_tex, "  \\label{tab:benchmark_comparativo}");
        $fdisplay(fd_tex, "  \\begin{tabular}{lcccccccccc}");
        $fdisplay(fd_tex, "    \\hline");
        $fdisplay(fd_tex, "    \\textbf{Firmware} & \\textbf{Mono} & \\textbf{$T_{\\text{mono}}$} & \\textbf{Pipe} & \\textbf{$T_{\\text{pipe}}$} & \\textbf{CPI} & \\textbf{IPC} & \\textbf{Speedup} & \\textbf{Stalls} & \\textbf{Flush Slots} & \\textbf{Desperd\\'icio} \\\\");
        $fdisplay(fd_tex, "    \\hline");

        emit_row("sort.bin (RAM ordenada)",  "\\texttt{sort.bin} (RAM)",    m_sort_ram_cyc, p_sort_ram_cyc, s195_stalls, s195_fex, s195_fid, s195_fwd, s195_wbid);
        emit_row("sort.bin (jr $ra -> 0)",   "\\texttt{sort.bin} (retorno)", m_sort_ret_cyc, p_sort_ret_cyc, sret_stalls, sret_fex, sret_fid, sret_fwd, sret_wbid);
        emit_row("teste_isa.bin (16 instr)", "\\texttt{teste\\_isa.bin}",    m_isa_cyc,      p_isa_cyc,      isa_stalls,  isa_fex,  isa_fid,  isa_fwd,  isa_wbid);
        emit_row("teste_hazards.bin (fib7)", "\\texttt{teste\\_hazards.bin}",m_haz_cyc,      p_haz_cyc,      haz_stalls,  haz_fex,  haz_fid,  haz_fwd,  haz_wbid);

        $fdisplay(fd_tex, "    \\hline");
        $fdisplay(fd_tex, "  \\end{tabular}");
        $fdisplay(fd_tex, "\\end{table*}");

        $fclose(fd_md);
        $fclose(fd_csv);
        $fclose(fd_tex);

        $display("==================================================================================================================================");
        $display("[OK] Arquivos gravados: build/benchmark_metrics.md | build/benchmark_metrics.csv | build/benchmark_metrics.tex");

        if (errors !== 0) begin
            $fatal(1, "Falha funcional no benchmark comparativo (%0d erro(s)).", errors);
        end
        $display(">>> BENCHMARK COMPARATIVO CONCLUIDO COM 100%% DE SUCESSO (0 erros)! <<<");
        $finish;
    end

endmodule
