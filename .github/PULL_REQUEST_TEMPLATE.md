## Descrição do Pull Request

Descreva detalhadamente a funcionalidade, módulo ou correção implementada para o MIPS com Pipeline.

* **Tipo de Alteração:**
  - [ ] Registrador de Pipeline (`src/pipeline/pipe_*.v`)
  - [ ] Unidade de Adiantamento / Forwarding (`src/hazard/forwarding_unit.v`)
  - [ ] Unidade de Detecção de Riscos / Hazard Detection (`src/hazard/hazard_detection_unit.v`)
  - [ ] Datapath ou Memória (`src/datapath/`, `src/memory/`)
  - [ ] Unidade de Controle (`src/control/`)
  - [ ] Integração Top-Level (`src/mips_pipeline_top.v`)
  - [ ] Testbench / Simulação (`tb/`, `scripts/`)
  - [ ] Relatório Técnico em LaTeX (`docs/relatorio/`)
* **Arquivos alterados:** `src/...`
* **Testbench correspondente:** `tb/...`

---

## Critérios de Aceitação (Checklist Obrigatório)

Para aprovação e integração na branch `main`, marque todos os itens abaixo confirmando a conformidade técnica local:

- [ ] **1. Contrato de Interface & Parametrização:** O módulo declara e utiliza parâmetros para largura de barramento (`parameter DATA_WIDTH = 32`, etc.) conforme Rubrica 3, mantendo a assinatura de portas acordada no *skeleton*.
- [ ] **2. Tratamento Correto de Sinais do Pipeline:** Módulos com registradores implementam corretamente os sinais de clock (`clk`), reset (`rst`), habilitação (`enable` / stall) e descarte (`flush`), sem inferência indesejada de latches.
- [ ] **3. Testbench Unitário:** Foi criado ou atualizado o testbench individual na pasta `tb/` cobrindo cenários nominais e condições de borda (ex.: riscos RAW consecutivos, desvios tomados e não tomados, stalls por load-use).
- [ ] **4. Simulação RTL (Icarus Verilog):** O código compila sem avisos/erros e roda localmente via `iverilog` / `scripts/run_simulation.sh`.
- [ ] **5. Validação Visual (GTKWave):** As formas de onda foram inspecionadas visualmente, comprovando o fluxo correto das instruções pelos 5 estágios.
- [ ] **6. Commit Limpo:** Nenhum artefato de compilação ou arquivo temporário (`.vcd`, `.out`, `.vvp`, pastas `db/` ou `incremental_db/` do Quartus) foi incluído no commit.

---

> **Política de Integração:** Pull Requests sem testbench correspondente ou com falhas de simulação serão rejeitados.
> **Revisão e Aprovação:** Aprovação mandatória do mantenedor do repositório (@josedercysilva / José Dercy Silva) antes do merge na branch `main`.
