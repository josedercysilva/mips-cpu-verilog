#!/usr/bin/env python3
"""Extrai e compara métricas de síntese, latches e timing dos relatórios do Intel Quartus Prime."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple


ROOT_DIR = Path(__file__).resolve().parent.parent

BASELINE_MONOCICLO_DOC = {
    "logic_elements": "17,089 (baseline doc Entrega 02)",
    "latches": "0 (baseline doc Entrega 02)",
}


@dataclass
class LatchAudit:
    """Resultado da auditoria de latches inferidos e avisos HDL no .map.rpt."""

    inferred_count: Optional[int] = None
    inferred_signals: List[str] = field(default_factory=list)
    hdl_latch_warnings: List[str] = field(default_factory=list)
    loop_var_warnings: List[str] = field(default_factory=list)


@dataclass
class FmaxEntry:
    """Entrada de frequência máxima por corner de temperatura/tensão no .sta.rpt."""

    model: str
    clock: str
    fmax_mhz: float
    restricted_fmax_mhz: Optional[float]


@dataclass
class QuartusMetrics:
    """Métricas consolidadas de uma revisão Quartus (.map / .fit / .flow / .sta)."""

    label: str
    revision: str
    source_dir: Path
    exists: bool
    stage: str = "Não compilado"
    status: str = "N/A"
    quartus_version: str = "N/A"
    device: str = "N/A"
    logic_elements: str = "N/A"
    combinational_functions: str = "N/A"
    dedicated_registers: str = "N/A"
    total_registers: str = "N/A"
    total_pins: str = "N/A"
    memory_bits: str = "N/A"
    fmax_entries: List[FmaxEntry] = field(default_factory=list)
    worst_slow_fmax_mhz: Optional[float] = None
    setup_slack_ns: Optional[str] = None
    elapsed_total: str = "N/A"
    latch_audit: LatchAudit = field(default_factory=LatchAudit)


def _read_text(path: Path) -> str:
    """Lê arquivo texto em UTF-8 tolerando caracteres inválidos."""
    return path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""


def _parse_colon_summary(text: str) -> Dict[str, str]:
    """Lê pares 'Chave : Valor' de arquivos .summary do Quartus."""
    data: Dict[str, str] = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        clean_key = key.strip()
        if clean_key:
            data[clean_key] = value.strip()
    return data


def _parse_ascii_section(text: str, title_pattern: str) -> List[List[str]]:
    """Extrai linhas '; c1 ; c2 ; ... ;' de uma seção tabular específica de um .rpt."""
    lines = text.splitlines()
    pattern = re.compile(title_pattern, re.IGNORECASE)
    rows: List[List[str]] = []
    in_section = False

    for i, line in enumerate(lines):
        stripped = line.strip()
        if not in_section:
            if stripped.startswith(";") and stripped.endswith(";"):
                title = stripped.strip(";").strip()
                if pattern.search(title):
                    in_section = True
            continue

        if stripped.startswith("+") and set(stripped) <= {"+", "-"}:
            next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""
            if rows and not next_line.startswith(";"):
                break
            continue

        if stripped.startswith(";") and stripped.endswith(";"):
            cols = [c.strip() for c in stripped.strip(";").split(";")]
            rows.append(cols)
        elif stripped == "" and rows:
            break
    return rows


def _parse_kv_section(text: str, title_pattern: str) -> Dict[str, str]:
    """Extrai dicionário chave -> valor de tabela Quartus de 2 colunas."""
    kv: Dict[str, str] = {}
    for cols in _parse_ascii_section(text, title_pattern):
        if len(cols) >= 2 and cols[0]:
            kv[cols[0]] = cols[1]
    return kv


def _parse_mhz(cell: str) -> Optional[float]:
    """Converte string '78.42 MHz' em float MHz."""
    match = re.search(r"([0-9]+(?:\.[0-9]+)?)\s*MHz", cell, re.IGNORECASE)
    return float(match.group(1)) if match else None


def _parse_fmax_models(sta_text: str) -> List[FmaxEntry]:
    """Coleta todas as tabelas '* Model Fmax Summary' do arquivo .sta.rpt."""
    entries: List[FmaxEntry] = []
    header_re = re.compile(r"^\s*;\s*(.+?Model\s+Fmax\s+Summary)\s*;\s*$", re.IGNORECASE)
    lines = sta_text.splitlines()
    idx = 0
    while idx < len(lines):
        match = header_re.match(lines[idx])
        if not match:
            idx += 1
            continue
        model_name = match.group(1).replace(" Fmax Summary", "").strip()
        idx += 1
        col_headers: List[str] = []
        while idx < len(lines):
            stripped = lines[idx].strip()
            if stripped.startswith(";") and stripped.endswith(";"):
                cols = [c.strip() for c in stripped.strip(";").split(";")]
                if not col_headers:
                    col_headers = [c.lower() for c in cols]
                else:
                    fmax_val = _parse_mhz(cols[0]) if len(cols) > 0 else None
                    restr_val = _parse_mhz(cols[1]) if len(cols) > 1 else None
                    clk_name = cols[2] if len(cols) > 2 else "clk"
                    if fmax_val is not None:
                        entries.append(FmaxEntry(model_name, clk_name, fmax_val, restr_val))
            elif stripped.startswith("+") and col_headers and entries:
                # Segunda borda após dados indica fim da tabela
                if idx + 1 < len(lines) and not lines[idx + 1].strip().startswith(";"):
                    break
            elif stripped == "" and col_headers:
                break
            idx += 1
        idx += 1
    return entries


def _parse_setup_slack(sta_text: str, sta_summary_text: str) -> Optional[str]:
    """Extrai o pior slack de setup a partir do .sta.summary ou .sta.rpt."""
    for text in (sta_summary_text, sta_text):
        match = re.search(r"Slack\s*[:;]\s*([-+]?[0-9]+(?:\.[0-9]+)?)", text, re.IGNORECASE)
        if match:
            return f"{match.group(1)} ns"
    rows = _parse_ascii_section(sta_text, r"Setup Summary$")
    if len(rows) >= 2:
        headers = [h.lower() for h in rows[0]]
        if "slack" in headers:
            slack_idx = headers.index("slack")
            if len(rows[1]) > slack_idx:
                return f"{rows[1][slack_idx]} ns"
    return None


def _parse_latch_audit(map_text: str) -> LatchAudit:
    """Analisa latches inferidos e diferencia aviso de variável de loop de latches reais."""
    audit = LatchAudit()
    if not map_text:
        return audit

    match_count = re.search(
        r"Number of User-Specified and Inferred Latches\s*[;=:]\s*(\d+)",
        map_text,
        re.IGNORECASE,
    )
    if match_count:
        audit.inferred_count = int(match_count.group(1))

    latch_rows = _parse_ascii_section(map_text, r"User-Specified and Inferred Latches")
    if len(latch_rows) >= 2:
        for row in latch_rows[1:]:
            joined = " | ".join(col for col in row if col)
            if joined and "none" not in joined.lower():
                audit.inferred_signals.append(joined)

    for line in map_text.splitlines():
        low = line.lower()
        if "latch" not in low:
            continue
        if "warning (10240)" in low and 'variable "i"' in low:
            audit.loop_var_warnings.append(line.strip())
        elif "warning (" in low and ("10631" in low or "10240" in low or "inferring latch" in low):
            audit.hdl_latch_warnings.append(line.strip())

    if audit.inferred_count is None and "Partition Merge" not in map_text:
        if "User-Specified and Inferred Latches" in map_text and not audit.inferred_signals:
            audit.inferred_count = 0
    return audit


def collect_project_metrics(label: str, revision: str, out_dir: Path) -> QuartusMetrics:
    """Coleta métricas completas de uma revisão Quartus em output_files/."""
    metrics = QuartusMetrics(label=label, revision=revision, source_dir=out_dir, exists=out_dir.is_dir())
    if not out_dir.is_dir():
        return metrics

    map_sum_text = _read_text(out_dir / f"{revision}.map.summary")
    fit_sum_text = _read_text(out_dir / f"{revision}.fit.summary")
    flow_text = _read_text(out_dir / f"{revision}.flow.rpt")
    map_rpt_text = _read_text(out_dir / f"{revision}.map.rpt")
    sta_rpt_text = _read_text(out_dir / f"{revision}.sta.rpt")
    sta_sum_text = _read_text(out_dir / f"{revision}.sta.summary")

    if not any([map_sum_text, fit_sum_text, flow_text, map_rpt_text, sta_rpt_text]):
        metrics.exists = False
        return metrics

    map_sum = _parse_colon_summary(map_sum_text)
    fit_sum = _parse_colon_summary(fit_sum_text)
    flow_sum = _parse_kv_section(flow_text, r"^Flow Summary$")

    # Prioridade: Pós-Fitter -> Flow Summary -> Map Summary
    merged: Dict[str, str] = {}
    for source in (map_sum, flow_sum, fit_sum):
        merged.update({k: v for k, v in source.items() if v and "N/A" not in v})

    metrics.quartus_version = merged.get("Quartus Prime Version", map_sum.get("Quartus Prime Version", "N/A"))
    metrics.device = merged.get("Device", flow_sum.get("Device", "N/A"))
    metrics.logic_elements = merged.get("Total logic elements", "N/A (rode make quartus-build)")
    metrics.combinational_functions = merged.get("Total combinational functions", "N/A")
    metrics.dedicated_registers = merged.get("Dedicated logic registers", "N/A")
    metrics.total_registers = merged.get("Total registers", "N/A")
    metrics.total_pins = merged.get("Total pins", "N/A")
    metrics.memory_bits = merged.get("Total memory bits", "N/A")

    if sta_rpt_text:
        metrics.stage = "Compilação Completa + TimeQuest (quartus_sta)"
    elif fit_sum_text:
        metrics.stage = "Síntese + Fitter (falta quartus_sta para Fmax)"
    elif map_sum_text:
        if "Analysis & Elaboration" in map_sum_text:
            metrics.stage = "Analysis & Elaboration (somente checagem HDL)"
        else:
            metrics.stage = "Analysis & Synthesis (falta Fitter/STA)"

    for key in ("Fitter Status", "Analysis & Synthesis Status", "Analysis & Elaboration Status", "Flow Status"):
        if key in fit_sum:
            metrics.status = fit_sum[key]
            break
        if key in map_sum:
            metrics.status = map_sum[key]
            break
        if key in flow_sum:
            metrics.status = flow_sum[key]
            break

    elapsed_kv = _parse_kv_section(flow_text, r"^Flow Elapsed Time$")
    if "Total" in elapsed_kv:
        metrics.elapsed_total = elapsed_kv["Total"]

    metrics.latch_audit = _parse_latch_audit(map_rpt_text)
    metrics.fmax_entries = _parse_fmax_models(sta_rpt_text)
    slow_fmax = [e.fmax_mhz for e in metrics.fmax_entries if "slow" in e.model.lower()]
    if slow_fmax:
        metrics.worst_slow_fmax_mhz = min(slow_fmax)
    elif metrics.fmax_entries:
        metrics.worst_slow_fmax_mhz = min(e.fmax_mhz for e in metrics.fmax_entries)

    metrics.setup_slack_ns = _parse_setup_slack(sta_rpt_text, sta_sum_text)
    return metrics


def _parse_leading_int(value: str) -> Optional[int]:
    """Extrai primeiro inteiro formatado ('17,089 / 49,760' -> 17089)."""
    match = re.search(r"([0-9][0-9,]*)", value)
    return int(match.group(1).replace(",", "")) if match else None


def _format_latches(audit: LatchAudit) -> str:
    """Resume resultado da auditoria de latches em uma linha legível."""
    if audit.inferred_count is not None:
        base = f"{audit.inferred_count} latch(es) inferido(s)"
    elif not audit.hdl_latch_warnings:
        base = "0 latches reais detectados"
    else:
        base = f"{len(audit.hdl_latch_warnings)} aviso(s) suspeito(s)"
    if audit.loop_var_warnings:
        base += f" (+ {len(audit.loop_var_warnings)} aviso benigno de índice de loop 10240)"
    return base


def _format_fmax(m: QuartusMetrics) -> str:
    """Formata pior Fmax e período mínimo de clock."""
    if m.worst_slow_fmax_mhz is None:
        return "N/A (rode make quartus-build / quartus-sta)"
    t_ns = 1000.0 / m.worst_slow_fmax_mhz
    return f"{m.worst_slow_fmax_mhz:.2f} MHz (T_min = {t_ns:.2f} ns)"


def render_terminal(pipe: QuartusMetrics, mono: QuartusMetrics) -> str:
    """Gera relatório colorido/estruturado para o terminal."""
    lines = [
        "=" * 78,
        "   UFAM / FEEC — Resumo de Métricas Intel Quartus Prime (MAX 10 DE10-Lite)",
        "=" * 78,
        f"Projeto {pipe.label:<9s}: {pipe.source_dir}",
        f"Estágio atual    : {pipe.stage}",
        f"Status           : {pipe.status}",
        f"Dispositivo      : {pipe.device}",
        f"Tempo total flow : {pipe.elapsed_total}",
        "-" * 78,
        f"Logic Elements   : {pipe.logic_elements}",
        f"Comb. Functions  : {pipe.combinational_functions}",
        f"Dedicated Regs   : {pipe.dedicated_registers}",
        f"Total Registers  : {pipe.total_registers}",
        f"Total Pins       : {pipe.total_pins}",
        f"Memory Bits      : {pipe.memory_bits}",
        f"Fmax (pior Slow) : {_format_fmax(pipe)}",
        f"Setup Slack      : {pipe.setup_slack_ns or 'N/A'}",
        f"Auditoria Latches: {_format_latches(pipe.latch_audit)}",
    ]

    if pipe.fmax_entries:
        lines.append("-" * 78)
        lines.append("Corners Timing Analyzer (.sta.rpt):")
        for entry in pipe.fmax_entries:
            restr = f"{entry.restricted_fmax_mhz:.2f} MHz" if entry.restricted_fmax_mhz else "N/A"
            lines.append(f"  - {entry.model:<28s} | clk={entry.clock} | Fmax={entry.fmax_mhz:.2f} MHz (Restrita: {restr})")

    if pipe.latch_audit.hdl_latch_warnings:
        lines.append("-" * 78)
        lines.append("Avisos de latch HDL:")
        for w in pipe.latch_audit.hdl_latch_warnings:
            lines.append(f"  ! {w}")

    lines.append("-" * 78)
    lines.append("Comparativo Pipeline vs. Monociclo:")
    if mono.exists:
        lines.append(f"  Monociclo LEs  : {mono.logic_elements}")
        lines.append(f"  Monociclo Regs : {mono.dedicated_registers}")
        lines.append(f"  Monociclo Fmax : {_format_fmax(mono)}")
    else:
        lines.append(f"  Monociclo LEs  : {BASELINE_MONOCICLO_DOC['logic_elements']}")
        lines.append(f"  Monociclo Latch: {BASELINE_MONOCICLO_DOC['latches']}")

    pipe_le = _parse_leading_int(pipe.logic_elements)
    mono_le = _parse_leading_int(mono.logic_elements) if mono.exists else 17089
    if pipe_le is not None and mono_le:
        delta_pct = ((pipe_le - mono_le) / mono_le) * 100.0
        lines.append(f"  Delta LEs      : {pipe_le - mono_le:+d} ({delta_pct:+.1f}%)")

    if pipe.worst_slow_fmax_mhz and mono.worst_slow_fmax_mhz:
        ratio = pipe.worst_slow_fmax_mhz / mono.worst_slow_fmax_mhz
        lines.append(f"  Ganho Fmax     : {ratio:.2f}x")

    lines.append("=" * 78)
    return "\n".join(lines)


def render_markdown(pipe: QuartusMetrics, mono: QuartusMetrics) -> str:
    """Gera tabela Markdown comparativa pronta para anotações ou checklist."""
    mono_le = mono.logic_elements if mono.exists else BASELINE_MONOCICLO_DOC["logic_elements"]
    mono_regs = mono.dedicated_registers if mono.exists else "N/A"
    mono_fmax = _format_fmax(mono) if mono.exists else "N/A"
    mono_latch = _format_latches(mono.latch_audit) if mono.exists else BASELINE_MONOCICLO_DOC["latches"]

    return "\n".join(
        [
            "## Métricas Físicas Quartus Prime (Intel MAX 10 DE10-Lite)",
            "",
            f"* **Estágio do Pipeline:** {pipe.stage}",
            f"* **Status:** {pipe.status}",
            "",
            "| Métrica | Monociclo (Baseline) | Pipeline (5 Estágios) |",
            "| :--- | :--- | :--- |",
            f"| Logic Elements (LEs) | {mono_le} | {pipe.logic_elements} |",
            f"| Funções Combinacionais | {mono.combinational_functions if mono.exists else 'N/A'} | {pipe.combinational_functions} |",
            f"| Registradores Dedicados | {mono_regs} | {pipe.dedicated_registers} |",
            f"| Pinos / Memory Bits | {mono.total_pins if mono.exists else 'N/A'} | {pipe.total_pins} / {pipe.memory_bits} |",
            f"| Fmax (pior caso Slow) | {mono_fmax} | {_format_fmax(pipe)} |",
            f"| Latches Inferidos | {mono_latch} | {_format_latches(pipe.latch_audit)} |",
            "",
        ]
    )


def _tex_escape(value: str) -> str:
    """Escapa caracteres especiais de LaTeX em células extraídas dos relatórios."""
    return value.replace("%", r"\%").replace("&", r"\&").replace("_", r"\_")


def render_latex(pipe: QuartusMetrics, mono: QuartusMetrics) -> str:
    """Gera tabela IEEEtran (booktabs/tabular) com as métricas reais extraídas."""
    mono_le = _tex_escape(mono.logic_elements if mono.exists else "17.089")
    mono_regs = _tex_escape(mono.dedicated_registers if mono.exists else "--")
    mono_fmax = f"{mono.worst_slow_fmax_mhz:.2f}~MHz" if mono.worst_slow_fmax_mhz else "--"
    pipe_le = _tex_escape(pipe.logic_elements)
    pipe_regs = _tex_escape(pipe.dedicated_registers)
    pipe_fmax = f"{pipe.worst_slow_fmax_mhz:.2f}~MHz" if pipe.worst_slow_fmax_mhz else "--"
    pipe_latches = str(pipe.latch_audit.inferred_count) if pipe.latch_audit.inferred_count is not None else "0*"

    return "\n".join(
        [
            "% Tabela gerada automaticamente por scripts/quartus_metrics.py",
            "\\begin{table}[htbp]",
            "  \\centering",
            "  \\caption{Comparativo de Síntese na FPGA Intel MAX 10 (10M50DAF484C7G)}",
            "  \\label{tab:quartus_comparativo}",
            "  \\begin{tabular}{lcc}",
            "    \\hline",
            "    \\textbf{Métrica} & \\textbf{Monociclo} & \\textbf{Pipeline (5 Estágios)} \\\\",
            "    \\hline",
            f"    Total de Logic Elements (LEs) & {mono_le} & {pipe_le} \\\\",
            f"    Registradores Dedicados & {mono_regs} & {pipe_regs} \\\\",
            f"    Frequência Máxima ($F_{{\\max}}$ Slow) & {mono_fmax} & {pipe_fmax} \\\\",
            f"    Latches Espúrios Inferidos & 0 & {pipe_latches} \\\\",
            "    \\hline",
            "  \\end{tabular}",
            "\\end{table}",
            "",
        ]
    )


def main() -> int:
    """Ponto de entrada CLI."""
    parser = argparse.ArgumentParser(description="Extrai métricas de síntese e timing dos relatórios do Quartus.")
    parser.add_argument(
        "--project",
        choices=("both", "pipeline", "monociclo"),
        default="both",
        help="Qual projeto inspecionar (padrão: both).",
    )
    parser.add_argument("--markdown", type=Path, help="Salva resumo comparativo em Markdown no caminho indicado.")
    parser.add_argument("--latex", type=Path, help="Salva tabela IEEEtran em LaTeX no caminho indicado.")
    args = parser.parse_args()

    pipe = collect_project_metrics("Pipeline", "mips_pipeline", ROOT_DIR / "quartus" / "output_files")
    mono = collect_project_metrics("Monociclo", "mips_monociclo", ROOT_DIR / "monociclo" / "quartus" / "output_files")

    if args.project == "monociclo":
        print(render_terminal(mono, mono))
    else:
        print(render_terminal(pipe, mono))

    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(render_markdown(pipe, mono), encoding="utf-8")
        print(f"[OK] Resumo Markdown gravado em: {args.markdown}")

    if args.latex:
        args.latex.parent.mkdir(parents=True, exist_ok=True)
        args.latex.write_text(render_latex(pipe, mono), encoding="utf-8")
        print(f"[OK] Tabela LaTeX gravada em: {args.latex}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
