# =============================================================================
# 03_data_inventory.R   (TODO: data-inventory)
#
# One-glance inventory of every module-year: cohort sizes, chapters released,
# week coverage, grade distribution, absences (final_grade == 0), low/fail
# counts, and the sem <-> grades student overlap that drives the join rules.
# =============================================================================

source("R/00_setup.R")

inventory_one <- function(module, file_tag) {
  co  <- load_cohort(module, file_tag)
  sem <- co$sem |> mutate(week = num_na(week))
  gr  <- co$grades |> mutate(final_grade = num_na(final_grade))

  contrib_cols <- grep("_contrib", names(sem), value = TRUE)
  # A chapter is "used" if any student has a non-NA contribution for it.
  chap_used <- sem |>
    summarise(across(all_of(contrib_cols), \(x) any(!is.na(num_na(x))))) |>
    pivot_longer(everything(), values_to = "used") |>
    mutate(chap = as.integer(str_extract(name, "\\d+$"))) |>
    filter(used) |>
    summarise(max_chapter = max(chap)) |>
    pull(max_chapter)

  pct_na <- sem |>
    summarise(across(all_of(contrib_cols), \(x) mean(is.na(num_na(x))))) |>
    unlist() |>
    mean()

  users_sem <- unique(sem$User)
  users_gr  <- unique(gr$User)
  g_valid   <- gr |> filter(!is.na(final_grade), final_grade > 0)

  tibble(
    cohort_id     = co$sem$cohort_id[1],
    module        = module,
    condition     = as.character(co$sem$condition[1]),
    n_students_sem    = length(users_sem),
    n_students_grades = length(users_gr),
    n_overlap     = length(intersect(users_sem, users_gr)),
    only_in_sem   = length(setdiff(users_sem, users_gr)),
    only_in_grades= length(setdiff(users_gr, users_sem)),
    weeks         = paste0(min(sem$week, na.rm = TRUE), "-", max(sem$week, na.rm = TRUE)),
    max_chapter   = chap_used,
    mean_pct_na_contrib = round(pct_na, 3),
    n_grade_zero  = sum(gr$final_grade == 0, na.rm = TRUE),
    n_grade_na    = sum(is.na(gr$final_grade)),
    n_analysed    = nrow(g_valid),
    mean_grade    = round(mean(g_valid$final_grade), 1),
    sd_grade      = round(sd(g_valid$final_grade), 1),
    pct_below_50  = round(100 * mean(g_valid$final_grade < 50), 1),
    pct_below_40  = round(100 * mean(g_valid$final_grade < 40), 1)
  )
}

inventory <- purrr::pmap_dfr(list(COHORTS$module, COHORTS$file_tag), inventory_one)

cat("\n======================= DATA INVENTORY =======================\n")
print(as.data.frame(inventory), row.names = FALSE)

save_tab(inventory, "03_data_inventory.csv")

# ---- Join / exclusion rule (decided from the overlap numbers) ---------------
rule <- paste(
  "JOIN RULE: inner join sem to grades on User; analysis set = students present",
  "in BOTH sem and grades with final_grade > 0 (exclude absences, per paper).",
  sep = "\n"
)
writeLines(rule, file.path(TAB_DIR, "03_join_rule.txt"))
cat("\n", rule, "\n", sep = "")
cat("\nSaved: outputs/tables/03_data_inventory.csv (+ 03_join_rule.txt)\n")
