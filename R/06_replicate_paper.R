# =============================================================================
# 06_replicate_paper.R   (TODO: replicate-paper)
#
# Reproduce the paper's two core validity analyses, per cohort:
#   (A) Weekly Spearman correlation between engagement and final grade, for
#       each indicator (Frequency, Immediacy, Diversity, IDF total), tracked
#       across weeks 1-11. We use the CUMULATIVE engagement (activity up to and
#       including week t), matching the paper's real-time framing.
#   (B) Final-grade distributions by engagement quintile at weeks 3 and 6.
# =============================================================================

source("R/00_setup.R")
source("R/features.R")

model_df <- readRDS(file.path(TAB_DIR, "model_df.rds"))
cohort_meta <- COHORTS |> select(cohort_id, condition, year_label, module)

# ---- (A) Weekly Spearman correlations --------------------------------------
ind_map <- c(Frequency = "cum_freq", Immediacy = "cum_imm",
             Diversity = "cum_div", IDF = "cum_IDF")

# spearman_ci() lives in features.R (Fisher-z approximate 95% CI).
corr_tbl <- purrr::imap_dfr(ind_map, function(col, ind_name) {
  model_df |>
    group_by(cohort_id, condition, module, week) |>
    summarise(spearman_ci(.data[[col]], final_grade), .groups = "drop") |>
    mutate(indicator = ind_name)
}) |>
  mutate(indicator = factor(indicator,
                            levels = c("Frequency", "Immediacy", "Diversity", "IDF")))

save_tab(corr_tbl, "06_weekly_grade_corr.csv")

p_corr <- corr_tbl |>
  ggplot(aes(week, rho, colour = condition, fill = condition)) +
  geom_hline(yintercept = 0, linewidth = 0.3, colour = "grey60") +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.3) +
  facet_grid(indicator ~ module) +
  scale_colour_manual(values = CONDITION_COLOURS, drop = FALSE) +
  scale_fill_manual(values = CONDITION_COLOURS, drop = FALSE) +
  scale_x_continuous(breaks = seq(1, 11, 2)) +
  labs(title = "Weekly Spearman correlation of cumulative engagement with final grade",
       subtitle = "By indicator (rows) and module (columns); ribbons = approx. 95% CI",
       x = "University week", y = expression(Spearman~rho),
       colour = "Delivery condition", fill = "Delivery condition") +
  theme_bw(base_size = 11) + theme(legend.position = "bottom")

save_fig(p_corr, "06_weekly_corr_cumulative.png", width = 9, height = 8)

# ---- (B) Final-grade distributions by engagement quintile ------------------
q_lab <- c("Q1 Very Low", "Q2 Low", "Q3 Moderate", "Q4 High", "Q5 Very High")

quint <- model_df |>
  filter(week %in% c(3, 6)) |>
  group_by(cohort_id, condition, week) |>
  mutate(quintile = factor(q_lab[ntile(cum_IDF, 5)], levels = q_lab)) |>
  ungroup() |>
  left_join(cohort_meta |> select(cohort_id, year_label), by = "cohort_id") |>
  mutate(panel = paste0(module, "\n", year_label, " (", condition, ")"),
         wk = paste0("Week ", week))

p_box <- quint |>
  ggplot(aes(quintile, final_grade, fill = condition)) +
  geom_hline(yintercept = 50, linetype = "dashed", colour = "grey30") +
  geom_hline(yintercept = 40, linetype = "dotted", colour = "firebrick") +
  geom_boxplot(outlier.size = 0.5, alpha = 0.8) +
  facet_grid(wk ~ panel) +
  scale_fill_manual(values = CONDITION_COLOURS, drop = FALSE) +
  labs(title = "Final grade by cumulative-engagement quintile (weeks 3 and 6)",
       subtitle = "Dashed = 50% (low performance); dotted = 40% (fail)",
       x = "Engagement quintile (cumulative IDF)", y = "Final grade (%)",
       fill = "Delivery condition") +
  theme_bw(base_size = 10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "bottom")

save_fig(p_box, "06_quintile_boxplots_w3_w6.png", width = 12, height = 6)

# Quintile median-grade table (useful in the report)
quint_summary <- quint |>
  group_by(cohort_id, condition, week, quintile) |>
  summarise(n = n(), median_grade = round(median(final_grade), 1),
            pct_low = round(100 * mean(low), 1), .groups = "drop")
save_tab(quint_summary, "06_quintile_grade_summary.csv")

cat("\n==================== PAPER REPLICATION ====================\n")
cat("Peak weekly rho per cohort x indicator:\n")
print(as.data.frame(
  corr_tbl |> group_by(module, condition, indicator) |>
    summarise(peak_rho = round(max(rho, na.rm = TRUE), 2), .groups = "drop") |>
    tidyr::pivot_wider(names_from = indicator, values_from = peak_rho)
), row.names = FALSE)

cat("\nSaved figures: 06_weekly_corr_cumulative.png, 06_quintile_boxplots_w3_w6.png\n")
cat("Saved tables: 06_weekly_grade_corr.csv, 06_quintile_grade_summary.csv\n")
