# ============================================================================
# Universidade Federal do Amazonas - UFAM
# Faculdade de Engenharia Eletrica e da Computacao - FEEC
# Disciplina: Arquitetura de Sistemas Digitais e Laboratorio
# Manaus, Amazonas, Brasil
# ----------------------------------------------------------------------------
# Programa: imprimindo_isa.s — Execucao e Impressao Visual no MARS 4.5
# Descricao: Espelha exatamente os testes de teste_isa.s em um buffer de
#            memoria .data (ram_sim) e imprime todos os resultados no console
#            Run I/O do MARS via syscall (somente para simulacao no MARS).
# ============================================================================

.data
ram_sim:    .space 128          # Simula 32 palavras da RAM (ram[0..31])

msg_titulo: .asciiz "=== Validacao das 16 Instrucoes MIPS (MARS) ===\n"
msg_add:    .asciiz "ram[16] add  (15 + -5)         = "
msg_sub:    .asciiz " (esperado: 10)\nram[17] sub  (15 - -5)         = "
msg_sll:    .asciiz " (esperado: 20)\nram[18] sll  (10 << 2)         = "
msg_and:    .asciiz " (esperado: 40)\nram[19] and  (255 & 3855)      = "
msg_or:     .asciiz " (esperado: 15)\nram[20] or   (255 | 3855)      = "
msg_nor:    .asciiz " (esperado: 4095)\nram[21] nor  (~(255 | 3855))   = "
msg_slt:    .asciiz " (esperado: -4096)\nram[22] slt/slti (0b0011)      = "
msg_sw:     .asciiz " (esperado: 3)\nram[23] sw                     = "
msg_lw:     .asciiz " (esperado: 4095)\nram[24] lw + addi (Load-Use)   = "
msg_ctrl:   .asciiz " (esperado: 4096)\nram[25] beq/bne/jal/jr/j       = "
msg_sig:    .asciiz " (esperado: 1150)\nram[26] assinatura (0x7ACE)    = "
msg_fim:    .asciiz " (esperado: 31438)\n=== Fim da Validacao ===\n"

.text
.globl main

main:
    la   $a2, ram_sim           # Base segura no segmento .data do MARS

    # 1. Aritmetica e deslocamento
    addi $t0, $zero, 15
    addi $t1, $zero, -5
    add  $t2, $t0, $t1
    sub  $t3, $t0, $t1
    sll  $t4, $t2, 2

    sw   $t2, 64($a2)           # ram[16] = 10
    sw   $t3, 68($a2)           # ram[17] = 20
    sw   $t4, 72($a2)           # ram[18] = 40

    # 2. Logicas
    addi $t5, $zero, 255
    addi $t6, $zero, 3855
    and  $s0, $t5, $t6
    or   $s1, $t5, $t6
    nor  $s2, $t5, $t6

    sw   $s0, 76($a2)           # ram[19] = 15
    sw   $s1, 80($a2)           # ram[20] = 4095
    sw   $s2, 84($a2)           # ram[21] = -4096

    # 3. Comparacoes e memoria
    slt  $t7, $t1, $t0
    slt  $t8, $t0, $t1
    slti $t9, $t1, 0
    slti $s3, $t0, 10

    sll  $t7, $t7, 1
    or   $t7, $t7, $t9
    or   $t7, $t7, $t8
    or   $s4, $t7, $s3
    sw   $s4, 88($a2)           # ram[22] = 3

    sw   $s1, 92($a2)           # ram[23] = 4095
    lw   $s5, 92($a2)
    addi $s5, $s5, 1
    sw   $s5, 96($a2)           # ram[24] = 4096

    # 4. Controle de fluxo (MARS com Delayed Branching desmarcado)
    beq  $t0, $t1, isa_fail
    bne  $t0, $t1, isa_ok
    j    isa_fail

isa_ok:
    addi $s6, $zero, 100
    jal  isa_subrotina
    addi $s6, $s6, 1000
    j    isa_after_sub
    addi $s6, $s6, 2000

isa_subrotina:
    addi $s6, $s6, 50
    jr   $ra
    addi $s6, $s6, 4000

isa_fail:
    sw   $zero, 104($a2)
    j    imprimir

isa_after_sub:
    sw   $s6, 100($a2)          # ram[25] = 1150
    addi $s7, $zero, 0x7ACE
    sw   $s7, 104($a2)          # ram[26] = 31438

imprimir:
    li   $v0, 4
    la   $a0, msg_titulo
    syscall

    li   $v0, 4
    la   $a0, msg_add
    syscall
    li   $v0, 1
    lw   $a0, 64($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_sub
    syscall
    li   $v0, 1
    lw   $a0, 68($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_sll
    syscall
    li   $v0, 1
    lw   $a0, 72($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_and
    syscall
    li   $v0, 1
    lw   $a0, 76($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_or
    syscall
    li   $v0, 1
    lw   $a0, 80($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_nor
    syscall
    li   $v0, 1
    lw   $a0, 84($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_slt
    syscall
    li   $v0, 1
    lw   $a0, 88($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_sw
    syscall
    li   $v0, 1
    lw   $a0, 92($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_lw
    syscall
    li   $v0, 1
    lw   $a0, 96($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_ctrl
    syscall
    li   $v0, 1
    lw   $a0, 100($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_sig
    syscall
    li   $v0, 1
    lw   $a0, 104($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_fim
    syscall

    li   $v0, 10
    syscall
