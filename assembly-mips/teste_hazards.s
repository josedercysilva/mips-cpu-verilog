# ============================================================================
# Universidade Federal do Amazonas - UFAM
# Faculdade de Engenharia Eletrica e da Computacao - FEEC
# Disciplina: Arquitetura de Sistemas Digitais e Laboratorio
# Manaus, Amazonas, Brasil
# ----------------------------------------------------------------------------
# Programa: teste_hazards.s — Estresse de Pipeline e Hazards (Bare-Metal)
# Descricao: Exercita deliberadamente, sem nenhum 'nop' artificial, todos os
#            caminhos de resolucao de riscos do pipeline de 5 estagios:
#              1) Forwarding EX/MEM -> EX e MEM/WB -> EX (rs, rt e prioridade)
#              2) Protecao do registrador $zero ($0) contra forwarding/escrita
#              3) Stall Load-Use (lw -> addi/add em rs/rt e lw -> sw)
#              4) Flush em beq, bne e j com armadilhas pos-salto
#              5) Retorno imediato jal -> jr $ra (EX/MEM forwarding de PC+4)
#              6) Load-Use combinado com salto indireto (lw $ra -> jr $ra)
#              7) Estresse real com recursao dupla e pilha: fib(7) = 13
#
#            Compativel com o hardware MIPS Pipeline e com o MARS 4.5
#            (Delayed branching DESMARCADO; exportar .text em Binary).
#
# Saidas gravadas na RAM (ram[32..40], enderecos 128..160):
#   ram[32] (128):   190 (Forwarding EX/MEM, MEM/WB e prioridade dupla)
#   ram[33] (132):     1 (Protecao de $zero no forwarding e WB->ID)
#   ram[34] (136):    90 (Load-Use lw->addi, lw->add, lw->sw)
#   ram[35] (140):    25 (Valor propagado diretamente de lw para sw)
#   ram[36] (144):    60 (Flush em beq, bne e j sem nop)
#   ram[37] (148):    15 (Retorno imediato jal -> jr $ra + flush)
#   ram[38] (152):   128 (Load-Use lw $ra -> jr $ra)
#   ram[39] (156):    13 (Fibonacci recursivo fib(7))
#   ram[40] (160): 23294 (0x5AFE — assinatura de sucesso)
# ============================================================================

.set noreorder
.text
.global main

main:
    addi $sp, $zero, 1020       # Pilha no topo real da RAM (ram[255] para baixo)

    # ------------------------------------------------------------------------
    # 1. Forwarding EX/MEM -> EX, MEM/WB -> EX e prioridade (Double Hazard)
    # ------------------------------------------------------------------------
    addi $t0, $zero, 10         # $t0 = 10
    addi $t1, $zero, 20         # $t1 = 20
    add  $t2, $t0, $t1          # $t2 = 30 (MEM/WB em rs, EX/MEM em rt)
    sub  $t3, $t2, $t0          # $t3 = 20 (EX/MEM em rs)
    add  $t4, $t1, $t3          # $t4 = 40 (EX/MEM em rt)

    addi $t5, $zero, 5          # Escrita antiga (estara em MEM/WB)
    addi $t5, $zero, 50         # Escrita recente (estara em EX/MEM -> vence!)
    add  $t6, $t5, $t5          # $t6 = 100 (ambos operandos devem receber 50)

    add  $t7, $t2, $t3          # $t7 = 50
    add  $t7, $t7, $t4          # $t7 = 90
    add  $t7, $t7, $t6          # $t7 = 190
    sw   $t7, 128($zero)        # ram[32] = 190 (testa tambem EX/MEM -> sw)

    # ------------------------------------------------------------------------
    # 2. Protecao do registrador $zero ($0) em EX/MEM, MEM/WB e WB->ID
    # ------------------------------------------------------------------------
    addi $zero, $zero, 77       # Tentativa invalida de alterar $0
    add  $s0, $zero, $zero      # 1 ciclo depois (EX/MEM): deve continuar 0
    add  $s1, $zero, $zero      # 2 ciclos depois (MEM/WB): deve continuar 0
    add  $s2, $zero, $zero      # 3 ciclos depois (WB->ID): deve continuar 0
    add  $s0, $s0, $s1
    add  $s0, $s0, $s2
    addi $s0, $s0, 1            # $s0 = 1 se $zero permaneceu 0
    sw   $s0, 132($zero)        # ram[33] = 1

    # ------------------------------------------------------------------------
    # 3. Stall Load-Use: lw -> addi (rs), lw -> add (rt) e lw -> sw
    # ------------------------------------------------------------------------
    addi $t0, $zero, 25
    sw   $t0, 136($zero)        # ram[34] = 25
    addi $t1, $zero, 10

    lw   $t2, 136($zero)        # $t2 = 25
    addi $t3, $t2, 5            # Load-Use imediato em rs -> $t3 = 30

    lw   $t4, 136($zero)        # $t4 = 25
    add  $t5, $t1, $t4          # Load-Use imediato em rt -> $t5 = 35

    lw   $t6, 136($zero)        # $t6 = 25
    sw   $t6, 140($zero)        # Load-Use lw -> sw -> ram[35] = 25
    lw   $t7, 140($zero)        # $t7 = 25

    add  $t8, $t3, $t5          # $t8 = 65
    add  $t8, $t8, $t7          # $t8 = 90
    sw   $t8, 136($zero)        # ram[34] = 90 (e ram[35] = 25)

    # ------------------------------------------------------------------------
    # 4. Flush em beq, bne e j sem nop
    # ------------------------------------------------------------------------
    addi $s0, $zero, 0
    addi $t0, $zero, 7
    addi $t1, $zero, 7

    beq  $t0, $t1, hz_beq_ok
    addi $s0, $s0, 100          # armadilha 1 pos-beq: flush!
    addi $s0, $s0, 200          # armadilha 2 pos-beq: flush!

hz_beq_ok:
    addi $s0, $s0, 10           # $s0 = 10
    addi $t1, $zero, 8

    beq  $t0, $t1, hz_ctrl_fail # nao tomado (7 != 8)
    bne  $t0, $t1, hz_bne_ok    # tomado!
    addi $s0, $s0, 400          # armadilha 1 pos-bne: flush!
    addi $s0, $s0, 800          # armadilha 2 pos-bne: flush!

hz_bne_ok:
    addi $s0, $s0, 20           # $s0 = 30
    j    hz_j_ok
    addi $s0, $s0, 1000         # armadilha pos-j: flush!
    addi $s0, $s0, 2000

hz_ctrl_fail:
    addi $s0, $zero, -999
    j    hz_ctrl_save

hz_j_ok:
    addi $s0, $s0, 30           # $s0 = 60

hz_ctrl_save:
    sw   $s0, 144($zero)        # ram[36] = 60

    # ------------------------------------------------------------------------
    # 5. Retorno imediato jal -> jr $ra (EX/MEM forwarding de PC+4 + flush)
    # ------------------------------------------------------------------------
    addi $s1, $zero, 5
    jal  hz_ret_imediato
    addi $s1, $s1, 10           # deve executar exatamente 1 vez -> $s1 = 15
    sw   $s1, 148($zero)        # ram[37] = 15
    j    hz_teste_lw_jr

hz_ret_imediato:
    jr   $ra                    # 1a instrucao da sub-rotina!
    addi $s1, $s1, 500          # armadilha pos-jr: flush!

    # ------------------------------------------------------------------------
    # 6. Load-Use combinado com jr $ra: lw $ra seguido imediatamente de jr $ra
    # ------------------------------------------------------------------------
hz_teste_lw_jr:
    addi $s2, $zero, 0
    jal  hz_outer
    addi $s2, $s2, 5            # $s2 = 123 + 5 = 128
    sw   $s2, 152($zero)        # ram[38] = 128
    j    hz_teste_fib

hz_outer:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    addi $s2, $s2, 100          # $s2 = 100
    jal  hz_inner
    addi $sp, $sp, 4
    lw   $ra, -4($sp)           # carrega $ra logo antes do jr $ra!
    jr   $ra                    # Load-Use + forwarding WB -> EX para next_pc
    addi $s2, $s2, 999          # armadilha pos-jr: flush!

hz_inner:
    addi $s2, $s2, 23           # $s2 = 123
    jr   $ra

    # ------------------------------------------------------------------------
    # 7. Estresse com recursao dupla e pilha: fib(7) = 13
    # ------------------------------------------------------------------------
hz_teste_fib:
    addi $a0, $zero, 7
    jal  fib
    sw   $v0, 156($zero)        # ram[39] = 13

    # ------------------------------------------------------------------------
    # 8. Assinatura de conclusao
    # ------------------------------------------------------------------------
    addi $s7, $zero, 0x5AFE     # 23294
    sw   $s7, 160($zero)        # ram[40] = 23294

haz_done:
    j    haz_done

# ============================================================================
# Funcao recursiva: int fib(int n)
# Entrada: $a0 = n | Saida: $v0 = fib(n)
# ============================================================================
fib:
    slti $t0, $a0, 2            # n < 2 ?
    beq  $t0, $zero, fib_rec
    add  $v0, $a0, $zero        # caso base: retorna n
    jr   $ra

fib_rec:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $s0, 0($sp)

    addi $a0, $a0, -1           # n - 1
    jal  fib
    add  $s0, $v0, $zero        # $s0 = fib(n - 1)

    lw   $a0, 4($sp)            # recupera n
    addi $a0, $a0, -2           # Load-Use em $a0 -> n - 2
    jal  fib
    add  $v0, $s0, $v0          # fib(n - 1) + fib(n - 2)

    lw   $s0, 0($sp)
    addi $sp, $sp, 12
    lw   $ra, -4($sp)           # Load-Use imediato antes de jr $ra!
    jr   $ra
