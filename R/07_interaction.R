# =============================================================================
# 07_interaction.R   (TODO: interaction-model)
#
# Core research question: does the engagement -> grade slope differ across
# delivery conditions? We use STAT0004 (the only module with all three
# conditions) and model, at each week t:
#
#   final_grade ~ (z_cum_freq + z_cum_imm + z_cum_div) * condition
#
# - Week-5 model reported in detail (coefficients + interaction tests +
#   per-condition indicator slopes with pairwise contrasts via emmeans).
# - Then the per-condition slopes are extracted for every week 1-11 and the
#   slope trajectories plotted.
#
# Interpretation note: condition = year = cohort are confounded. Slope
# differences are described as differences BETWEEN delivery conditions, not
# causal effects of delivery mode.
# =============================================================================

source("R/00_setup.R")
suppressMessages(library(emmeans))
suppressMessages(library(broom))

model_df <- readRDS(file.path(TAB_DIR, "model_df.rds"))

s4 <- model_df |>
  filter(module == "STAT0004") |>
  mutate(condition = droplevels(factor(as.character(condition),
                                       levels = CONDITION_LEVELS)))

indicators <- c(Frequency = "z_cum_freq", Immediacy = "z_cum_imm",
                Diversity = "z_cum_div")

fit_week <- function(df, wk) {
  d <- filter(df, week == wk)
  lm(final_grade ~ (z_cum_freq + z_cum_imm + z_cum_div) * condition, data = d)
}

# ---- Week 5: detailed report -----------------------------------------------
m5 <- fit_week(s4, 5)
m5_main <- lm(final_grade ~ z_cum_freq + z_cum_imm + z_cum_div + condition,
              data = filter(s4, week == 5))

cat("\n================ STAT0004 WEEK-5 INTERACTION MODEL ================\n")
cat("\nCoefficients:\n")
print(as.data.frame(broom::tidy(m5)), digits = 3, row.names = FALSE)

cat("\nOverall test of ALL engagement x condition interactions",
    "(main-effects vs interaction model):\n")
print(anova(m5_main, m5))

# Per-condition slopes for each indicator + pairwise contrasts between conditions
emt_week <- function(model, var) {
  et <- emmeans::emtrends(model, ~ condition, var = var)
  list(
    slopes   = as.data.frame(et),
    contrasts = as.data.frame(pairs(et))
  )
}

cat("\n---- Per-condition slopes & pairwise contrasts (week 5) ----\n")
w5_slopes <- purrr::imap_dfr(indicators, function(col, nm) {
  e <- emt_week(m5, col)
  e$slopes |> rename(slope = 2) |> mutate(indicator = nm)
})
w5_contr <- purrr::imap_dfr(indicators, function(col, nm) {
  emt_week(m5, col)$contrasts |> mutate(indicator = nm)
})
print(as.data.frame(w5_slopes), digits = 3, row.names = FALSE)
cat("\nPairwise slope differences (week 5):\n")
print(as.data.frame(w5_contr), digits = 3, row.names = FALSE)

save_tab(broom::tidy(m5), "07_week5_coefficients.csv")
save_tab(w5_slopes, "07_week5_slopes.csv")
save_tab(w5_contr,  "07_week5_slope_contrasts.csv")

# ---- All weeks: per-condition slope trajectories ---------------------------
weeks <- sort(unique(s4$week))
slopes_by_week <- purrr::map_dfr(weeks, function(wk) {
  m <- fit_week(s4, wk)
  purrr::imap_dfr(indicators, function(col, nm) {
    et <- as.data.frame(emmeans::emtrends(m, ~ condition, var = col))
    names(et)[2] <- "slope"
    et |> transmute(week = wk, indicator = nm, condition,
                    slope, lo = lower.CL, hi = upper.CL)
  })
}) |>
  mutate(indicator = factor(indicator, levels = names(indicators)),
         condition = factor(condition, levels = CONDITION_LEVELS))

save_tab(slopes_by_week, "07_slopes_by_week.csv")

p_slopes <- slopes_by_week |>
  ggplot(aes(week, slope, colour = condition, fill = condition)) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.2) +
  facet_wrap(~ indicator, ncol = 3) +
  scale_colour_manual(values = CONDITION_COLOURS, drop = FALSE) +
  scale_fill_manual(values = CONDITION_COLOURS, drop = FALSE) +
  scale_x_continuous(breaks = seq(1, 11, 2)) +
  labs(title = "STAT0004: partial slope of each engagement indicator on final grade, by week",
       subtitle = "Slopes from final_grade ~ (freq+imm+div)*condition; grade points per +1 SD of cumulative indicator",
       x = "University week", y = "Partial slope (grade points per SD)",
       colour = "Delivery condition", fill = "Delivery condition") +
  theme_bw(base_size = 11) + theme(legend.position = "bottom")

save_fig(p_slopes, "07_slope_trajectories_STAT0004.png", width = 11, height = 5)

# Week-by-week overall interaction p-value (any engagement x condition term)
int_p <- purrr::map_dfr(weeks, function(wk) {
  d <- filter(s4, week == wk)
  full <- lm(final_grade ~ (z_cum_freq + z_cum_imm + z_cum_div) * condition, d)
  main <- lm(final_grade ~ z_cum_freq + z_cum_imm + z_cum_div + condition, d)
  a <- anova(main, full)
  tibble(week = wk, F = round(a$F[2], 2), df = a$Df[2],
         p_interaction = signif(a$`Pr(>F)`[2], 3))
})
save_tab(int_p, "07_interaction_pvalues_by_week.csv")
cat("\nWeek-by-week test of engagement x condition interaction (STAT0004):\n")
print(as.data.frame(int_p), row.names = FALSE)

cat("\nSaved figure: 07_slope_trajectories_STAT0004.png\n")
cat("Saved tables: 07_week5_*.csv, 07_slopes_by_week.csv, 07_interaction_pvalues_by_week.csv\n")
