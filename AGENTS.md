# AGENTS.md — Guia Operacional para Agentes de IA

> **Projeto:** Processador MIPS 32 bits com Pipeline de 5 Estágios (Entrega 03 — UFAM / FEEC)  
> **Mantenedor:** José Dercy Vieira da Silva Filho ([@josedercysilva](https://github.com/josedercysilva))  
> **Regras completas:** Consulte [`.gemini/rules.md`](.gemini/rules.md) (espelhado em `GEMINI.md`).

---

## 1. Leitura Obrigatória Inicial
Antes de alterar código ou propor mudanças, leia:
1. `contexto/MANUAL-GEMINI.md` — visão geral do estado real do projeto, mapa de diretórios e armadilhas a evitar.
2. `contexto/arquivo-original-classroom.md` — enunciado e rubrica oficiais da Entrega 03 (**prazo: 18/11/2026 até 13:59h**).
3. `contexto/arquitetura-pipeline-mips.md` — arquitetura efetivamente implementada em `src/`.
4. `contexto/projeto-arquitetura-integra.md` — especificação C do benchmark *Bubble Sort* (**não modificar**).

---

## 2. Comandos Essenciais
```bash
make test              # Executa todas as 13 bancadas no Icarus Verilog
make pipeline_top      # Simula o Top-Level executando assembly-mips/sort.bin
make waves-pipeline    # Abre build/pipeline_top.vcd no GTKWave
make -C monociclo run  # Executa o baseline Monociclo da Entrega 02
make clean             # Limpa artefatos de build (.vvp, .vcd, Quartus)
make relatorio         # Compila o relatório IEEE via Tectonic
```

---

## 3. Restrições Inegociáveis
* **Rubrica 3 (Parametrização):** Todo módulo em `src/` deve usar `parameter` para larguras de barramento e profundidades.
* **Rubrica 2 (Testbenches):** Todo componente deve possuir testbench em `tb/` com geração de `.vcd` para validação no GTKWave.
* **Escopo da ISA:** O processador suporta exatamente **16 instruções** (`add`, `sub`, `and`, `or`, `slt`, `nor`, `sll`, `jr`, `lw`, `sw`, `addi`, `slti`, `beq`, `bne`, `j`, `jal`). **Não** inventar ou adicionar instruções extras sem pedido explícito.
* **Proibição de comandos Git sem autorização expressa:** Nunca execute nenhum comando `git` sem autorização expressa do usuário (mesmo em modo de autonomia total), pois o usuário usa Git + Antigravity manualmente para depurar e revisar todas as mudanças.
* **Git limpo e branch protection:** Nunca dar push direto em `main`; não versionar `.vcd`, `.vvp`, `build/`, `quartus/db/` ou `quartus/output_files/`.
* **Preservar arquivos originais:** Não modificar `contexto/projeto-arquitetura-integra.md` nem `contexto/arquivo-original-classroom.md`.
