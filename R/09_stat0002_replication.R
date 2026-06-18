# =============================================================================
# 09_stat0002_replication.R   (TODO: stat0002-replication)
#
# STAT0002 has only online (2020-21) and in-person (2022-23) -> a 2-way
# replication of the endpoint conditions. Both modules share these two
# conditions, so we also build a CROSS-MODULE comparison: does the
# online-vs-in-person pattern in the engagement->grade relationship replicate
# across STAT0002 and STAT0004?
# =============================================================================

source("R/00_setup.R")
source("R/features.R")
suppressMessages(library(emmeans))
suppressMessages(library(broom))

model_df <- readRDS(file.path(TAB_DIR, "model_df.rds"))

# ---- (1) STAT0002 weekly correlations (online vs in-person) ----------------
ind_map <- c(Frequency = "cum_freq", Immediacy = "cum_imm",
             Diversity = "cum_div", IDF = "cum_IDF")

s2 <- model_df |> filter(module == "STAT0002")

corr_s2 <- purrr::imap_dfr(ind_map, function(col, nm) {
  s2 |> group_by(condition, week) |>
    summarise(spearman_ci(.data[[col]], final_grade), .groups = "drop") |>
    mutate(indicator = nm)
}) |> mutate(indicator = factor(indicator, levels = names(ind_map)))

save_tab(corr_s2, "09_stat0002_weekly_corr.csv")

# ---- (2) STAT0002 interaction model: slope differs online vs in-person? ----
s2w <- s2 |> mutate(condition = droplevels(condition))
fit2 <- function(wk) lm(final_grade ~ (z_cum_freq + z_cum_imm + z_cum_div) * condition,
                        data = filter(s2w, week == wk))

int_p_s2 <- purrr::map_dfr(sort(unique(s2w$week)), function(wk) {
  d <- filter(s2w, week == wk)
  full <- lm(final_grade ~ (z_cum_freq + z_cum_imm + z_cum_div) * condition, d)
  main <- lm(final_grade ~ z_cum_freq + z_cum_imm + z_cum_div + condition, d)
  a <- anova(main, full)
  tibble(week = wk, F = round(a$F[2], 2), p_interaction = signif(a$`Pr(>F)`[2], 3))
})
save_tab(int_p_s2, "09_stat0002_interaction_pvalues.csv")

cat("\n========== STAT0002: engagement x condition interaction by week ==========\n")
print(as.data.frame(int_p_s2), row.names = FALSE)

# ---- (3) CROSS-MODULE replication: online vs in-person, both modules -------
# Endpoint (week 11) correlation per module x condition x indicator.
endpoint <- purrr::imap_dfr(ind_map, function(col, nm) {
  model_df |>
    filter(condition %in% c("online", "in_person"), week == 11) |>
    group_by(module, condition) |>
    summarise(spearman_ci(.data[[col]], final_grade), .groups = "drop") |>
    mutate(indicator = nm)
}) |>
  mutate(indicator = factor(indicator, levels = names(ind_map)),
         condition = droplevels(factor(condition, levels = CONDITION_LEVELS)))

save_tab(endpoint, "09_cross_module_endpoint_corr.csv")

p_repl <- endpoint |>
  ggplot(aes(indicator, rho, fill = condition)) +
  geom_col(position = position_dodge(0.8), width = 0.7) +
  geom_errorbar(aes(ymin = lo, ymax = hi), position = position_dodge(0.8),
                width = 0.2) +
  facet_wrap(~ module) +
  scale_fill_manual(values = CONDITION_COLOURS, drop = FALSE) +
  labs(title = "Cross-module replication: end-of-term engagement-grade correlation",
       subtitle = "Online (2020-21) vs in-person (2022-23), week 11; bars = approx. 95% CI",
       x = NULL, y = expression(Spearman~rho), fill = "Delivery condition") +
  theme_bw(base_size = 11) + theme(legend.position = "bottom")

save_fig(p_repl, "09_cross_module_replication.png", width = 9, height = 5)

# Weekly online-vs-in-person curves for BOTH modules (IDF + Diversity focus)
cross_weekly <- purrr::imap_dfr(ind_map, function(col, nm) {
  model_df |> filter(condition %in% c("online", "in_person")) |>
    group_by(module, condition, week) |>
    summarise(spearman_ci(.data[[col]], final_grade), .groups = "drop") |>
    mutate(indicator = nm)
}) |>
  mutate(indicator = factor(indicator, levels = names(ind_map)),
         condition = droplevels(factor(condition, levels = CONDITION_LEVELS)))

p_cross <- cross_weekly |>
  ggplot(aes(week, rho, colour = condition)) +
  geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.3) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.1) +
  facet_grid(indicator ~ module) +
  scale_colour_manual(values = CONDITION_COLOURS, drop = FALSE) +
  scale_x_continuous(breaks = seq(1, 11, 2)) +
  labs(title = "Online vs in-person engagement-grade correlation, both modules",
       x = "University week", y = expression(Spearman~rho),
       colour = "Delivery condition") +
  theme_bw(base_size = 11) + theme(legend.position = "bottom")

save_fig(p_cross, "09_cross_module_weekly.png", width = 9, height = 8)

cat("\n========== CROSS-MODULE ENDPOINT (week 11) CORRELATIONS ==========\n")
print(as.data.frame(
  endpoint |> select(module, condition, indicator, rho) |>
    mutate(rho = round(rho, 2)) |>
    pivot_wider(names_from = indicator, values_from = rho)
), row.names = FALSE)

cat("\nSaved figures: 09_cross_module_replication.png, 09_cross_module_weekly.png\n")
cat("Saved tables: 09_stat0002_weekly_corr.csv, 09_stat0002_interaction_pvalues.csv,",
    "09_cross_module_endpoint_corr.csv\n")
