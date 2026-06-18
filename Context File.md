from pathlib import Path

content = """# Moodle Log Data Research Project — LLM Context File

## 1. Purpose of This Context

This file provides structured background information for an LLM assistant helping with a learning analytics research project using Moodle log data from UCL statistics modules.

The project focuses on analysing how student behavioural engagement with Moodle relates to final module grades, and how these relationships differ across different teaching delivery modes.

The main research paper to read first is:

https://arxiv.org/abs/2507.12162

The paper provides the methodological and conceptual background for the project.

---

## 2. Research Background

The data come from a learning analytics project analysing student engagement with Moodle across two statistics modules:

- STAT0002
- STAT0004

The project studies how behavioural engagement indicators relate to student grades.

The key focus is whether these relationships change across three delivery modes:

1. 2020-21: fully online delivery  
   - Emergency remote teaching during the COVID-19 pandemic.

2. 2021-22: hybrid delivery  
   - A mix of online and in-person teaching.

3. 2022-23: return to in-person teaching  
   - Teaching largely returned to normal in-person delivery.

Important interpretation note:

Delivery mode and academic year are perfectly confounded. Therefore, differences between years cannot be interpreted as pure delivery-mode effects. They may also reflect cohort effects.

Any analysis should describe the years as delivery conditions, but results should be interpreted cautiously.

---

## 3. Central Research Questions

The central research questions are:

1. How does frequency of engagement relate to student grades within each cohort?

2. How does immediacy of engagement relate to student grades within each cohort?

3. How does diversity of engagement relate to student grades within each cohort?

4. Do the relationships between engagement indicators and grades differ across delivery conditions?

5. Are the engagement-grade relationships stronger, weaker, or qualitatively different in:
   - fully online delivery,
   - hybrid delivery,
   - in-person delivery?

The project is now primarily interested in the individual engagement indicators:
- frequency
- immediacy
- diversity

The goal is not simply to sum them into one overall engagement score, although weekly summaries or averages may still be useful.

---

## 4. Files Shared

For each module and academic year, files follow this naming convention:

```text
{MODULE}_{YEAR}_dat_clean.csv
{MODULE}_{YEAR}_grades_clean.csv
{MODULE}_{YEAR}_weekly_chapter_IDF_norm01.csv
{MODULE}_{YEAR}_data.RData