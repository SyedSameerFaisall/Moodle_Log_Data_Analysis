# =============================================================================
# 10_profiles_clustering.R   (TODO: profiles-clustering)
#
# Interpretable behaviour profiles from per-student trajectory descriptors:
#   level (mean weekly IDF), consistency, trend, active weeks, and the
#   Frequency:Immediacy:Diversity balance. Features are z-scored WITHIN cohort
#   (so clusters reflect behaviour shape, not cohort scale), then clustered
#   with PAM. k is chosen by average silhouette width. Clusters are profiled by
#   final grade and by delivery condition.
# =============================================================================

source("R/00_setup.R")
source("R/features.R")
suppressMessages(library(cluster))
set.seed(42)

profiles <- readRDS(file.path(TAB_DIR, "student_profiles.rds"))
grades   <- load_all("grades") |> select(cohort_id, User, final_grade) |>
  mutate(final_grade = num_na(final_grade))

prof <- profiles |>
  inner_join(grades, by = c("cohort_id", "User")) |>
  filter(!is.na(final_grade), final_grade > 0)

clust_vars <- c("level_IDF", "consistency", "trend_IDF", "active_wks",
                "bal_freq", "bal_div")

# z-score within cohort to remove cohort-level scale differences
X <- prof |>
  group_by(cohort_id) |>
  mutate(across(all_of(clust_vars), \(x) {
    s <- sd(x, na.rm = TRUE); if (is.na(s) || s == 0) x * 0 else as.numeric(scale(x))
  })) |>
  ungroup() |>
  select(all_of(clust_vars)) |>
  mutate(across(everything(), \(x) tidyr::replace_na(x, 0)))

D <- dist(as.matrix(X))

# ---- Choose k by average silhouette width ----------------------------------
sil <- purrr::map_dfr(2:6, function(k) {
  pm <- cluster::pam(D, k = k, diss = TRUE)
  tibble(k = k, avg_sil = pm$silinfo$avg.width)
})
save_tab(sil, "10_silhouette_by_k.csv")
best_k <- sil$k[which.max(sil$avg_sil)]
cat("\nAverage silhouette width by k:\n"); print(as.data.frame(sil), row.names = FALSE)
cat(sprintf("Chosen k = %d\n", best_k))

pm <- cluster::pam(D, k = best_k, diss = TRUE)
prof$cluster <- factor(paste0("C", pm$clustering))

# ---- Name clusters by their dominant behaviour ------------------------------
centres <- prof |>
  group_by(cluster) |>
  summarise(across(all_of(clust_vars), \(x) round(mean(x, na.rm = TRUE), 3)),
            n = n(), mean_grade = round(mean(final_grade), 1),
            pct_low = round(100 * mean(final_grade < 50), 1), .groups = "drop")
save_tab(centres, "10_cluster_profiles.csv")

cat("\n==================== CLUSTER PROFILES ====================\n")
print(as.data.frame(centres), row.names = FALSE)

# ---- Cluster composition by delivery condition -----------------------------
comp <- prof |>
  count(condition, cluster) |>
  group_by(condition) |>
  mutate(prop = n / sum(n)) |>
  ungroup()
save_tab(comp, "10_cluster_by_condition.csv")

# ---- Figures ---------------------------------------------------------------
p_grade <- prof |>
  ggplot(aes(cluster, final_grade, fill = cluster)) +
  geom_hline(yintercept = 50, linetype = "dashed", colour = "grey30") +
  geom_boxplot(alpha = 0.8, outlier.size = 0.5) +
  labs(title = sprintf("Final grade by engagement-behaviour cluster (k = %d)", best_k),
       subtitle = "Clusters from PAM on within-cohort z-scored trajectory features",
       x = "Behaviour cluster", y = "Final grade (%)") +
  theme_bw(base_size = 11) + theme(legend.position = "none")
save_fig(p_grade, "10_cluster_grade_boxplots.png", width = 8, height = 5)

p_comp <- comp |>
  ggplot(aes(condition, prop, fill = cluster)) +
  geom_col() +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Behaviour-cluster composition by delivery condition",
       x = "Delivery condition", y = "Share of students", fill = "Cluster") +
  theme_bw(base_size = 11)
save_fig(p_comp, "10_cluster_composition.png", width = 8, height = 5)

# Cluster centre heatmap (standardised feature means) for interpretation
centre_long <- prof |>
  group_by(cluster) |>
  summarise(across(all_of(clust_vars), \(x) mean(scale(x)[, 1], na.rm = TRUE)),
            .groups = "drop")
# (use overall-scaled means just for the heatmap visual)
heat <- prof |>
  mutate(across(all_of(clust_vars), \(x) as.numeric(scale(x)))) |>
  group_by(cluster) |>
  summarise(across(all_of(clust_vars), \(x) mean(x, na.rm = TRUE)), .groups = "drop") |>
  pivot_longer(all_of(clust_vars), names_to = "feature", values_to = "z")

p_heat <- heat |>
  ggplot(aes(feature, cluster, fill = z)) +
  geom_tile() +
  geom_text(aes(label = round(z, 2)), size = 3) +
  scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b") +
  labs(title = "Cluster behaviour signatures (standardised feature means)",
       x = NULL, y = NULL, fill = "z") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
save_fig(p_heat, "10_cluster_signatures.png", width = 9, height = 4)

cat("\nCluster composition by condition (proportion):\n")
print(as.data.frame(comp |> mutate(prop = round(prop, 2))), row.names = FALSE)
cat("\nSaved figures: 10_cluster_grade_boxplots.png, 10_cluster_composition.png, 10_cluster_signatures.png\n")
cat("Saved tables: 10_silhouette_by_k.csv, 10_cluster_profiles.csv, 10_cluster_by_condition.csv\n")
