# ─────────────────────────────────────────────
#  data_prep.R  –  Load & clean movie data
#  Supports:
#    • tmdb_5000_movies.csv  (real TMDB dataset)
#    • movies.csv            (simple 5-col format)
#    • auto-generated fallback if neither exists
# ─────────────────────────────────────────────
library(dplyr)
library(readr)
library(stringr)

# ── 1. Load ───────────────────────────────────
load_movies <- function(csv_path = "movies.csv") {

  # Prefer the real TMDB dataset if present
  tmdb_path <- "tmdb_5000_movies.csv"

  if (file.exists(tmdb_path)) {
    message("Loading real TMDB dataset: ", tmdb_path)
    movies <- read_csv(tmdb_path, show_col_types = FALSE)
    movies <- wrangle_tmdb(movies)

  } else if (file.exists(csv_path)) {
    message("Loading: ", csv_path)
    movies <- read_csv(csv_path, show_col_types = FALSE)

  } else {
    message("No CSV found – generating sample dataset of 200 movies.")
    movies <- generate_sample()
    write_csv(movies, csv_path)
    message("Saved to ", csv_path)
  }

  movies
}

# ── 2. TMDB-specific wrangling ────────────────
wrangle_tmdb <- function(df) {
  df %>%
    mutate(
      # Extract first genre name from JSON string, e.g. [{"id":28,"name":"Action"},…]
      genre = str_match(genres, '"name":\\s*"([^"]+)"')[, 2],
      genre = if_else(is.na(genre) | genre == "", "Unknown", genre),

      # Parse release_year from "YYYY-MM-DD"
      release_year = as.integer(str_sub(as.character(release_date), 1, 4)),

      # Keep title & overview as-is; vote_average already numeric
      title        = as.character(title),
      vote_average = as.numeric(vote_average),
      overview     = as.character(overview)
    ) %>%
    select(title, genre, release_year, vote_average, overview)
}

# ── 3. Generate fallback sample ───────────────
generate_sample <- function(n = 200) {
  set.seed(42)
  genres      <- c("Action", "Comedy", "Drama", "Horror", "Romance",
                   "Sci-Fi", "Thriller", "Animation", "Fantasy", "Documentary")
  first_words  <- c("The","A","Last","Dark","Bright","Lost","Eternal",
                    "Wild","Silent","Broken","Rising","Fallen","Hidden",
                    "Frozen","Burning","Golden","Silver","Iron","Ghost","Shadow")
  second_words <- c("Knight","Promise","Journey","Echo","Storm","Dawn",
                    "Horizon","Legacy","Frontier","Whisper","Enigma",
                    "Paradox","Odyssey","Labyrinth","Chronicle","Saga",
                    "Vortex","Phantom","Ember","Cipher")

  title_pool <- unique(paste(sample(first_words, n * 2, replace = TRUE),
                             sample(second_words, n * 2, replace = TRUE)))
  tibble(
    title        = title_pool[seq_len(n)],
    genre        = sample(genres, n, replace = TRUE),
    release_year = sample(1990:2024, n, replace = TRUE),
    vote_average = round(runif(n, 3.5, 9.8), 1),
    overview     = paste(
      sample(c("A thrilling story about","An emotional journey through",
               "A mysterious tale of","An epic adventure involving"),
             n, replace = TRUE),
      sample(c("love and loss","power and corruption","survival and hope",
               "friendship and betrayal","identity and purpose"),
             n, replace = TRUE), ".")
  )
}

# ── 4. Clean / validate ───────────────────────
clean_movies <- function(df) {
  df %>%
    rename_with(str_to_lower) %>%
    rename_with(~ str_replace_all(.x, "\\s+", "_")) %>%

    select(any_of(c("title", "genre", "release_year",
                    "vote_average", "overview"))) %>%

    filter(!is.na(title), !is.na(vote_average)) %>%

    mutate(
      title        = str_squish(as.character(title)),
      genre        = str_squish(as.character(genre)),
      release_year = as.integer(release_year),
      vote_average = as.numeric(vote_average),
      overview     = if_else(is.na(overview) | str_squish(overview) == "",
                             "No overview available.",
                             str_squish(as.character(overview)))
    ) %>%

    filter(vote_average >= 0, vote_average <= 10) %>%
    filter(!is.na(release_year)) %>%
    distinct(title, .keep_all = TRUE) %>%
    arrange(desc(vote_average))
}

# ── 5. Public wrapper ─────────────────────────
prepare_movies <- function(csv_path = "movies.csv") {
  raw   <- load_movies(csv_path)
  clean <- clean_movies(raw)
  message("Dataset ready: ", nrow(clean), " movies, ",
          n_distinct(clean$genre), " genres, ",
          min(clean$release_year, na.rm = TRUE), "–",
          max(clean$release_year, na.rm = TRUE))
  clean
}
