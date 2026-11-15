SHELL := /usr/bin/env bash

QUARTUS_BIN_DIR ?= /home/jdercy/01-dev/programas/opt_intel/quartus/bin
export PATH := $(QUARTUS_BIN_DIR):$(PATH)

.PHONY: all help test alu datapath_aux reg_file control instr_mem data_mem pipe_if_id pipe_id_ex pipe_ex_mem pipe_mem_wb forwarding_unit hazard_detection_unit pipeline_top pipeline_isa_hazards benchmark waves waves-alu waves-pipeline relatorio apresentacao quartus quartus-build quartus-build-monociclo quartus-sta quartus-metrics quartus-pgm clean

all: pipeline_top

help:
	@echo "Alvos disponíveis no Makefile:"
	@echo "  make alu           - Executa o testbench da ALU"
	@echo "  make datapath_aux  - Executa o testbench dos módulos auxiliares do datapath"
	@echo "  make reg_file      - Executa o testbench do Register File"
	@echo "  make control       - Executa o testbench da Unidade de Controle"
	@echo "  make instr_mem     - Executa o testbench da Memória de Instruções"
	@echo "  make data_mem      - Executa o testbench da Memória de Dados"
	@echo "  make pipe_if_id    - Executa o testbench do Registrador IF/ID"
	@echo "  make pipe_id_ex    - Executa o testbench do Registrador ID/EX"
	@echo "  make pipe_ex_mem   - Executa o testbench do Registrador EX/MEM"
	@echo "  make pipe_mem_wb   - Executa o testbench do Registrador MEM/WB"
	@echo "  make forwarding_unit - Executa o testbench da Forwarding Unit"
	@echo "  make hazard_detection_unit - Executa o testbench da Hazard Detection Unit"
	@echo "  make pipeline_top  - Executa a simulação do MIPS Pipeline Top-Level (Bubble Sort)"
	@echo "  make pipeline_isa_hazards - Executa a suíte integrada teste_isa.bin + teste_hazards.bin"
	@echo "  make benchmark     - Executa sort/isa/hazards (Monociclo vs Pipeline) e salva build/benchmark_metrics.*"
	@echo "  make test          - Executa toda a bateria de testes de regressão do Pipeline"
	@echo "  make quartus       - Executa Análise e Elaboração rápida no Intel Quartus Prime"
	@echo "  make quartus-build - Compilação Completa do Pipeline (Síntese + Fitter + Bitstream + Timing STA)"
	@echo "  make quartus-build-monociclo - Compilação Completa do baseline Monociclo no Quartus"
	@echo "  make quartus-sta   - Executa somente o Timing Analyzer (Fmax / Slack)"
	@echo "  make quartus-metrics - Sintetiza Pipeline + Monociclo (se desatualizados) e gera métricas comparativas"
	@echo "  make quartus-pgm   - Grava o bitstream (.sof) na placa DE10-Lite via USB-Blaster"
	@echo "  make waves         - Abre as formas de onda do MIPS Pipeline no GTKWave"
	@echo "  make waves-alu     - Abre as formas de onda da ALU no GTKWave"
	@echo "  make waves-pipeline - Abre as formas de onda do MIPS Pipeline Top no GTKWave"
	@echo "  make relatorio     - Compila o relatório IEEE em LaTeX via Tectonic"
	@echo "  make apresentacao  - Compila os slides da apresentação em LaTeX Beamer via Tectonic"
	@echo "  make clean         - Remove arquivos compilados e temporários (.vvp, .vcd)"

alu:
	@./scripts/run_simulation.sh alu

datapath_aux:
	@./scripts/run_simulation.sh datapath_aux

reg_file:
	@./scripts/run_simulation.sh reg_file

control:
	@./scripts/run_simulation.sh control_unit

instr_mem:
	@./scripts/run_simulation.sh instr_mem

data_mem:
	@./scripts/run_simulation.sh data_mem

pipe_if_id:
	@./scripts/run_simulation.sh pipe_if_id

pipe_id_ex:
	@./scripts/run_simulation.sh pipe_id_ex

pipe_ex_mem:
	@./scripts/run_simulation.sh pipe_ex_mem

pipe_mem_wb:
	@./scripts/run_simulation.sh pipe_mem_wb

forwarding_unit:
	@./scripts/run_simulation.sh forwarding_unit

hazard_detection_unit:
	@./scripts/run_simulation.sh hazard_detection_unit

pipeline_top:
	@./scripts/run_simulation.sh pipeline_top

pipeline_isa_hazards:
	@./scripts/run_simulation.sh pipeline_isa_hazards

benchmark:
	@./scripts/run_simulation.sh benchmark

test:
	@./scripts/run_all_tests.sh

PIPELINE_SYNTH_DEPS  := $(wildcard src/*.v src/*/*.v) quartus/mips_pipeline.qsf quartus/mips_pipeline.sdc assembly-mips/sort.bin
MONOCICLO_SYNTH_DEPS := $(wildcard monociclo/src/*.v src/control/*.v src/datapath/*.v src/memory/*.v) monociclo/quartus/mips_monociclo.qsf monociclo/quartus/mips_monociclo.sdc assembly-mips/sort.bin

quartus/output_files/mips_pipeline.sta.rpt: $(PIPELINE_SYNTH_DEPS)
	@./scripts/run_quartus_flow.sh quartus mips_pipeline

monociclo/quartus/output_files/mips_monociclo.sta.rpt: $(MONOCICLO_SYNTH_DEPS)
	@./scripts/run_quartus_flow.sh monociclo/quartus mips_monociclo

quartus:
	@echo "Executando Análise e Elaboração no Intel Quartus Prime..."
	@mkdir -p quartus/assembly-mips
	@cp assembly-mips/sort.bin quartus/assembly-mips/
	@cd quartus && quartus_map mips_pipeline --analysis_and_elaboration
	@python3 scripts/quartus_metrics.py --project pipeline

quartus-build:
	@./scripts/run_quartus_flow.sh quartus mips_pipeline
	@python3 scripts/quartus_metrics.py --markdown build/quartus_metrics.md --latex build/quartus_metrics.tex

quartus-build-monociclo:
	@./scripts/run_quartus_flow.sh monociclo/quartus mips_monociclo

quartus-sta:
	@echo "Executando Timing Analyzer (quartus_sta)..."
	@cd quartus && quartus_sta mips_pipeline
	@python3 scripts/quartus_metrics.py

quartus-metrics: quartus/output_files/mips_pipeline.sta.rpt monociclo/quartus/output_files/mips_monociclo.sta.rpt
	@mkdir -p build
	@python3 scripts/quartus_metrics.py --markdown build/quartus_metrics.md --latex build/quartus_metrics.tex

quartus-pgm:
	@echo "Verificando conexão JTAG com a placa DE10-Lite..."
	@jtagconfig
	@echo "Gravando bitstream no FPGA Intel MAX 10..."
	@cd quartus && quartus_pgm -m jtag -c 1 -o "p;output_files/mips_pipeline.sof"

waves:
	@./scripts/view_waves.sh pipeline_top

waves-alu:
	@./scripts/view_waves.sh alu

waves-pipeline:
	@./scripts/view_waves.sh pipeline_top

relatorio:
	@cd docs/relatorio && ./compilar.sh

apresentacao:
	@cd docs/apresentacao && ./compilar.sh

clean:
	@./scripts/clean.sh
