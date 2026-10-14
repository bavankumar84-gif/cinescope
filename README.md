# 🎬 CineScope — Movie Review App (R Shiny)

A full-featured Movie Review web application built **entirely in R** using Shiny, bslib, ggplot2, DT, RSQLite, and tidytext.

---

## 📁 Project Structure

```
fods mini prj/
├── app.R               # Main Shiny application (UI + Server)
├── data_prep.R         # Data loading, generation & cleaning (dplyr)
├── install_packages.R  # One-time package installer
├── movies.csv          # Auto-generated on first run (200 movies)
├── reviews.sqlite      # Auto-created SQLite DB for user reviews
└── README.md           # This file
```

---

## 🚀 Quick Start

### Step 1 — Install R packages (run ONCE)

Open RStudio or an R console and run:

```r
source("install_packages.R")
```

Or paste this directly:

```r
install.packages(c(
  "shiny", "bslib", "DT", "dplyr", "ggplot2", "plotly",
  "RSQLite", "DBI", "tidytext", "stringr", "readr", "scales"
), repos = "https://cloud.r-project.org")
```

### Step 2 — Launch the app

```r
setwd("c:/Users/User/Documents/fods mini prj")
shiny::runApp("app.R")
```

Or from RStudio: open `app.R` and click the **Run App** button.

---

## 📋 Feature Overview

### 🎞️ Browse Tab
- Full-text search across **title** and **overview**
- Dropdown **genre filter**
- **Minimum rating slider** (0–10)
- Live result count
- Interactive **DT table** with colour-coded ratings:
  - 🔴 < 5 — Red
  - 🟡 5–7 — Gold
  - 🟢 > 7 — Green

### 📊 Insights Tab
Three interactive Plotly charts:
1. **Average Rating by Genre** — horizontal bar chart
2. **Movies Released per Year** — area + line chart
3. **Top 10 Highest-Rated Movies** — grouped bar chart by genre

### ✍️ Write a Review Tab
- Select movie from dropdown
- Enter name, rating (1–10 slider), and free-text review
- Saved to **SQLite** (`reviews.sqlite`)
- Live review feed with star ratings, timestamps

### 🧠 Sentiment Analysis Tab
- Analyse either **movie overviews** or **user reviews**
- Filter by genre
- Overall sentiment label (Positive / Neutral / Negative)
- Top 5 positive & negative words
- Dual-facet **word frequency bar chart**
- Powered by **tidytext** + Bing sentiment lexicon

---

## 🎨 Design

| Property | Value |
|---|---|
| Theme engine | `bslib` (Bootstrap 5, `darkly` bootswatch) |
| Accent colour | `#E94560` (crimson red) |
| Background | `#1A1A2E` (deep navy) |
| Cards | `#16213E` (midnight blue) |
| Positive sentiment | `#1DB954` (green) |
| Fonts | Inter (body), Montserrat (headings) via Google Fonts |

---

## 📦 Dependencies

| Package | Purpose |
|---|---|
| `shiny` | Reactive web framework |
| `bslib` | Bootstrap 5 modern theming |
| `DT` | Interactive DataTables |
| `dplyr` | Data wrangling |
| `ggplot2` | Static chart generation |
| `plotly` | Interactive chart wrapping |
| `RSQLite` | SQLite driver |
| `DBI` | Database interface |
| `tidytext` | Text tokenisation & sentiment |
| `stringr` | String operations |
| `readr` | Fast CSV I/O |
| `scales` | Plot scale helpers |

---

## 🗄️ Data

- If **`movies.csv`** is present in the project folder, it is loaded automatically.
- Required columns: `title`, `genre`, `release_year`, `vote_average`, `overview`
- If the file is **missing**, `data_prep.R` auto-generates a clean 200-movie sample dataset and saves it as `movies.csv`.

---

## ⚙️ Troubleshooting

| Problem | Fix |
|---|---|
| `there is no package named 'bslib'` | Run `install_packages.R` first |
| App doesn't start | Make sure `setwd()` points to the project folder |
| Sentiment tab empty | Write at least one review first (for "User Reviews" mode) |
| Port already in use | Run `shiny::runApp(port = 3839)` |
| `tidytext` lexicon missing | Run `tidytext::get_sentiments("bing")` once to download |

---

## 📝 Notes

- No Python, no JavaScript frameworks — **pure R** throughout.
- The SQLite database (`reviews.sqlite`) is created automatically on first run.
- Charts are rendered with `ggplot2` and wrapped in `plotly` for interactivity.
