# Programas Assembly MIPS e Firmwares (`assembly-mips/`)

Este diretório separa os códigos **bare-metal para o hardware** (raiz) dos códigos **exclusivos para simulação visual no MARS** (`mars/`).

---

## 1. Estrutura

```text
assembly-mips/
├── sort.s             # Bubble Sort bare-metal (benchmark oficial da disciplina)
├── sort.bin           # Código de máquina de sort.s carregado na ROM (instr_mem.v)
├── teste_isa.s        # Validação das 16 instruções suportadas (bare-metal, sem syscall)
├── teste_isa.bin      # Código de máquina de teste_isa.s exportado pelo MARS
├── teste_hazards.s    # Estresse de forwarding, Load-Use, flush e recursão (sem nop)
├── teste_hazards.bin  # Código de máquina de teste_hazards.s exportado pelo MARS
└── mars/              # Programas exclusivos do simulador MARS (.data + syscall)
    ├── sort-teste.s               # Bubble Sort com impressão no console Run I/O
    ├── imprimindo_isa.s           # Espelho de teste_isa.s com impressão no console Run I/O
    └── imprimindo_teste_hazards.s # Espelho de teste_hazards.s com impressão no console Run I/O
```

> Os firmwares da raiz usam **apenas as 16 instruções suportadas** pelo processador MIPS Pipeline (e pelo baseline Monociclo): `add`, `sub`, `and`, `or`, `slt`, `nor`, `sll`, `jr`, `lw`, `sw`, `addi`, `slti`, `beq`, `bne`, `j`, `jal`.

---

## 2. Como Gerar o `.bin` no MARS 4.5 (para Verilog / FPGA)

1. No MARS (`java -jar Mars4_5.jar`), confirme em **Settings**:
   * **Memory Configuration:** `Default`
   * **Delayed branching:** **desmarcado** (para códigos sem `nop` no slot de desvio)
2. Abra um arquivo `.s` bare-metal da raiz (ex.: `sort.s` ou `teste_isa.s`) e monte com **Run → Assemble** (`F3`).
3. Exporte em **File → Dump Memory...**:
   * **Memory Segment:** `.text (0x00400000 - ...)`
   * **Dump Format:** `Binary` *(gera linhas de 32 bits em ASCII `'0'`/`'1'` para o `$readmemb`)*
   * Salve como `<nome>.bin` na raiz de `assembly-mips/`.
