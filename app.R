# ==============================================================================
#  app.R  --  CineScope Movie Review App (Light Glassmorphism & 3D Backdrop)
#  Dependencies: shiny, bslib, DT, dplyr, ggplot2, RSQLite, DBI,
#                tidytext, stringr, readr, plotly, scales
# ==============================================================================

# -- Ensure user library is on the search path ---------------------------------
local({
  user_lib <- file.path(Sys.getenv("USERPROFILE"), "R", "win-library",
                        paste0(R.version$major, ".",
                               substr(R.version$minor, 1, 1)))
  if (dir.exists(user_lib) && !(user_lib %in% .libPaths()))
    .libPaths(c(user_lib, .libPaths()))
})

library(shiny)
library(bslib)
library(DT)
library(dplyr)
library(ggplot2)
library(RSQLite)
library(DBI)
library(tidytext)
library(stringr)
library(readr)
library(plotly)
library(scales)

source("data_prep.R")

# -- Global data ---------------------------------------------------------------
movies_df <- prepare_movies("movies.csv")
genres_all <- sort(unique(movies_df$genre))

# -- SQLite setup --------------------------------------------------------------
db_path <- "reviews.sqlite"

init_db <- function() {
  con <- dbConnect(SQLite(), db_path)
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS reviews (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      movie     TEXT    NOT NULL,
      reviewer  TEXT    NOT NULL,
      rating    REAL    NOT NULL,
      review    TEXT    NOT NULL,
      timestamp TEXT    NOT NULL
    )
  ")
  dbDisconnect(con)
}
init_db()

get_reviews <- function() {
  con  <- dbConnect(SQLite(), db_path)
  data <- dbReadTable(con, "reviews")
  dbDisconnect(con)
  data
}

insert_review <- function(movie, reviewer, rating, review) {
  con <- dbConnect(SQLite(), db_path)
  dbExecute(con,
    "INSERT INTO reviews (movie, reviewer, rating, review, timestamp)
     VALUES (?, ?, ?, ?, ?)",
    list(movie, reviewer, rating, review,
         format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  )
  dbDisconnect(con)
}

# -- Light Glassmorphism Theme -------------------------------------------------
app_theme <- bs_theme(
  version       = 5,
  bootswatch    = "flatly",
  primary       = "#6366F1",
  secondary     = "#EC4899",
  success       = "#10B981",
  base_font     = font_google("Plus Jakarta Sans"),
  heading_font  = font_google("Outfit"),
  code_font     = font_google("Fira Code"),
  "body-bg"     = "transparent",
  "body-color"  = "#1E293B"
)

# -- Light Glass Plot Theme ----------------------------------------------------
glass_theme <- function() {
  theme_minimal(base_family = "sans") +
    theme(
      plot.background  = element_rect(fill = "transparent", color = NA),
      panel.background = element_rect(fill = "rgba(255, 255, 255, 0.45)", color = NA),
      panel.grid.major = element_line(color = "rgba(99, 102, 241, 0.1)"),
      panel.grid.minor = element_blank(),
      text             = element_text(color = "#1E293B"),
      axis.text        = element_text(color = "#475569", size = 9),
      axis.title       = element_text(color = "#1E293B", face = "bold", size = 10),
      plot.title       = element_text(color = "#4338CA", size = 14, face = "bold"),
      legend.background= element_rect(fill = "transparent", color = NA),
      legend.text      = element_text(color = "#1E293B"),
      strip.text       = element_text(color = "#1E293B", face = "bold")
    )
}

# ==============================================================================
#  UI
# ==============================================================================
ui <- page_navbar(
  title = tags$div(
    class = "brand-container d-flex align-items-center gap-2",
    tags$i(class = "bi bi-film me-1", style = "color:#6366F1; font-size: 1.5rem;"),
    tags$span("CineScope", style = "font-weight: 800; font-size: 1.4rem; background: linear-gradient(135deg, #4338CA, #EC4899); -webkit-background-clip: text; -webkit-text-fill-color: transparent;")
  ),
  theme    = app_theme,
  fillable = FALSE,
  header = tagList(
    tags$head(
      tags$link(rel = "stylesheet",
                href = "https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css"),
      tags$style(HTML("
        /* ── 3D Animated Movie Backdrop & Ambient Orbs ── */
        body {
          margin: 0;
          min-height: 100vh;
          background: linear-gradient(135deg, #F1F5F9 0%, #E2E8F0 40%, #EEF2FF 100%) fixed !important;
          font-family: 'Plus Jakarta Sans', sans-serif;
          color: #1E293B;
          overflow-x: hidden;
        }

        .bg-3d-wrapper {
          position: fixed;
          top: 0; left: 0; right: 0; bottom: 0;
          z-index: -1;
          overflow: hidden;
          pointer-events: none;
        }

        .ambient-orb {
          position: absolute;
          border-radius: 50%;
          filter: blur(80px);
          opacity: 0.55;
          animation: floatOrb 18s ease-in-out infinite alternate;
        }
        .orb-1 { width: 450px; height: 450px; background: #C7D2FE; top: -100px; left: -100px; }
        .orb-2 { width: 500px; height: 500px; background: #FBCFE8; bottom: -150px; right: -100px; animation-delay: -6s; }
        .orb-3 { width: 350px; height: 350px; background: #A7F3D0; top: 40%; left: 60%; animation-delay: -12s; }

        @keyframes floatOrb {
          0%   { transform: translate(0, 0) scale(1); }
          50%  { transform: translate(40px, 60px) scale(1.1); }
          100% { transform: translate(-30px, -40px) scale(0.95); }
        }

        /* 3D Floating Movie Tiles Track */
        .movie-grid-3d {
          position: absolute;
          width: 140%;
          height: 140%;
          top: -20%; left: -20%;
          display: flex;
          gap: 30px;
          transform: perspective(1000px) rotateX(25deg) rotateY(-15deg) rotateZ(5deg);
          opacity: 0.22;
        }

        .poster-column {
          display: flex;
          flex-direction: column;
          gap: 25px;
          animation: scrollUp 40s linear infinite;
        }
        .poster-column:nth-child(even) {
          animation-direction: reverse;
          animation-duration: 48s;
        }

        .poster-card-3d {
          width: 140px;
          height: 200px;
          border-radius: 16px;
          background: linear-gradient(135deg, rgba(99, 102, 241, 0.4), rgba(236, 72, 153, 0.4));
          box-shadow: 0 15px 35px rgba(0, 0, 0, 0.1);
          backdrop-filter: blur(4px);
          border: 1px solid rgba(255, 255, 255, 0.8);
          display: flex;
          align-items: center;
          justify-content: center;
          color: rgba(30, 41, 59, 0.7);
          font-weight: 700;
          font-size: 0.85rem;
          text-align: center;
          padding: 12px;
        }

        @keyframes scrollUp {
          0%   { transform: translateY(0); }
          100% { transform: translateY(-50%); }
        }

        /* ── Glassmorphism UI Components ── */
        .navbar {
          background: rgba(255, 255, 255, 0.75) !important;
          backdrop-filter: blur(20px) saturate(180%) !important;
          -webkit-backdrop-filter: blur(20px) saturate(180%) !important;
          border-bottom: 1px solid rgba(255, 255, 255, 0.8) !important;
          box-shadow: 0 4px 30px rgba(99, 102, 241, 0.08) !important;
          padding: 12px 24px !important;
        }

        .nav-link {
          color: #475569 !important;
          font-weight: 600 !important;
          border-radius: 12px !important;
          padding: 8px 16px !important;
          transition: all 0.3s ease !important;
        }
        .nav-link:hover, .nav-link.active {
          color: #6366F1 !important;
          background: rgba(99, 102, 241, 0.12) !important;
        }

        .card {
          background: rgba(255, 255, 255, 0.65) !important;
          backdrop-filter: blur(20px) saturate(180%) !important;
          -webkit-backdrop-filter: blur(20px) saturate(180%) !important;
          border: 1px solid rgba(255, 255, 255, 0.85) !important;
          box-shadow: 0 10px 30px 0 rgba(31, 38, 135, 0.07), inset 0 0 0 1px rgba(255, 255, 255, 0.6) !important;
          border-radius: 20px !important;
          transition: transform 0.3s ease, box-shadow 0.3s ease !important;
        }
        .card:hover {
          transform: translateY(-2px);
          box-shadow: 0 15px 35px 0 rgba(99, 102, 241, 0.12), inset 0 0 0 1px rgba(255, 255, 255, 0.8) !important;
        }

        .card-header {
          background: rgba(255, 255, 255, 0.45) !important;
          border-bottom: 1px solid rgba(226, 232, 240, 0.8) !important;
          font-weight: 700 !important;
          color: #1E293B !important;
          border-radius: 20px 20px 0 0 !important;
          padding: 14px 20px !important;
        }

        /* Stat Box Glass Style */
        .stat-box {
          background: linear-gradient(135deg, rgba(255, 255, 255, 0.85), rgba(238, 242, 255, 0.75));
          backdrop-filter: blur(16px);
          border: 1px solid rgba(255, 255, 255, 0.9);
          border-radius: 20px;
          padding: 22px;
          text-align: center;
          box-shadow: 0 8px 25px rgba(99, 102, 241, 0.08);
          transition: all 0.3s ease;
        }
        .stat-box:hover {
          transform: translateY(-4px) scale(1.02);
          box-shadow: 0 12px 30px rgba(99, 102, 241, 0.15);
          border-color: rgba(99, 102, 241, 0.4);
        }
        .stat-box h2 {
          background: linear-gradient(135deg, #4338CA, #EC4899);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          font-size: 2.3rem;
          font-weight: 800;
          margin: 0;
        }
        .stat-box p {
          color: #64748B;
          font-weight: 600;
          margin: 4px 0 0 0;
          font-size: 0.9rem;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }

        /* Inputs & Buttons */
        .form-control, .form-select, .selectize-input {
          background-color: rgba(255, 255, 255, 0.75) !important;
          border: 1px solid rgba(203, 213, 225, 0.8) !important;
          border-radius: 12px !important;
          color: #1E293B !important;
          backdrop-filter: blur(8px) !important;
        }
        .form-control:focus, .form-select:focus, .selectize-input.focus {
          border-color: #6366F1 !important;
          box-shadow: 0 0 0 4px rgba(99, 102, 241, 0.15) !important;
          background-color: rgba(255, 255, 255, 0.95) !important;
        }

        .btn-primary {
          background: linear-gradient(135deg, #6366F1, #4F46E5) !important;
          border: none !important;
          border-radius: 12px !important;
          font-weight: 700 !important;
          box-shadow: 0 4px 15px rgba(99, 102, 241, 0.3) !important;
          transition: all 0.3s ease !important;
        }
        .btn-primary:hover {
          transform: translateY(-2px) !important;
          box-shadow: 0 8px 25px rgba(99, 102, 241, 0.4) !important;
        }

        /* DataTables Custom Light Styling */
        .dataTables_wrapper { color: #1E293B !important; }
        table.dataTable { border-collapse: separate !important; border-spacing: 0 8px !important; }
        table.dataTable tbody tr {
          background-color: rgba(255, 255, 255, 0.6) !important;
          backdrop-filter: blur(10px) !important;
          border-radius: 10px !important;
          transition: all 0.2s ease !important;
        }
        table.dataTable tbody tr:hover {
          background-color: rgba(238, 242, 255, 0.9) !important;
          transform: scale(1.002);
        }
        table.dataTable thead th {
          background: rgba(224, 231, 255, 0.65) !important;
          color: #4338CA !important;
          font-weight: 700 !important;
          border: none !important;
        }

        /* Review Cards */
        .review-card {
          background: rgba(255, 255, 255, 0.75);
          backdrop-filter: blur(12px);
          border: 1px solid rgba(255, 255, 255, 0.9);
          border-radius: 16px;
          padding: 18px;
          margin-bottom: 14px;
          box-shadow: 0 4px 15px rgba(0, 0, 0, 0.03);
          transition: all 0.3s ease;
        }
        .review-card:hover {
          transform: translateX(4px);
          box-shadow: 0 6px 20px rgba(99, 102, 241, 0.1);
        }
        .review-card .reviewer { color: #4338CA; font-weight: 700; }
        .review-card .timestamp { color: #94A3B8; font-size: 0.8rem; }

        .sentiment-positive { color: #10B981; font-weight: 800; }
        .sentiment-negative { color: #EF4444; font-weight: 800; }
        .sentiment-neutral  { color: #64748B; font-weight: 800; }
      "))
    ),
    tags$div(
      class = "bg-3d-wrapper",
      tags$div(class = "ambient-orb orb-1"),
      tags$div(class = "ambient-orb orb-2"),
      tags$div(class = "ambient-orb orb-3"),
      tags$div(
        class = "movie-grid-3d",
        tags$div(class = "poster-column",
          tags$div(class = "poster-card-3d", "ACTION"),
          tags$div(class = "poster-card-3d", "9.8 / 10"),
          tags$div(class = "poster-card-3d", "CINEMA"),
          tags$div(class = "poster-card-3d", "DRAMA"),
          tags$div(class = "poster-card-3d", "BLOCKBUSTER"),
          tags$div(class = "poster-card-3d", "SCI-FI")
        ),
        tags$div(class = "poster-column",
          tags$div(class = "poster-card-3d", "COMEDY"),
          tags$div(class = "poster-card-3d", "TOP RATED"),
          tags$div(class = "poster-card-3d", "ROMANCE"),
          tags$div(class = "poster-card-3d", "FANTASY"),
          tags$div(class = "poster-card-3d", "THRILLER"),
          tags$div(class = "poster-card-3d", "ANIMATION")
        ),
        tags$div(class = "poster-column",
          tags$div(class = "poster-card-3d", "HORROR"),
          tags$div(class = "poster-card-3d", "CLASSIC"),
          tags$div(class = "poster-card-3d", "CRIME"),
          tags$div(class = "poster-card-3d", "9.5 / 10"),
          tags$div(class = "poster-card-3d", "ADVENTURE"),
          tags$div(class = "poster-card-3d", "MYSTERY")
        ),
        tags$div(class = "poster-column",
          tags$div(class = "poster-card-3d", "OSCAR WINNER"),
          tags$div(class = "poster-card-3d", "WESTERN"),
          tags$div(class = "poster-card-3d", "FAMILY"),
          tags$div(class = "poster-card-3d", "WAR"),
          tags$div(class = "poster-card-3d", "9.2 / 10"),
          tags$div(class = "poster-card-3d", "HISTORY")
        )
      )
    )
  ),

  # -- TAB 1: Browse -----------------------------------------------------------
  nav_panel(
    title = tagList(tags$i(class = "bi bi-grid-fill me-1"), "Browse"),
    value = "browse",

    # Summary stats row
    layout_columns(
      col_widths = c(3, 3, 3, 3),
      div(class = "stat-box",
          tags$h2(textOutput("stat_total", inline = TRUE)),
          tags$p("Total Movies")),
      div(class = "stat-box",
          tags$h2(textOutput("stat_genres", inline = TRUE)),
          tags$p("Genres")),
      div(class = "stat-box",
          tags$h2(textOutput("stat_avg", inline = TRUE)),
          tags$p("Avg Rating")),
      div(class = "stat-box",
          tags$h2(textOutput("stat_years", inline = TRUE)),
          tags$p("Year Span"))
    ),

    br(),

    # Filters row
    layout_columns(
      col_widths = c(5, 4, 3),
      card(
        card_header(tags$i(class = "bi bi-search me-2", style = "color:#6366F1;"), "Search"),
        textInput("search_text", NULL,
                  placeholder = "Search title or overview...",
                  width = "100%")
      ),
      card(
        card_header(tags$i(class = "bi bi-funnel-fill me-2", style = "color:#EC4899;"), "Genre"),
        selectInput("genre_filter", NULL,
                    choices  = c("All Genres" = "", genres_all),
                    selected = "",
                    width    = "100%")
      ),
      card(
        card_header(tags$i(class = "bi bi-star-fill me-2", style = "color:#F59E0B;"), "Min Rating"),
        sliderInput("rating_filter", NULL,
                    min = 0, max = 10, value = 0, step = 0.5, width = "100%")
      )
    ),

    br(),

    card(
      card_header(
        tags$i(class = "bi bi-film me-2", style = "color:#6366F1;"), "Movie Catalogue",
        tags$span(
          class = "float-end text-muted small",
          textOutput("filtered_count", inline = TRUE)
        )
      ),
      DTOutput("movies_table")
    )
  ),

  # -- TAB 2: Insights ---------------------------------------------------------
  nav_panel(
    title = tagList(tags$i(class = "bi bi-bar-chart-fill me-1"), "Insights"),
    value = "insights",

    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header(tags$i(class = "bi bi-trophy-fill me-2", style = "color:#F59E0B;"),
                    "Average Rating by Genre"),
        plotlyOutput("plot_genre_rating", height = "350px")
      ),
      card(
        card_header(tags$i(class = "bi bi-calendar3 me-2", style = "color:#6366F1;"),
                    "Movies Released per Year"),
        plotlyOutput("plot_movies_year", height = "350px")
      )
    ),

    br(),

    card(
      card_header(tags$i(class = "bi bi-award-fill me-2", style = "color:#EC4899;"), "Top 10 Rated Movies"),
      plotlyOutput("plot_top10", height = "400px")
    )
  ),

  # -- TAB 3: Write a Review --------------------------------------------------
  nav_panel(
    title = tagList(tags$i(class = "bi bi-pencil-fill me-1"), "Write a Review"),
    value = "review",

    layout_columns(
      col_widths = c(5, 7),

      card(
        card_header(tags$i(class = "bi bi-send-fill me-2", style = "color:#6366F1;"), "Submit Your Review"),
        selectizeInput("rev_movie", "Movie",
                    choices  = NULL,
                    options  = list(placeholder = "Type to search a movie..."),
                    width    = "100%"),
        textInput("rev_name",       "Your Name",
                  placeholder = "Enter your name", width = "100%"),
        sliderInput("rev_rating",   "Your Rating",
                    min = 1, max = 10, value = 7, step = 0.5, width = "100%"),
        textAreaInput("rev_text",   "Your Review",
                      placeholder = "Write your thoughts about the movie...",
                      rows = 5, width = "100%"),
        actionButton("submit_review", "Submit Review",
                     class = "btn-primary w-100",
                     icon  = icon("paper-plane")),
        br(), br(),
        uiOutput("review_feedback")
      ),

      card(
        card_header(tags$i(class = "bi bi-chat-quote-fill me-2", style = "color:#EC4899;"),
                    "Recent Reviews"),
        div(style = "max-height:520px; overflow-y:auto;",
            uiOutput("reviews_list"))
      )
    )
  ),

  # -- TAB 4: Sentiment Analysis ----------------------------------------------
  nav_panel(
    title = tagList(tags$i(class = "bi bi-emoji-smile-fill me-1"), "Sentiment"),
    value = "sentiment",

    layout_columns(
      col_widths = c(4, 8),

      card(
        card_header(tags$i(class = "bi bi-sliders me-2", style = "color:#6366F1;"), "Options"),
        selectInput("sent_source",  "Analyse Text From",
                    choices  = c("Movie Overviews" = "overview",
                                 "User Reviews"    = "reviews"),
                    selected = "overview"),
        selectInput("sent_genre",   "Filter by Genre",
                    choices  = c("All" = "", genres_all),
                    selected = ""),
        hr(),
        h6("Overall Sentiment", style = "color:#64748B; font-weight:700;"),
        uiOutput("sentiment_summary"),
        hr(),
        h6("Top Positive Words", style = "color:#10B981; font-weight:700;"),
        uiOutput("top_pos_words"),
        hr(),
        h6("Top Negative Words", style = "color:#EF4444; font-weight:700;"),
        uiOutput("top_neg_words")
      ),

      card(
        card_header(tags$i(class = "bi bi-pie-chart-fill me-2", style = "color:#EC4899;"),
                    "Sentiment Word Frequency"),
        plotlyOutput("plot_sentiment", height = "480px")
      )
    )
  )
)

# ==============================================================================
#  SERVER
# ==============================================================================
server <- function(input, output, session) {

  # -- Populate server-side selectize (fast for 4800+ titles) ------------------
  updateSelectizeInput(session, "rev_movie",
                       choices  = sort(movies_df$title),
                       server   = TRUE)

  # -- Reactive: filtered movies -----------------------------------------------
  filtered_movies <- reactive({
    df <- movies_df
    if (nchar(trimws(input$search_text)) > 0) {
      pattern <- regex(trimws(input$search_text), ignore_case = TRUE)
      df <- dplyr::filter(df, str_detect(title, pattern) | str_detect(overview, pattern))
    }
    if (!is.null(input$genre_filter) && input$genre_filter != "") {
      df <- dplyr::filter(df, genre == input$genre_filter)
    }
    df <- dplyr::filter(df, vote_average >= input$rating_filter)
    df
  })

  # -- Stats -------------------------------------------------------------------
  output$stat_total  <- renderText(nrow(movies_df))
  output$stat_genres <- renderText(length(genres_all))
  output$stat_avg    <- renderText(
    round(mean(movies_df$vote_average, na.rm = TRUE), 1)
  )
  output$stat_years  <- renderText({
    paste0(min(movies_df$release_year, na.rm = TRUE), "--",
           max(movies_df$release_year, na.rm = TRUE))
  })
  output$filtered_count <- renderText({
    n <- nrow(filtered_movies())
    paste(n, "movie(s) found")
  })

  # -- DT table ----------------------------------------------------------------
  output$movies_table <- renderDT({
    df <- filtered_movies() %>%
      mutate(
        Rating = vote_average,
        Year   = release_year
      ) %>%
      select(Title = title, Genre = genre, Year, Rating, Overview = overview)

    datatable(
      df,
      escape    = FALSE,
      rownames  = FALSE,
      selection = "single",
      options   = list(
        pageLength  = 10,
        scrollX     = TRUE,
        dom         = "tip",
        columnDefs  = list(
          list(width = "38%", targets = 4),
          list(className = "dt-center", targets = c(1, 2, 3))
        )
      ),
      class = "compact hover"
    ) %>%
      formatStyle("Rating",
                  color            = styleInterval(c(5, 7.5), c("#EF4444","#F59E0B","#10B981")),
                  fontWeight       = "bold")
  })

  # -- Plot: avg rating by genre -----------------------------------------------
  output$plot_genre_rating <- renderPlotly({
    df <- movies_df %>%
      group_by(genre) %>%
      summarise(avg_rating = round(mean(vote_average, na.rm = TRUE), 2),
                n = n(), .groups = "drop") %>%
      arrange(desc(avg_rating))

    p <- ggplot(df, aes(x = reorder(genre, avg_rating), y = avg_rating,
                        fill = avg_rating,
                        text = paste0(genre, "\nAvg: ", avg_rating,
                                      "\nMovies: ", n))) +
      geom_col(width = 0.75) +
      geom_text(aes(label = avg_rating), hjust = -0.2,
                color = "#334155", size = 3.5, fontface = "bold") +
      coord_flip() +
      scale_fill_gradient(low = "#818CF8", high = "#4338CA", guide = "none") +
      scale_y_continuous(limits = c(0, 11), expand = c(0, 0)) +
      labs(x = NULL, y = "Average Rating",
           title = "Average Rating by Genre") +
      glass_theme()

    ggplotly(p, tooltip = "text") %>%
      layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "#1E293B"))
  })

  # -- Plot: movies per year ---------------------------------------------------
  output$plot_movies_year <- renderPlotly({
    df <- movies_df %>%
      count(release_year) %>%
      arrange(release_year)

    p <- ggplot(df, aes(x = release_year, y = n,
                        text = paste0("Year: ", release_year, "\nMovies: ", n))) +
      geom_area(fill = "#818CF8", alpha = 0.35) +
      geom_line(color = "#4338CA", linewidth = 1.3) +
      geom_point(color = "#EC4899", size = 2.5) +
      scale_x_continuous(breaks = scales::pretty_breaks(n = 8)) +
      labs(x = "Year", y = "Number of Movies",
           title = "Movies Released per Year") +
      glass_theme()

    ggplotly(p, tooltip = "text") %>%
      layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "#1E293B"))
  })

  # -- Plot: top 10 movies -----------------------------------------------------
  output$plot_top10 <- renderPlotly({
    df <- movies_df %>%
      arrange(desc(vote_average)) %>%
      slice_head(n = 10)

    p <- ggplot(df, aes(x = reorder(title, vote_average), y = vote_average,
                        fill = genre,
                        text = paste0(title, "\n", genre,
                                      " (", release_year, ")",
                                      "\nRating: ", vote_average))) +
      geom_col(width = 0.7) +
      geom_text(aes(label = vote_average), hjust = -0.2,
                color = "#334155", size = 3.5, fontface = "bold") +
      coord_flip() +
      scale_y_continuous(limits = c(0, 11.5), expand = c(0, 0)) +
      scale_fill_brewer(palette = "Set2") +
      labs(x = NULL, y = "Rating", fill = "Genre",
           title = "Top 10 Highest-Rated Movies") +
      glass_theme() +
      theme(legend.position = "bottom")

    ggplotly(p, tooltip = "text") %>%
      layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "#1E293B"))
  })

  # -- Review submission -------------------------------------------------------
  review_trigger <- reactiveVal(0)

  observeEvent(input$submit_review, {
    req(input$rev_movie, input$rev_name, input$rev_text)

    if (nchar(trimws(input$rev_name)) < 2) {
      output$review_feedback <- renderUI(
        div(class = "alert alert-danger mt-2", style = "border-radius:12px;",
            icon("exclamation-circle"), " Please enter your name.")
      )
      return()
    }
    if (nchar(trimws(input$rev_text)) < 10) {
      output$review_feedback <- renderUI(
        div(class = "alert alert-danger mt-2", style = "border-radius:12px;",
            icon("exclamation-circle"),
            " Review must be at least 10 characters.")
      )
      return()
    }

    insert_review(
      movie    = input$rev_movie,
      reviewer = trimws(input$rev_name),
      rating   = input$rev_rating,
      review   = trimws(input$rev_text)
    )

    output$review_feedback <- renderUI(
      div(class = "alert alert-success mt-2", style = "border-radius:12px;",
          icon("check-circle"), " Review submitted! Thank you.")
    )

    updateTextInput(session, "rev_name",  value = "")
    updateTextAreaInput(session, "rev_text", value = "")
    review_trigger(review_trigger() + 1)
  })

  # -- Reviews list -------------------------------------------------------------
  output$reviews_list <- renderUI({
    review_trigger()
    reviews <- get_reviews()

    if (nrow(reviews) == 0) {
      return(div(style = "color:#94A3B8; text-align:center; padding:40px;",
                 icon("chat-square-dots"),
                 " No reviews yet. Be the first to write one!"))
    }

    reviews <- reviews %>% arrange(desc(timestamp))

    lapply(seq_len(nrow(reviews)), function(i) {
      r     <- reviews[i, ]
      stars <- paste(rep("*", floor(r$rating)), collapse = "")
      empty <- paste(rep("-", 10 - floor(r$rating)), collapse = "")
      div(
        class = "review-card",
        div(class = "d-flex justify-content-between align-items-center mb-1",
            span(class = "reviewer", icon("user"), " ", r$reviewer),
            span(class = "timestamp", icon("clock"), " ", r$timestamp)
        ),
        div(style = "font-size:.85rem; color:#64748B; margin-bottom:4px;",
            icon("film"), " ", r$movie),
        div(class = "stars",
            span(style = "color:#F59E0B; font-size:1.1rem; font-weight:700;", stars),
            span(style = "color:#CBD5E1; font-size:1.1rem;", empty),
            span(style = "color:#334155; margin-left:6px; font-weight:700;",
                 paste0(" ", r$rating, "/10"))
        ),
        p(style = "color:#334155; margin-top:8px; margin-bottom:0;",
          r$review)
      )
    })
  })

  # -- Sentiment analysis -------------------------------------------------------
  sentiment_data <- reactive({
    if (input$sent_source == "overview") {
      df <- movies_df
      if (!is.null(input$sent_genre) && input$sent_genre != "") {
        df <- dplyr::filter(df, genre == input$sent_genre)
      }
      text_col <- df %>%
        mutate(doc_id = row_number(), text = overview) %>%
        select(doc_id, text)
    } else {
      reviews <- get_reviews()
      if (nrow(reviews) == 0) {
        return(list(words = tibble(), summary = "neutral", pos = 0, neg = 0))
      }
      text_col <- reviews %>%
        mutate(doc_id = row_number(), text = review) %>%
        select(doc_id, text)
    }

    words <- text_col %>%
      unnest_tokens(word, text) %>%
      anti_join(stop_words, by = "word") %>%
      inner_join(get_sentiments("bing"), by = "word") %>%
      count(word, sentiment, sort = TRUE)

    pos_score <- sum(words$n[words$sentiment == "positive"], na.rm = TRUE)
    neg_score <- sum(words$n[words$sentiment == "negative"], na.rm = TRUE)

    overall <- if (pos_score > neg_score * 1.3) "positive" else
               if (neg_score > pos_score * 1.3) "negative" else "neutral"

    list(words = words, summary = overall,
         pos = pos_score, neg = neg_score)
  })

  output$sentiment_summary <- renderUI({
    sd <- sentiment_data()
    cls <- paste0("sentiment-", sd$summary)
    div(
      class = cls,
      style = "font-size:1.8rem; text-align:center; padding:10px;",
      icon(switch(sd$summary,
                  positive = "emoji-smile-fill",
                  negative = "emoji-frown-fill",
                  neutral  = "emoji-neutral-fill")),
      br(),
      str_to_title(sd$summary),
      br(),
      div(style = "font-size:.85rem; color:#64748B; margin-top:4px;",
          paste0("Pos: ", sd$pos, "  |  Neg: ", sd$neg))
    )
  })

  output$top_pos_words <- renderUI({
    words <- sentiment_data()$words
    top_pos <- dplyr::filter(words, sentiment == "positive") %>% head(5)
    if (nrow(top_pos) == 0) return(p("No positive words found.", style = "color:#94A3B8"))
    tags$ul(style = "color:#10B981; list-style:none; padding:0;",
      lapply(seq_len(nrow(top_pos)), function(i)
        tags$li(paste0("+ ", top_pos$word[i], " (", top_pos$n[i], ")"))
      )
    )
  })

  output$top_neg_words <- renderUI({
    words <- sentiment_data()$words
    top_neg <- dplyr::filter(words, sentiment == "negative") %>% head(5)
    if (nrow(top_neg) == 0) return(p("No negative words found.", style = "color:#94A3B8"))
    tags$ul(style = "color:#EF4444; list-style:none; padding:0;",
      lapply(seq_len(nrow(top_neg)), function(i)
        tags$li(paste0("- ", top_neg$word[i], " (", top_neg$n[i], ")"))
      )
    )
  })

  output$plot_sentiment <- renderPlotly({
    words <- sentiment_data()$words
    if (nrow(words) == 0) {
      return(plotly_empty() %>%
               layout(title = "No data for sentiment analysis.",
                      paper_bgcolor = "rgba(0,0,0,0)",
                      font = list(color = "#1E293B")))
    }

    df <- words %>%
      group_by(sentiment) %>%
      slice_max(n, n = 12, with_ties = FALSE) %>%
      ungroup() %>%
      mutate(word = reorder(word, n))

    p <- ggplot(df, aes(x = word, y = n, fill = sentiment,
                        text = paste0(word, "\nCount: ", n))) +
      geom_col(show.legend = FALSE) +
      facet_wrap(~sentiment, scales = "free_y") +
      coord_flip() +
      scale_fill_manual(values = c(negative = "#EF4444",
                                   positive = "#10B981")) +
      labs(x = NULL, y = "Frequency",
           title = "Most Frequent Sentiment Words") +
      glass_theme() +
      theme(strip.background = element_rect(fill = "rgba(224, 231, 255, 0.6)", color = NA))

    ggplotly(p, tooltip = "text") %>%
      layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "#1E293B"))
  })
}

# -- Run -----------------------------------------------------------------------
shinyApp(ui = ui, server = server)
