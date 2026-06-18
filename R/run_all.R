# =============================================================================
# run_all.R
# Run the full engagement-analysis pipeline end to end. From the project root:
#   "C:/Program Files/R/R-4.4.3/bin/Rscript.exe" R/run_all.R
# Each step writes figures to outputs/figures and tables to outputs/tables.
# =============================================================================

steps <- c(
  "R/01_verify_metric.R",       # confirm sem contributions are per-week
  "R/02_check_schema.R",        # loaders + schema consistency
  "R/03_data_inventory.R",      # cohort sizes, grades, overlap
  "R/04_build_features.R",      # weekly / cumulative / phase / profile features
  "R/05_build_model_df.R",      # join grades, exclude absences, standardise
  "R/06_replicate_paper.R",     # weekly correlations + quintile boxplots
  "R/07_interaction.R",         # engagement x condition interaction (STAT0004)
  "R/08_early_warning.R",       # bottom-quintile recall / precision / AUC
  "R/09_stat0002_replication.R",# STAT0002 + cross-module replication
  "R/10_profiles_clustering.R"  # behaviour profiles + PAM clustering
)

for (s in steps) {
  message("\n========================= RUNNING: ", s, " =========================")
  source(s, echo = FALSE)
}
message("\nPipeline complete. See outputs/figures and outputs/tables.")
