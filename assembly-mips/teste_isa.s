# ============================================================================
# Universidade Federal do Amazonas - UFAM
# Faculdade de Engenharia Eletrica e da Computacao - FEEC
# Disciplina: Arquitetura de Sistemas Digitais e Laboratorio
# Manaus, Amazonas, Brasil
# ----------------------------------------------------------------------------
# Programa: teste_isa.s — Validacao das 16 Instrucoes Suportadas (Bare-Metal)
# Descricao: Compativel diretamente com o hardware MIPS Pipeline e com o MARS
#            (montar no MARS com Delayed Branching DESMARCADO e exportar .text
#            em Binary para gerar teste_isa.bin).
#
# Instrucoes exercitadas (todas as 16):
#   Tipo-R: add, sub, and, or, slt, nor, sll, jr
#   Tipo-I: lw, sw, addi, slti, beq, bne
#   Tipo-J: j, jal
#
# Saidas gravadas na RAM (ram[16..26], enderecos 64..104):
#   ram[16] ( 64):   10  (add:  15 + -5)
#   ram[17] ( 68):   20  (sub:  15 - -5)
#   ram[18] ( 72):   40  (sll:  10 << 2)
#   ram[19] ( 76):   15  (and:  0x00FF & 0x0F0F)
#   ram[20] ( 80): 4095  (or:   0x00FF | 0x0F0F)
#   ram[21] ( 84): -4096 (nor:  ~(0x00FF | 0x0F0F) = 0xFFFFF000)
#   ram[22] ( 88):    3  (slt/slti: bits combinados = 0b0011)
#   ram[23] ( 92): 4095  (sw)
#   ram[24] ( 96): 4096  (lw + addi Load-Use)
#   ram[25] (100): 1150  (beq/bne/jal/jr/j sem nop de delay slot)
#   ram[26] (104): 31438 (0x7ACE — assinatura de sucesso)
# ============================================================================

.set noreorder
.text
.global main

main:
    # ------------------------------------------------------------------------
    # 1. Aritmetica e deslocamento: addi, add, sub, sll
    # ------------------------------------------------------------------------
    addi $t0, $zero, 15         # $t0 = 15
    addi $t1, $zero, -5         # $t1 = -5 (testa extensao de sinal)
    add  $t2, $t0, $t1          # $t2 = 10
    sub  $t3, $t0, $t1          # $t3 = 20
    sll  $t4, $t2, 2            # $t4 = 40

    sw   $t2, 64($zero)         # ram[16] = 10
    sw   $t3, 68($zero)         # ram[17] = 20
    sw   $t4, 72($zero)         # ram[18] = 40

    # ------------------------------------------------------------------------
    # 2. Operacoes logicas: and, or, nor
    # ------------------------------------------------------------------------
    addi $t5, $zero, 255        # $t5 = 0x000000FF
    addi $t6, $zero, 3855       # $t6 = 0x00000F0F
    and  $s0, $t5, $t6          # $s0 = 0x0000000F (15)
    or   $s1, $t5, $t6          # $s1 = 0x00000FFF (4095)
    nor  $s2, $t5, $t6          # $s2 = 0xFFFFF000 (-4096)

    sw   $s0, 76($zero)         # ram[19] = 15
    sw   $s1, 80($zero)         # ram[20] = 4095
    sw   $s2, 84($zero)         # ram[21] = -4096

    # ------------------------------------------------------------------------
    # 3. Comparacoes com sinal (slt, slti) e acesso a memoria (sw, lw)
    # ------------------------------------------------------------------------
    slt  $t7, $t1, $t0          # -5 < 15 -> 1
    slt  $t8, $t0, $t1          # 15 < -5 -> 0
    slti $t9, $t1, 0            # -5 < 0  -> 1
    slti $s3, $t0, 10           # 15 < 10 -> 0

    sll  $t7, $t7, 1            # $t7 = 2
    or   $t7, $t7, $t9          # $t7 = 3
    or   $t7, $t7, $t8          # $t7 = 3 (confirma $t8 == 0)
    or   $s4, $t7, $s3          # $s4 = 3 (confirma $s3 == 0)
    sw   $s4, 88($zero)         # ram[22] = 3

    sw   $s1, 92($zero)         # ram[23] = 4095
    lw   $s5, 92($zero)         # $s5 = 4095
    addi $s5, $s5, 1            # $s5 = 4096 (Load-Use imediato)
    sw   $s5, 96($zero)         # ram[24] = 4096

    # ------------------------------------------------------------------------
    # 4. Controle de fluxo sem nop: beq, bne, jal, jr, j
    # ------------------------------------------------------------------------
    beq  $t0, $t1, isa_fail     # 15 == -5 (nao deve desviar)
    bne  $t0, $t1, isa_ok       # 15 != -5 (deve desviar)
    j    isa_fail               # armadilha: descartada por flush do bne

isa_ok:
    addi $s6, $zero, 100        # $s6 = 100
    jal  isa_subrotina          # salva PC+4 em $ra e salta
    addi $s6, $s6, 1000         # ponto de retorno: executa 1 unica vez
    j    isa_after_sub
    addi $s6, $s6, 2000         # armadilha pos-j: descartada por flush

isa_subrotina:
    addi $s6, $s6, 50           # $s6 = 150
    jr   $ra
    addi $s6, $s6, 4000         # armadilha pos-jr: descartada por flush

isa_after_sub:
    sw   $s6, 100($zero)        # ram[25] = 1150
    addi $s7, $zero, 0x7ACE     # 31438 (assinatura valida em 16 bits com sinal)
    sw   $s7, 104($zero)        # ram[26] = 31438

isa_done:
    j    isa_done               # laco final seguro em hardware

isa_fail:
    sw   $zero, 104($zero)      # ram[26] = 0 em caso de falha
    j    isa_fail
