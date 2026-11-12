SHELL := /usr/bin/env bash

QUARTUS_BIN_DIR ?= /home/jdercy/01-dev/programas/opt_intel/quartus/bin
export PATH := $(QUARTUS_BIN_DIR):$(PATH)

.PHONY: all help test alu datapath_aux reg_file control instr_mem data_mem pipe_if_id pipe_id_ex pipe_ex_mem pipe_mem_wb forwarding_unit hazard_detection_unit pipeline_top waves waves-alu waves-pipeline relatorio apresentacao quartus quartus-build quartus-pgm clean

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
	@echo "  make pipeline_top  - Executa a simulação do MIPS Pipeline Top-Level"
	@echo "  make test          - Executa toda a bateria de testes de regressão do Pipeline"
	@echo "  make quartus       - Executa Análise e Elaboração rápida no Intel Quartus Prime"
	@echo "  make quartus-build - Compilação Completa (Síntese + Fitter + Geração do Bitstream .sof)"
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

test:
	@./scripts/run_all_tests.sh

quartus:
	@echo "Executando Análise e Elaboração no Intel Quartus Prime..."
	@mkdir -p quartus/assembly-mips
	@cp assembly-mips/sort.bin quartus/assembly-mips/
	@cd quartus && quartus_map mips_pipeline --analysis_and_elaboration

quartus-build:
	@echo "==> [1/3] Análise e Síntese (quartus_map)..."
	@mkdir -p quartus/assembly-mips
	@cp assembly-mips/sort.bin quartus/assembly-mips/
	@cd quartus && quartus_map mips_pipeline
	@echo "==> [2/3] Mapeamento e Roteamento (quartus_fit)..."
	@cd quartus && quartus_fit mips_pipeline
	@echo "==> [3/3] Geração do Bitstream .sof (quartus_asm)..."
	@cd quartus && quartus_asm mips_pipeline
	@echo "[OK] Bitstream gerado com sucesso em quartus/output_files/mips_pipeline.sof"

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
