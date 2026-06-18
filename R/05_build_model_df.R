# =============================================================================
# 05_build_model_df.R   (TODO: build-model-df)
#
# Assemble the modelling dataset:
#   weekly engagement  ->  join final_grade  ->  exclude absences (grade<=0)
#   ->  (re)standardise engagement WITHIN cohort x week on the analysis set
#   ->  add cumulative z-scores and grade thresholds.
# Saved as model_df.rds for all downstream modelling scripts.
# =============================================================================

source("R/00_setup.R")
source("R/features.R")

weekly <- readRDS(file.path(TAB_DIR, "weekly_engagement.rds"))
grades <- load_all("grades") |> select(cohort_id, condition, User, final_grade)

model_df <- weekly |>
  select(-starts_with("z_")) |>                 # drop pre-join z-scores; redo below
  attach_grades(grades) |>                      # inner join + final_grade>0
  standardise_within(cols = c("freq_week", "imm_week", "div_week", "IDF_week",
                              "cum_freq", "cum_imm", "cum_div", "cum_IDF")) |>
  mutate(
    condition = factor(as.character(condition), levels = CONDITION_LEVELS),
    low  = final_grade < 50,    # low performer (D/F), paper threshold
    fail = final_grade < 40     # fail (F)
  )

saveRDS(model_df, file.path(TAB_DIR, "model_df.rds"))

cat("\n==================== MODEL DATAFRAME ====================\n")
cat("Rows:", nrow(model_df), " | students:",
    nrow(distinct(model_df, cohort_id, User)), "\n\n")

summ <- model_df |>
  group_by(cohort_id, condition) |>
  summarise(students = n_distinct(User), rows = n(),
            mean_grade = round(mean(final_grade), 1),
            pct_low = round(100 * mean(low[week == max(week)]), 1),
            .groups = "drop")
print(as.data.frame(summ), row.names = FALSE)

cat("\nKey modelling columns: z_freq_week, z_imm_week, z_div_week, z_IDF_week,\n",
    "z_cum_freq, z_cum_imm, z_cum_div, z_cum_IDF, final_grade, low, fail\n")

# Sanity: z-scores should be ~0 mean / ~1 sd within each cohort x week.
chk <- model_df |>
  group_by(cohort_id, week) |>
  summarise(m = round(mean(z_IDF_week), 3), s = round(sd(z_IDF_week), 3),
            .groups = "drop") |>
  summarise(max_abs_mean = max(abs(m), na.rm = TRUE),
            sd_range = paste0(round(min(s, na.rm = TRUE), 2), "-",
                              round(max(s, na.rm = TRUE), 2)))
cat("\nStandardisation check (z_IDF_week within cohort x week):\n")
print(as.data.frame(chk), row.names = FALSE)
cat("\nSaved: outputs/tables/model_df.rds\n")
