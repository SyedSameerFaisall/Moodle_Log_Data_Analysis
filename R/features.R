# =============================================================================
# features.R
# Reusable feature-engineering functions for the engagement analysis.
# Sourced by the numbered analysis scripts (after 00_setup.R).
#
# IMPORTANT semantics (verified in 01_verify_metric.R):
#   The sem *_contrib values are PER-WEEK increments (not cumulative).
#   Therefore:
#     - weekly engagement  = the per-week values (summed over released chapters)
#     - cumulative engagement = cumsum of the weekly values over weeks 1..t
#   Immediacy is the one indicator where summing/cumulating is conceptually
#   weaker (it reflects promptness of first access); we keep it symmetric for a
#   consistent pipeline but flag this in the limitations.
# =============================================================================

# ---- tidy_sem: wide chapter columns -> tidy long --------------------------
# Output rows: one per (User, cohort, week, dimension, chapter).
tidy_sem <- function(sem) {
  sem |>
    dplyr::mutate(week = num_na(week)) |>
    tidyr::pivot_longer(dplyr::matches("_contrib\\.\\.c\\."),
                        names_to = "key", values_to = "value") |>
    dplyr::mutate(
      value     = num_na(value),
      dimension = stringr::str_extract(key, "^(freq|imm|div)"),
      chapter   = as.integer(stringr::str_extract(key, "\\d+$"))
    ) |>
    dplyr::select(cohort_id, module, condition, User, week, dimension, chapter, value)
}

# ---- weekly_engagement: per-week per-dimension summaries -------------------
# sum_*  = total contribution across released chapters that week (scales with
#          number of released chapters -> use for cumulative metric)
# mean_* = average contribution per released chapter that week (comparable
#          across weeks regardless of how many chapters are live)
# n_active_chap = number of chapters with non-zero activity that week
weekly_engagement <- function(sem_long) {
  per_dim <- sem_long |>
    dplyr::group_by(cohort_id, module, condition, User, week, dimension) |>
    dplyr::summarise(
      sum_val      = sum(value, na.rm = TRUE),
      mean_val     = mean(value[!is.na(value)]),
      n_released   = sum(!is.na(value)),
      n_active     = sum(value > 0, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(mean_val = ifelse(is.nan(mean_val), 0, mean_val))

  wide <- per_dim |>
    tidyr::pivot_wider(
      id_cols = c(cohort_id, module, condition, User, week),
      names_from = dimension,
      values_from = c(sum_val, mean_val, n_active)
    )

  # number of chapters released by this week (same across dimensions)
  released <- per_dim |>
    dplyr::filter(dimension == "freq") |>
    dplyr::select(cohort_id, User, week, n_released)

  out <- wide |>
    dplyr::left_join(released, by = c("cohort_id", "User", "week")) |>
    dplyr::mutate(
      freq_week = sum_val_freq,
      imm_week  = sum_val_imm,
      div_week  = sum_val_div,
      IDF_week  = sum_val_freq + sum_val_imm + sum_val_div
    )

  # ---- Complete the (student x week) grid -----------------------------------
  # sem is ragged: a missing (User, week) means zero engagement that week.
  # Fill those weeks with 0 so week-level analyses include silent students
  # (avoids survivorship bias) and cumulative totals carry forward correctly.
  wk_range <- range(out$week, na.rm = TRUE)
  fill0 <- c("sum_val_freq", "sum_val_imm", "sum_val_div",
             "mean_val_freq", "mean_val_imm", "mean_val_div",
             "n_active_freq", "n_active_imm", "n_active_div",
             "freq_week", "imm_week", "div_week", "IDF_week")
  fill0 <- intersect(fill0, names(out))

  out |>
    tidyr::complete(
      tidyr::nesting(cohort_id, module, condition, User),
      week = seq(wk_range[1], wk_range[2]),
      fill = stats::setNames(as.list(rep(0, length(fill0))), fill0)
    ) |>
    dplyr::group_by(cohort_id, User) |>
    dplyr::arrange(week, .by_group = TRUE) |>
    # chapters released by week t is non-decreasing -> running max fills gaps
    dplyr::mutate(n_released = cummax(tidyr::replace_na(n_released, 0L))) |>
    dplyr::ungroup() |>
    dplyr::arrange(cohort_id, User, week)
}

# ---- add_cumulative: running totals over weeks ----------------------------
add_cumulative <- function(weekly) {
  weekly |>
    dplyr::group_by(cohort_id, User) |>
    dplyr::arrange(week, .by_group = TRUE) |>
    dplyr::mutate(
      cum_freq = cumsum(freq_week),
      cum_imm  = cumsum(imm_week),
      cum_div  = cumsum(div_week),
      cum_IDF  = cumsum(IDF_week)
    ) |>
    dplyr::ungroup()
}

# ---- phase_features: early / mid / late aggregates per student ------------
# Default thirds of an 11-week term: early 1-4, mid 5-8 (week 6 reading week),
# late 9-11. Returns one row per (cohort, User) with mean weekly IDF/F/I/D
# within each phase.
phase_features <- function(weekly,
                           early = 1:4, mid = 5:8, late = 9:11) {
  lab <- function(w) dplyr::case_when(w %in% early ~ "early",
                                      w %in% mid   ~ "mid",
                                      w %in% late  ~ "late",
                                      TRUE ~ NA_character_)
  weekly |>
    dplyr::mutate(phase = lab(week)) |>
    dplyr::filter(!is.na(phase)) |>
    dplyr::group_by(cohort_id, module, condition, User, phase) |>
    dplyr::summarise(
      IDF  = mean(IDF_week),
      freq = mean(freq_week),
      imm  = mean(imm_week),
      div  = mean(div_week),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(names_from = phase,
                       values_from = c(IDF, freq, imm, div))
}

# ---- student_profile: one row per student of trajectory descriptors -------
# level (mean), consistency (1 - normalised SD), trend (OLS slope over weeks),
# active weeks, and the Frequency:Immediacy:Diversity balance.
student_profile <- function(weekly) {
  slope <- function(y, x) {
    if (length(unique(x)) < 2 || sd(y) == 0) return(0)
    unname(coef(lm(y ~ x))[2])
  }
  weekly |>
    dplyr::group_by(cohort_id, module, condition, User) |>
    dplyr::arrange(week, .by_group = TRUE) |>
    dplyr::summarise(
      level_IDF   = mean(IDF_week),
      sd_IDF      = sd(IDF_week),
      trend_IDF   = slope(IDF_week, week),
      active_wks  = sum(IDF_week > 0),
      total_freq  = sum(freq_week),
      total_imm   = sum(imm_week),
      total_div   = sum(div_week),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      consistency = ifelse(level_IDF > 0, 1 - (sd_IDF / (level_IDF + 1e-9)), 0),
      tot         = total_freq + total_imm + total_div + 1e-9,
      bal_freq    = total_freq / tot,
      bal_imm     = total_imm  / tot,
      bal_div     = total_div  / tot
    )
}

# ---- attach_grades: join final_grade and exclusion ------------------------
attach_grades <- function(weekly_or_profile, grades) {
  g <- grades |>
    dplyr::mutate(final_grade = num_na(final_grade)) |>
    dplyr::select(cohort_id, User, final_grade) |>
    dplyr::filter(!is.na(final_grade), final_grade > 0)
  weekly_or_profile |>
    dplyr::inner_join(g, by = c("cohort_id", "User"))
}

# ---- spearman_ci: Spearman rho with Fisher-z approximate 95% CI -----------
spearman_ci <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]; y <- y[ok]; n <- length(x)
  if (n < 6 || stats::sd(x) == 0 || stats::sd(y) == 0)
    return(tibble::tibble(rho = NA_real_, lo = NA_real_, hi = NA_real_, n = n))
  r  <- stats::cor(x, y, method = "spearman")
  z  <- atanh(pmin(pmax(r, -0.999), 0.999))
  se <- 1.06 / sqrt(n - 3)
  tibble::tibble(rho = r, lo = tanh(z - 1.96 * se), hi = tanh(z + 1.96 * se), n = n)
}

# ---- standardise_within: z-score engagement within cohort x week ----------
# Makes regression coefficients comparable across cohorts/conditions.
standardise_within <- function(model_df, cols) {
  model_df |>
    dplyr::group_by(cohort_id, week) |>
    dplyr::mutate(dplyr::across(dplyr::all_of(cols),
                                \(x) as.numeric(scale(x)),
                                .names = "z_{.col}")) |>
    dplyr::ungroup()
}
