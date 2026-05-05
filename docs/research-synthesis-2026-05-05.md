# Research Synthesis — May 5, 2026

## How Multi-Tract Evaluation and Arxiv Monitoring Came from Research

This document captures how recent arxiv papers influenced the AHE harness architecture. It serves as the audit trail connecting research → design decisions → implemented changes.

## Papers Analyzed

| Paper | arXiv | Date | Core Contribution |
|-------|-------|------|-------------------|
| **AHE** | 2604.25850 | Apr 2026 | Agentic Harness Engineering — keep/discard/improve loop, component observability |
| **RecursiveMAS** | 2604.25917 | Apr 2026 | Latent-space recursion, gradient stability theorem, residual design, inner/outer loop |
| **Progress over Points** | 2512.11183 | Dec 2025 | Scientific delta metric; progress-oriented environment vs static pass thresholds |
| **Holistic Agent Leaderboard (HAL)** | 2510.11977 | Oct 2025 | 3D evaluation (models x scaffolds x benchmarks); reliability as first-class metric |
| **ResearchGym** | 2602.15112 | Feb 2026 | 1/15 agent success rate; 6 failure modes; capability-reliability gap as fundamental |
| **TRACE** | 2510.00415 | Sep 2025 | Self-evolving benchmarks — agents generate harder tasks from their own trajectories |
| **When AI Benchmarks Plateau** | 2602.16763 | Feb 2026 | 60 benchmarks analyzed; half saturated; expert-curation beats hiding test data |
| **Geometry of Benchmarks** | 2512.04276 | Dec 2025 | Kappa coefficient as a non-saturating differential metric |
| **AAI Kardashev Scale** | 2511.13411 | Nov 2025 | Ten-axis evaluation with closure properties (maintain + expand) |
| **Live-SWE-agent** | 2511.13646 | Nov 2025 | Runtime scaffold self-modification at 77.4% SWE-bench |
| **AIRS-Bench** | 2602.06855 | Feb 2026 | Full research lifecycle evaluation, no baseline code allowed |

## Key Findings That Drove Architecture Changes

### 1. The Benchmark Ceiling Problem

The AHE paper (2604.25850) ran 10 iterations on Terminal-Bench 2 (89 tasks, mostly Hard/Medium) and never plateaued because the task set had sufficient latent difficulty. Our harness uses a synthetic weighted score with 25 tests, and after fixing a glob pattern bug, the score reached 100/100 — **saturating the measurement signal**.

The "When AI Benchmarks Plateau" paper confirmed nearly half of 60 LLM benchmarks are saturated, and hiding test sets provides no protective effect. Our benchmark was following the same trajectory.

**RecursiveMAS** provided the theoretical framework: Theorem 4.1 proves that text-based recursion suffers from vanishing gradients — when you recycle the same evaluation dimensions, the signal decays to zero. The fix is to introduce **new latent dimensions** that restore gradient flow.

### 2. Multi-Tract Evaluation (Three Independent Signals)

Inspired by **HAL**'s 3D evaluation (models × scaffolds × benchmarks) and the **AAI Kardashev Scale**'s ten-axis approach with closure properties, we replaced the single 0-100 aggregate with three independent tracts:

| Tract | Purpose | Never Saturates Because... |
|-------|---------|---------------------------|
| **Correctness** | Regression detection (25 test suite) | Retained as residual — weight decays when stable at 100% |
| **Utility** | Forward progress (MCPs, skills, scripts) | Capability expands — always new MCPs, skills, integrations |
| **Reliability** | Hardening (MCP starts, backup freshness) | Tests get harder as thresholds tighten |

This mirrors **RecursiveMAS**'s residual design: the correctness tract is the residual (preserves prior learning), while utility and reliability are the additive layers that introduce new latent dimensions for the keep/discard signal.

### 3. Kappa: The Non-Saturating Metric

**Geometry of Benchmarks** independently proposed a *kappa coefficient* — the Lie derivative of capability along a generator-verifier-updater flow. This is a **differential quantity** (measures rate of improvement) rather than an absolute score, so it never saturates.

The **AAI Kardashev Scale** independently converged on kappa as well: capability growth per unit of agent-initiated resources.

Our implementation tracks kappa as the trailing trend across the last 5 aggregate benchmark runs:

```
kappa = (score[t] - score[t-4]) / 5
```

If kappa > 0, the system is improving. If kappa < 0, it's regressing. If kappa ≈ 0 with ceilings saturated, it's time to explore new evaluation dimensions.

### 4. Decision Matrix (Replace Single Keep/Discard)

The AHE paper's keep/improve/rollback logic uses a single pass@1 score. With multi-tract evaluation, we introduced a prioritized decision matrix:

```
Correctness < 95     → ROLLBACK (regression always wins)
Utility > 80 or
Reliability > 80     → KEEP (forward progress detected)
Kappa > 0            → KEEP (positive trailing trend)
Otherwise            → NO_CHANGE (need harder evaluation)
```

This is inspired by **ResearchGym**'s finding that point estimates are deeply misleading — the variance between runs matters as much as the peak. Our three independent signals surface which dimension is driving (or regressing) the system's overall trajectory.

### 5. Arxiv Research Discovery Phase

**TRACE**'s core insight — that static benchmarks inevitably saturate, and agents must generate harder tasks from their own trajectories — motivated adding a continuous research discovery phase to the pipeline.

The `Invoke-ResearchDiscovery` function queries 8 arxiv subject categories in parallel:

| Query | Category | Rationale |
|-------|----------|-----------|
| Agent evaluation benchmarks | cs.AI | Direct relevance to harness core mission |
| Self-improving/rewarding systems | cs.LG | Maps to keep/discard loop |
| Benchmark evaluation methodology | cs.LG | New evaluation techniques |
| Tool-use and function-calling | cs.AI | MCP discovery |
| Agent workflow orchestration | cs.AI | Pipeline architecture improvements |
| Code generation evaluation | cs.SE | Code agent testing |
| Test-time compute scaling | cs.LG | Efficiency optimization |
| Multi-agent system evaluation | cs.MA | Multi-agent patterns |

Findings are persisted to `.autoresearch/research/findings.json` and feed into the pipeline's existing prediction/verification system as pending improvements. A 24-hour guard prevents redundant queries, and dedup by arXiv ID prevents re-processing.

## How RecursiveMAS Specifically Impacted AHE

### Direct Transfers

| RecursiveMAS Concept | AHE Implementation | Status |
|----------------------|-------------------|--------|
| Residual design | Correctness tract preserved when adding Utility/Reliability | ✅ Implemented |
| Gradient stability (Thm 4.1) | New latent dimensions (Utility, Reliability) restore delta signal | ✅ Implemented |
| Multi-metric without aggregate | Tract scores reported separately, composite used only for decisions | ✅ Implemented |
| Inner/outer loop | Correctness (inner/stability) + Utility/Reliability (outer/progress) | ✅ Implemented |

### Identified for Future Work

| RecursiveMAS Concept | AHE Potential | Status |
|----------------------|---------------|--------|
| Latent-space recursion | Replace text-based agent communication with RecursiveLink modules | ⏳ Future |
| Gradient-based attribution | Replace LLM-based edit attribution (regression-blind at 11.1% recall) | ⏳ Future |
| RecursiveLink as trainable params | Add 0.31% overhead gradient-based optimization channel to harness | ⏳ Future |
| Formal complexity model | Replace fixed 1-hour timeout with per-task dynamic budgeting (Proposition 3.1) | ⏳ Future |

### Papers That Validated Each Design Decision

| Decision | Validating Paper | Quote or Insight |
|----------|-----------------|------------------|
| Add more tract dimensions | When AI Benchmarks Plateau | "Nearly half of 60 benchmarks saturated" |
| Track kappa | Geometry of Benchmarks | "Kappa is a differential quantity, never saturates" |
| Keep correctness as residual | RecursiveMAS | "Residual branch preserves original latent semantics" |
| Utility tract never saturates | Progress over Points | "Benchmark objective should be an open-ended goal, not a fixed test set" |
| Reliability as separate tract | HAL | "Higher reasoning effort reduced accuracy in majority of runs" |
| Decision matrix over single score | ResearchGym | "Point estimates are deeply misleading" |
| Arxiv research pipeline | TRACE | "Rapid ceiling-hitting trend — benchmarks must evolve with agents" |

## Running the Research Pipeline

```powershell
# Quick research scan (runs with pipeline cycle)
.\ahe-pipeline\pipeline.ps1

# Force research scan (bypasses 24h guard)
.\ahe-pipeline\pipeline.ps1 -Research

# Standalone research phase
.\ahe-pipeline\pipeline.ps1 -Phase research
```

Research findings land at `.autoresearch/research/findings.json` and feed into the manifest's prediction/verification system.
