# =============================================================================
# 01_verify_metric.R   (TODO: verify-metric-semantics)
#
# Question: are the freq/imm/div *_contrib values in `sem` CUMULATIVE
# (computed from all activity up to and including week t, as in the paper) or
# PER-WEEK increments (only that week's activity)?
#
# Method: reconstruct raw Frequency and Diversity per (student, chapter, week)
# directly from the event log `dat`, under BOTH interpretations, then check
# which one reproduces the ordering of `sem`'s scaled contributions.
#
# Because min-max scaling is a monotone (affine) transform within each
# (chapter, week) group, Spearman(raw, contrib) within each group is invariant
# to the exact scaling population. The interpretation whose reconstruction
# yields Spearman ~ 1 is the correct one.
# =============================================================================

source("R/00_setup.R")

co  <- load_cohort("STAT0004", "2122")   # hybrid cohort used as the probe
dat <- co$dat
sem <- co$sem

# ---- 1. Chapter-labelled study sessions from the log ------------------------
# session_chap holds the chapter a study session was attributed to ("NA" when
# the session was general/overview material and excluded from the metric).
sess <- dat |>
  mutate(chap = num_na(session_chap), wk = num_na(univ_week)) |>
  filter(!is.na(chap), !is.na(wk), chap >= 1) |>
  group_by(User, chap, Session_ID) |>
  summarise(sess_week = min(wk), .groups = "drop")   # week the session belongs to

# Diversity raw input: distinct activity types accessed within chapter sessions.
acts <- dat |>
  mutate(chap = num_na(session_chap), wk = num_na(univ_week)) |>
  filter(!is.na(chap), !is.na(wk), chap >= 1, !is.na(resource_type)) |>
  distinct(User, chap, resource_type, wk)

weeks <- sort(unique(num_na(sem$week)))
users <- sort(unique(sem$User))

# ---- 2. Reconstruct raw indicators under both interpretations ---------------
# Cumulative: count up to and including week t.  Per-week: count in week t only.
freq_cum <- map_dfr(weeks, \(t) sess |> filter(sess_week <= t) |>
                      count(User, chap, name = "raw") |> mutate(t = t, kind = "cumulative"))
freq_pw  <- map_dfr(weeks, \(t) sess |> filter(sess_week == t) |>
                      count(User, chap, name = "raw") |> mutate(t = t, kind = "per_week"))

div_cum  <- map_dfr(weeks, \(t) acts |> filter(wk <= t) |>
                      distinct(User, chap, resource_type) |>
                      count(User, chap, name = "raw") |> mutate(t = t, kind = "cumulative"))
div_pw   <- map_dfr(weeks, \(t) acts |> filter(wk == t) |>
                      distinct(User, chap, resource_type) |>
                      count(User, chap, name = "raw") |> mutate(t = t, kind = "per_week"))

# ---- 3. sem contributions in long form -------------------------------------
sem_long <- sem |>
  mutate(week = num_na(week)) |>
  pivot_longer(matches("_contrib\\.\\.c\\."), names_to = "key", values_to = "contrib") |>
  mutate(contrib   = num_na(contrib),
         dimension = str_extract(key, "^(freq|imm|div)"),
         chap      = as.integer(str_extract(key, "\\d+$"))) |>
  select(User, t = week, chap, dimension, contrib)

freq_sem <- sem_long |> filter(dimension == "freq", !is.na(contrib))
div_sem  <- sem_long |> filter(dimension == "div",  !is.na(contrib))

# ---- 4. Compare: Spearman(raw, contrib) within each (chapter, week) ---------
compare <- function(raw_tbl, sem_tbl) {
  # Fill students with no activity as raw = 0 within each released (chap, t).
  released <- sem_tbl |> distinct(chap, t)
  full <- released |>
    left_join(tibble(User = users), by = character()) |>
    left_join(raw_tbl |> select(User, chap, t, raw), by = c("chap", "t", "User")) |>
    mutate(raw = tidyr::replace_na(raw, 0)) |>
    inner_join(sem_tbl |> select(User, chap, t, contrib), by = c("User", "chap", "t"))

  full |>
    group_by(chap, t) |>
    filter(n() >= 5, sd(raw) > 0, sd(contrib) > 0) |>
    summarise(rho = cor(raw, contrib, method = "spearman"), n = n(), .groups = "drop") |>
    summarise(mean_rho = weighted.mean(rho, n),
              median_rho = median(rho),
              min_rho = min(rho), groups = n())
}

res <- bind_rows(
  compare(freq_cum, freq_sem) |> mutate(indicator = "frequency", interpretation = "cumulative"),
  compare(freq_pw,  freq_sem) |> mutate(indicator = "frequency", interpretation = "per_week"),
  compare(div_cum,  div_sem)  |> mutate(indicator = "diversity", interpretation = "cumulative"),
  compare(div_pw,   div_sem)  |> mutate(indicator = "diversity", interpretation = "per_week")
) |>
  select(indicator, interpretation, mean_rho, median_rho, min_rho, groups)

cat("\n================ METRIC SEMANTICS VERIFICATION (STAT0004 2021-22) =========\n")
print(as.data.frame(res), digits = 3)

verdict <- res |>
  group_by(indicator) |>
  slice_max(mean_rho, n = 1) |>
  ungroup()

cat("\nBest-matching interpretation per indicator:\n")
print(as.data.frame(verdict[, c("indicator", "interpretation", "mean_rho")]), digits = 3)

overall <- names(sort(table(verdict$interpretation), decreasing = TRUE))[1]
cat(sprintf("\nVERDICT: the sem *_contrib values are best described as '%s'.\n", overall))

save_tab(res, "01_metric_semantics_check.csv")
writeLines(
  c(sprintf("Verified on STAT0004 2021-22 (hybrid). Verdict: %s.", overall),
    "Frequency reconstructed from distinct chapter-labelled Session_IDs;",
    "Diversity from distinct resource_type within chapter sessions.",
    "Spearman computed within each (chapter, week) group vs sem contributions."),
  file.path(TAB_DIR, "01_metric_semantics_verdict.txt")
)
cat("\nSaved: outputs/tables/01_metric_semantics_check.csv (+ verdict .txt)\n")
