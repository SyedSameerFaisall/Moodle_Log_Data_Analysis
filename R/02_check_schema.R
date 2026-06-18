# =============================================================================
# 02_check_schema.R   (TODO: loaders)
#
# The loaders themselves (load_cohort / load_all / COHORTS registry) live in
# 00_setup.R. This script exercises them on all five module-years and confirms
# the column schemas are consistent so downstream code can treat them uniformly.
# =============================================================================

source("R/00_setup.R")

cohorts <- purrr::pmap(list(COHORTS$module, COHORTS$file_tag),
                       \(m, ft) load_cohort(m, ft))
names(cohorts) <- COHORTS$cohort_id

# Strip the metadata columns added by load_cohort before comparing native schema.
meta_cols <- c("module", "file_tag", "cohort_id", "condition")
native <- function(df) setdiff(names(df), meta_cols)

schema_report <- function(tbl_name) {
  cols <- map(cohorts, \(co) native(co[[tbl_name]]))
  ref  <- cols[[1]]
  tibble(
    table        = tbl_name,
    cohort_id    = names(cols),
    n_cols       = map_int(cols, length),
    same_as_ref  = map_lgl(cols, \(x) identical(sort(x), sort(ref))),
    extra_cols   = map_chr(cols, \(x) paste(setdiff(x, ref), collapse = ";")),
    missing_cols = map_chr(cols, \(x) paste(setdiff(ref, x), collapse = ";"))
  )
}

report <- bind_rows(schema_report("sem"),
                    schema_report("grades"),
                    schema_report("dat"))

cat("\n================ SCHEMA CONSISTENCY ACROSS COHORTS ================\n")
print(as.data.frame(report), row.names = FALSE)

# Chapter columns present in each sem (max chapter index actually used).
chap_cols <- map_dfr(names(cohorts), \(id) {
  s <- cohorts[[id]]$sem
  cc <- grep("freq_contrib", names(s), value = TRUE)
  tibble(cohort_id = id, n_chapter_cols = length(cc),
         max_chapter = max(as.integer(str_extract(cc, "\\d+$"))))
})
cat("\nChapter columns per sem:\n")
print(as.data.frame(chap_cols), row.names = FALSE)

save_tab(report, "02_schema_consistency.csv")
cat(sprintf("\nAll sem schemas identical to reference: %s\n",
            all(report$same_as_ref[report$table == "sem"])))
cat(sprintf("All grades schemas identical to reference: %s\n",
            all(report$same_as_ref[report$table == "grades"])))
cat(sprintf("All dat schemas identical to reference: %s\n",
            all(report$same_as_ref[report$table == "dat"])))
cat("\nSaved: outputs/tables/02_schema_consistency.csv\n")
