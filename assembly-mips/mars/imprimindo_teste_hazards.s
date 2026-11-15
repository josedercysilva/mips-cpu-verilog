# ============================================================================
# Universidade Federal do Amazonas - UFAM
# Faculdade de Engenharia Eletrica e da Computacao - FEEC
# Disciplina: Arquitetura de Sistemas Digitais e Laboratorio
# Manaus, Amazonas, Brasil
# ----------------------------------------------------------------------------
# Programa: imprimindo_teste_hazards.s — Espelho MARS de teste_hazards.s
# Descricao: Executa os mesmos testes de teste_hazards.s em um buffer .data
#            (ram_sim) e imprime todos os resultados no console Run I/O do MARS
#            via syscall (exclusivo para simulacao visual no MARS 4.5).
# ============================================================================

.data
ram_sim:    .space 256          # Simula 64 palavras da RAM (ram[0..63])

msg_titulo: .asciiz "=== Validacao de Hazards e Recursao (MARS) ===\n"
msg_fwd:    .asciiz "ram[32] Forwarding EX/MEM, MEM/WB e dupla  = "
msg_zero:   .asciiz " (esperado: 190)\nram[33] Protecao de $zero ($0)             = "
msg_lu:     .asciiz " (esperado: 1)\nram[34] Stall Load-Use (lw->addi/add/sw)   = "
msg_lwsw:   .asciiz " (esperado: 90)\nram[35] Dado propagado lw -> sw            = "
msg_ctrl:   .asciiz " (esperado: 25)\nram[36] Flush em beq, bne e j sem nop      = "
msg_jaljr:  .asciiz " (esperado: 60)\nram[37] Retorno imediato jal -> jr $ra     = "
msg_lwjr:   .asciiz " (esperado: 15)\nram[38] Load-Use lw $ra -> jr $ra          = "
msg_fib:    .asciiz " (esperado: 128)\nram[39] Fibonacci recursivo fib(7)         = "
msg_sig:    .asciiz " (esperado: 13)\nram[40] Assinatura final (0x5AFE)          = "
msg_fim:    .asciiz " (esperado: 23294)\n=== Fim da Validacao de Hazards ===\n"

.text
.globl main

main:
    la   $a2, ram_sim           # Base segura no segmento .data do MARS

    # 1. Forwarding EX/MEM -> EX, MEM/WB -> EX e prioridade (Double Hazard)
    addi $t0, $zero, 10
    addi $t1, $zero, 20
    add  $t2, $t0, $t1          # 30
    sub  $t3, $t2, $t0          # 20
    add  $t4, $t1, $t3          # 40

    addi $t5, $zero, 5
    addi $t5, $zero, 50
    add  $t6, $t5, $t5          # 100

    add  $t7, $t2, $t3          # 50
    add  $t7, $t7, $t4          # 90
    add  $t7, $t7, $t6          # 190
    sw   $t7, 128($a2)          # ram[32] = 190

    # 2. Protecao do registrador $zero ($0)
    addi $zero, $zero, 77
    add  $s0, $zero, $zero
    add  $s1, $zero, $zero
    add  $s2, $zero, $zero
    add  $s0, $s0, $s1
    add  $s0, $s0, $s2
    addi $s0, $s0, 1
    sw   $s0, 132($a2)          # ram[33] = 1

    # 3. Stall Load-Use: lw -> addi (rs), lw -> add (rt) e lw -> sw
    addi $t0, $zero, 25
    sw   $t0, 136($a2)
    addi $t1, $zero, 10

    lw   $t2, 136($a2)
    addi $t3, $t2, 5            # 30

    lw   $t4, 136($a2)
    add  $t5, $t1, $t4          # 35

    lw   $t6, 136($a2)
    sw   $t6, 140($a2)          # ram[35] = 25
    lw   $t7, 140($a2)          # 25

    add  $t8, $t3, $t5          # 65
    add  $t8, $t8, $t7          # 90
    sw   $t8, 136($a2)          # ram[34] = 90

    # 4. Flush em beq, bne e j sem nop
    addi $s0, $zero, 0
    addi $t0, $zero, 7
    addi $t1, $zero, 7

    beq  $t0, $t1, hz_beq_ok
    addi $s0, $s0, 100
    addi $s0, $s0, 200

hz_beq_ok:
    addi $s0, $s0, 10
    addi $t1, $zero, 8

    beq  $t0, $t1, hz_ctrl_fail
    bne  $t0, $t1, hz_bne_ok
    addi $s0, $s0, 400
    addi $s0, $s0, 800

hz_bne_ok:
    addi $s0, $s0, 20
    j    hz_j_ok
    addi $s0, $s0, 1000
    addi $s0, $s0, 2000

hz_ctrl_fail:
    addi $s0, $zero, -999
    j    hz_ctrl_save

hz_j_ok:
    addi $s0, $s0, 30

hz_ctrl_save:
    sw   $s0, 144($a2)          # ram[36] = 60

    # 5. Retorno imediato jal -> jr $ra
    addi $s1, $zero, 5
    jal  hz_ret_imediato
    addi $s1, $s1, 10
    sw   $s1, 148($a2)          # ram[37] = 15
    j    hz_teste_lw_jr

hz_ret_imediato:
    jr   $ra
    addi $s1, $s1, 500

    # 6. Load-Use combinado com jr $ra: lw $ra -> jr $ra
hz_teste_lw_jr:
    addi $s2, $zero, 0
    jal  hz_outer
    addi $s2, $s2, 5
    sw   $s2, 152($a2)          # ram[38] = 128
    j    hz_teste_fib

hz_outer:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    addi $s2, $s2, 100
    jal  hz_inner
    addi $sp, $sp, 4
    lw   $ra, -4($sp)
    jr   $ra
    addi $s2, $s2, 999

hz_inner:
    addi $s2, $s2, 23
    jr   $ra

    # 7. Estresse com recursao dupla e pilha: fib(7) = 13
hz_teste_fib:
    addi $a0, $zero, 7
    jal  fib
    sw   $v0, 156($a2)          # ram[39] = 13

    # 8. Assinatura de conclusao
    addi $s7, $zero, 0x5AFE
    sw   $s7, 160($a2)          # ram[40] = 23294

    # ------------------------------------------------------------------------
    # Impressao dos resultados no console Run I/O do MARS
    # ------------------------------------------------------------------------
    li   $v0, 4
    la   $a0, msg_titulo
    syscall

    li   $v0, 4
    la   $a0, msg_fwd
    syscall
    li   $v0, 1
    lw   $a0, 128($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_zero
    syscall
    li   $v0, 1
    lw   $a0, 132($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_lu
    syscall
    li   $v0, 1
    lw   $a0, 136($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_lwsw
    syscall
    li   $v0, 1
    lw   $a0, 140($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_ctrl
    syscall
    li   $v0, 1
    lw   $a0, 144($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_jaljr
    syscall
    li   $v0, 1
    lw   $a0, 148($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_lwjr
    syscall
    li   $v0, 1
    lw   $a0, 152($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_fib
    syscall
    li   $v0, 1
    lw   $a0, 156($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_sig
    syscall
    li   $v0, 1
    lw   $a0, 160($a2)
    syscall

    li   $v0, 4
    la   $a0, msg_fim
    syscall

    li   $v0, 10
    syscall

# Funcao recursiva: int fib(int n)
fib:
    slti $t0, $a0, 2
    beq  $t0, $zero, fib_rec
    add  $v0, $a0, $zero
    jr   $ra

fib_rec:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $s0, 0($sp)

    addi $a0, $a0, -1
    jal  fib
    add  $s0, $v0, $zero

    lw   $a0, 4($sp)
    addi $a0, $a0, -2
    jal  fib
    add  $v0, $s0, $v0

    lw   $s0, 0($sp)
    addi $sp, $sp, 12
    lw   $ra, -4($sp)
    jr   $ra
