# =============================================================================
# 04_build_features.R   (TODO: tidy-features)
#
# Build the weekly engagement feature tables for every cohort and persist them
# (RDS for fast reuse by later scripts; CSV previews for inspection).
# =============================================================================

source("R/00_setup.R")
source("R/features.R")

cohorts <- purrr::pmap(list(COHORTS$module, COHORTS$file_tag),
                       \(m, ft) load_cohort(m, ft))
names(cohorts) <- COHORTS$cohort_id

# ---- Long + weekly + cumulative for each cohort, then row-bind --------------
weekly_all <- purrr::map(cohorts, \(co) {
  co$sem |> tidy_sem() |> weekly_engagement() |> add_cumulative()
}) |> purrr::list_rbind()

# Standardise the per-week summed indicators within cohort x week.
weekly_all <- standardise_within(
  weekly_all, cols = c("freq_week", "imm_week", "div_week", "IDF_week")
)

# Phase (early/mid/late) and per-student trajectory profiles.
phase_all   <- purrr::map(cohorts, \(co) co$sem |> tidy_sem() |>
                            weekly_engagement() |> phase_features()) |>
  purrr::list_rbind()

profile_all <- purrr::map(cohorts, \(co) co$sem |> tidy_sem() |>
                            weekly_engagement() |> student_profile()) |>
  purrr::list_rbind()

# ---- Persist ----------------------------------------------------------------
saveRDS(weekly_all,  file.path(TAB_DIR, "weekly_engagement.rds"))
saveRDS(phase_all,   file.path(TAB_DIR, "phase_features.rds"))
saveRDS(profile_all, file.path(TAB_DIR, "student_profiles.rds"))

save_tab(head(weekly_all, 200), "04_weekly_engagement_preview.csv")

cat("\n==================== FEATURE BUILD SUMMARY ====================\n")
cat("weekly_all rows:", nrow(weekly_all),
    "| students x weeks per cohort:\n")
print(as.data.frame(
  weekly_all |> count(cohort_id, name = "rows") |>
    left_join(weekly_all |> distinct(cohort_id, User) |> count(cohort_id, name = "students"),
              by = "cohort_id")
), row.names = FALSE)

cat("\nColumns in weekly_all:\n")
print(names(weekly_all))

cat("\nExample (one student, all weeks):\n")
ex <- weekly_all |> filter(cohort_id == "STAT0004_2122") |>
  slice_head(n = 11) |>
  select(week, freq_week, imm_week, div_week, IDF_week, cum_IDF)
print(as.data.frame(ex), digits = 3, row.names = FALSE)

cat("\nSaved RDS: weekly_engagement / phase_features / student_profiles (.rds)\n")
