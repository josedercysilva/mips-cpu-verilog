# ============================================================================
# Universidade Federal do Amazonas - UFAM
# Faculdade de Engenharia Eletrica e da Computacao - FEEC
# Clock Base para Analise Temporal Estatica (TimeQuest / quartus_sta)
# Alvo: DE10-Lite MAX 10 (50 MHz -> T = 20.000 ns)
# ============================================================================

create_clock -name clk -period 20.000 [get_ports {clk}]
derive_clock_uncertainty
