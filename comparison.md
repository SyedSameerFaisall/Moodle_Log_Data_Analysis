# Professor's Research vs My Internship Plan

**For:** Meeting with Professor Johnston  
**Professor's paper:** [Johnston et al. (2025)](https://arxiv.org/abs/2507.12162) — develops and first-validates the chapter-aligned IDF engagement metric  
**My role:** Apply that **same metric** to new STAT0002/STAT0004 cohorts; replicate core checks; then extend with deeper analysis over the **next 5 weeks**

---

## 1. The difference in one table

| | Professor Johnston et al. | My internship |
|---|---------------------------|---------------|
| **Question** | Can we build a real-time chapter-aligned engagement metric that works? | Does that **existing** metric still work on **new** cohorts, and what can we learn by extending the analysis? |
| **Metric** | **Creates** IDF = Frequency + Immediacy + Diversity (from Chong & Wong 2019) | **Uses** the professor's definition unchanged — I do not invent a new score |
| **Data** | ~3 statistics modules, 2 academic years (original validation) | STAT0002 + STAT0004, five cohorts (2020–21 to 2022–23) |
| **Main output** | Academic paper | R analysis pipeline + written report |

---

## 2. How the projects connect (ASCII — renders everywhere)

```
Chong & Wong (2019)          Johnston et al. (2025)              My internship
─────────────────            ──────────────────────              ─────────────
Course-wide score     -->    Chapter-aligned weekly IDF    -->   Same IDF on NEW cohorts
(retrospective)              (real-time, cumulative)            │
                             First validation                   ├─ Phase 1: replicate paper  [STARTED]
                                                                └─ Phase 2: extend + report  [NEXT 5 WEEKS]
```

**Shared metric (identical in both studies):**

```
Moodle logs  -->  per chapter, per week:  F + I + D  -->  sum across chapters  -->  cumulate over weeks
```

---

## 3. Full project plan (entire internship)

Everything below is the **full scope**. Phase 1 is what I have been coding so far; Phase 2 is what I will complete in the **remaining ~5 weeks**.

### Phase 1 — Foundation & replication of Johnston et al. `[IN PROGRESS / LARGELY DONE]`

| Step | What it does | Status |
|------|----------------|--------|
| 1. Verify metric | Confirm data match additive F+I+D (per-week contributions) | Done |
| 2. Load & inventory | Five cohorts, N=1,291, grade exclusions | Done |
| 3. Build features | Weekly and cumulative IDF, standardise within cohort/week | Done |
| 4. Weekly correlations | Spearman *r* between cumulative engagement and final grade, weeks 1–11 | Done |
| 5. Quintile plots | Grade distributions by engagement quintile (weeks 3 & 6) | Done |
| 6. Early-warning metrics | Bottom-quintile recall, precision, AUC for grade &lt; 50 | Done |
| 7. Cross-module check | Compare STAT0002 vs STAT0004; delivery-period patterns (descriptive) | Done |

**Phase 1 answers:** “Does the professor's metric behave on our new data the same way it did in the paper?”

---

### Phase 2 — Extensions & report `[PLANNED — NEXT 5 WEEKS]`

| Step | What it will do | Why |
|------|-----------------|-----|
| 8. Pooled meta-analysis | Combine all five cohorts; pooled *r*, mixed-effects slope, *I²* | One summary “does it travel?” answer |
| 9. Quantile regression | Is engagement more important for weaker students? | Early-support focus |
| 10. Component importance (LMG) | Which of F / I / D matters most under collinearity? | Diagnostic interpretation |
| 11. Assessment alignment | Exam vs coursework vs peer/group marks | What Moodle actually tracks |
| 12. Stabilisation timing | When does the weekly correlation stop changing? | When is the signal usable? |
| 13. Temporal features | Regularity / timing beyond F+I+D | How students engage over time |
| 14. Trajectory classes | Latent groups of weekly engagement shapes | Sustained patterns vs one snapshot |
| 15. Robustness | Programme adjustment, multiple-testing correction, thresholds | Trust the headline results |
| 16. Write-up | Report: validation + interpretation + practical guidance | Deliverable for internship |

**Phase 2 answers:** “What kind of engagement matters, how should staff use the metric, and what are the limits?”

---

## 4. Timeline view

```
Past / current                          Next 5 weeks
──────────────────────────────────────────────────────────────────
[Phase 1]  Data ──► Metric check ──► Replicate paper analyses
                                              │
                                              ▼
[Phase 2]  Pool cohorts ──► Extend methods ──► Draft report ──► Final report
```

---

## 5. My data (five cohorts)

| Module | Year | Period | N |
|--------|------|--------|---|
| STAT0002 | 2020–21 | Online | 342 |
| STAT0002 | 2022–23 | In-person | 268 |
| STAT0004 | 2020–21 | Online | 312 |
| STAT0004 | 2021–22 | Hybrid | 172 |
| STAT0004 | 2022–23 | In-person | 197 |
| **Total** | | | **1,291** |

**Design note:** Online / hybrid / in-person line up with academic year — so delivery comparisons will stay **descriptive**, not causal.

---

## 6. Initial results (Phase 1 only — to show coding has started)

These come from replicating the professor's core analyses on the new cohorts. They are **early** results, not the final internship conclusions.

### 6.1 Metric verification

- Confirmed: contributions are **per-week increments**; cumulative IDF = sum of weekly F+I+D across chapters.
- Reconstruction check passed on supplied `sem` data (additive, not multiplicative).

### 6.2 End-of-term engagement–grade correlation (week 11, cumulative IDF)

Same style of analysis as Johnston et al. — positive in every cohort:

| Cohort | Spearman *r* | 95% CI (approx.) |
|--------|-------------|------------------|
| STAT0002 online | 0.28 | 0.17 – 0.38 |
| STAT0002 in-person | **0.41** | 0.30 – 0.51 |
| STAT0004 online | 0.30 | 0.19 – 0.40 |
| STAT0004 hybrid | 0.23 | 0.08 – 0.38 |
| STAT0004 in-person | 0.19 | 0.05 – 0.33 |

**Early reading:** Associations are positive everywhere (good sign for replication). STAT0002 looks stronger than STAT0004 — worth investigating in Phase 2 (assessment structure, module year).

### 6.3 Signal appears early in the term

Example: STAT0002 in-person cumulative IDF vs grade

| Week | Spearman *r* |
|------|-------------|
| 3 | 0.35 |
| 6 | 0.36 |
| 11 | 0.41 |

Similar pattern to the paper: correlation is visible from the first few weeks and builds in some cohorts.

### 6.4 Early-warning preview (STAT0002, bottom quintile, week 6)

| Cohort | Recall (grade &lt; 50) | Precision | AUC |
|--------|-------------------------|-----------|-----|
| STAT0002 online | ~38% | ~19% | ~0.71 |
| STAT0002 in-person | ~32% | ~17% | ~0.73 |

**Early reading:** Can flag some at-risk students, but precision is modest (many flagged students still pass) — Phase 2 will explore this properly with quantile regression and practical guidance.

### 6.5 What Phase 1 does **not** yet claim

- No pooled estimate across all cohorts yet (Phase 2 meta-analysis)
- No final answer on F vs I vs D importance (Phase 2 LMG)
- No trajectory or timing extensions yet
- No written report conclusions yet

---

## 7. Three questions the full project will answer

```
┌─────────────────────────────────────────────────────────────────┐
│  1. VALIDATION     Does the metric travel to new STAT0002/0004  │
│                    cohorts?                          [Phase 1+2]  │
├─────────────────────────────────────────────────────────────────┤
│  2. INTERPRETATION What KIND of engagement matters beyond       │
│                    raw volume?                       [Phase 2]  │
├─────────────────────────────────────────────────────────────────┤
│  3. PRACTICE       How should staff use it safely given         │
│                    modest precision?                 [Phase 2]  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Short script for the meeting (~45 seconds)

> “Your paper developed the chapter-aligned IDF metric and validated it on structured statistics modules. My project uses that exact metric on five new STAT0002 and STAT0004 cohorts from 2020–21 through 2022–23.
>
> **So far** I have built the data pipeline and replicated your core analyses — weekly correlations, quintiles, and early-warning metrics. Initial results look encouraging: every cohort shows a positive association between cumulative engagement and final grade, with correlations from about 0.19 to 0.41 at week 11.
>
> **Over the next five weeks** I plan to pool evidence across cohorts, test whether the link is stronger for weaker students, decompose Frequency vs Immediacy vs Diversity, add trajectory and timing analyses, run robustness checks, and write this up as a report focused on validation, interpretation, and safe practical use — not building a new metric.”

---

## 9. Where the code lives

| Phase | Scripts | Outputs |
|-------|---------|---------|
| Phase 1 | `R/01_verify_metric.R` … `R/09_stat0002_replication.R` | `outputs/tables/03_data_inventory.csv`, `06_weekly_grade_corr.csv`, `08_early_warning_metrics.csv`, … |
| Phase 2 | `R/11_outcome_models.R` … `R/19_synthesis.R` | Planned / in progress |
| Full pipeline | `R/run_all.R` | `outputs/figures/`, `outputs/tables/` |
| Report | `report/report.tex` | Draft in Phase 2 |

---

## 10. Summary

| | Professor | Me (now) | Me (after 5 weeks) |
|---|-----------|----------|---------------------|
| **Built metric?** | Yes | No — use theirs | No |
| **New cohorts?** | Original set | STAT0002/0004, N=1,291 | Same |
| **Replication done?** | N/A | **Yes — initial results** | Complete + pooled |
| **Extensions done?** | N/A | Planned | **Target** |
| **Report** | Paper published | Not final | **Target** |

*This document describes the internship plan and early progress. It intentionally shows Phase 1 results only; Phase 2 findings will go in the final report.*
