# =============================================================================
# 08_early_warning.R   (TODO: early-warning)
#
# Treat the bottom 20% of cumulative engagement (cum_IDF) each week as the
# "at-risk" flag (the paper's approach) and evaluate, per cohort x week:
#   - recall    = P(flagged | low performer)         (sensitivity)
#   - precision = P(low performer | flagged)
#   - recall for failures (<40) as a separate dotted series
#   - AUC of cum_IDF for discriminating low performers
#
# Caveat (from the inventory): STAT0004 hybrid/in-person have very few low
# performers, so recall/precision/AUC are unstable there; reported but flagged.
# =============================================================================

source("R/00_setup.R")
suppressMessages(library(pROC))

model_df <- readRDS(file.path(TAB_DIR, "model_df.rds"))
cohort_meta <- COHORTS |> select(cohort_id, year_label)

safe_auc <- function(resp, pred) {
  # resp = TRUE for low performer; low engagement should predict low performance
  if (length(unique(resp)) < 2) return(NA_real_)
  out <- tryCatch(
    as.numeric(pROC::auc(pROC::roc(response = resp, predictor = pred,
                                   levels = c(FALSE, TRUE), direction = ">",
                                   quiet = TRUE))),
    error = function(e) NA_real_)
  out
}

ew <- model_df |>
  group_by(cohort_id, condition, week) |>
  mutate(flag = cum_IDF <= quantile(cum_IDF, 0.20, na.rm = TRUE)) |>
  summarise(
    n            = n(),
    n_low        = sum(low),
    n_fail       = sum(fail),
    recall_low   = ifelse(n_low  > 0, mean(flag[low]),  NA_real_),
    recall_fail  = ifelse(n_fail > 0, mean(flag[fail]), NA_real_),
    precision_low = ifelse(sum(flag) > 0, mean(low[flag]), NA_real_),
    auc_low      = safe_auc(low, cum_IDF),
    .groups = "drop"
  )

save_tab(ew, "08_early_warning_metrics.csv")

# ---- Recall / precision figure ---------------------------------------------
ew_long <- ew |>
  select(cohort_id, condition, week, recall_low, recall_fail, precision_low) |>
  pivot_longer(c(recall_low, recall_fail, precision_low),
               names_to = "metric", values_to = "value") |>
  mutate(metric = recode(metric,
                         recall_low   = "Recall (<50)",
                         recall_fail  = "Recall (<40)",
                         precision_low = "Precision (<50)"),
         module = str_extract(cohort_id, "STAT\\d+"))

p_rp <- ew_long |>
  ggplot(aes(week, value, colour = condition, linetype = metric)) +
  geom_line(linewidth = 0.7) + geom_point(size = 1) +
  facet_wrap(~ cohort_id, ncol = 5) +
  scale_colour_manual(values = CONDITION_COLOURS, drop = FALSE) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_x_continuous(breaks = seq(1, 11, 2)) +
  labs(title = "Early-warning performance of the bottom-20% engagement flag",
       subtitle = "Recall and precision for identifying low performers, by week and cohort",
       x = "University week", y = NULL, colour = "Condition", linetype = "Metric") +
  theme_bw(base_size = 10) + theme(legend.position = "bottom")

save_fig(p_rp, "08_recall_precision.png", width = 13, height = 5)

# ---- AUC figure -------------------------------------------------------------
p_auc <- ew |>
  ggplot(aes(week, auc_low, colour = condition, group = cohort_id)) +
  geom_hline(yintercept = 0.5, linetype = "dotted", colour = "grey50") +
  geom_line(linewidth = 0.8) + geom_point(size = 1.3) +
  facet_wrap(~ str_extract(cohort_id, "STAT\\d+")) +
  scale_colour_manual(values = CONDITION_COLOURS, drop = FALSE) +
  scale_x_continuous(breaks = seq(1, 11, 2)) +
  coord_cartesian(ylim = c(0.4, 1)) +
  labs(title = "AUC of cumulative engagement for discriminating low performers (<50)",
       subtitle = "0.5 = chance. Unstable where low-performer counts are tiny (STAT0004 hybrid/in-person).",
       x = "University week", y = "AUC", colour = "Delivery condition") +
  theme_bw(base_size = 11) + theme(legend.position = "bottom")

save_fig(p_auc, "08_auc_by_week.png", width = 9, height = 5)

cat("\n==================== EARLY-WARNING SUMMARY (mid-term, week 6) ====================\n")
print(as.data.frame(
  ew |> filter(week == 6) |>
    select(cohort_id, condition, n_low, n_fail, recall_low, precision_low, auc_low) |>
    mutate(across(c(recall_low, precision_low, auc_low), \(x) round(x, 2)))
), row.names = FALSE)

cat("\nSaved figures: 08_recall_precision.png, 08_auc_by_week.png\n")
cat("Saved table: 08_early_warning_metrics.csv\n")
