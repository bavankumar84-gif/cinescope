# ─────────────────────────────────────────────
#  install_packages.R
#  Run this ONCE before launching the app.
#  install.packages() command for all deps.
# ─────────────────────────────────────────────

# ── Ensure a writable personal library exists ─
user_lib <- file.path(Sys.getenv("USERPROFILE"), "R", "win-library",
                      paste0(R.version$major, ".",
                             substr(R.version$minor, 1, 1)))
dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(user_lib, .libPaths()))
cat("Installing to:", user_lib, "\n")

install.packages(c(
  "shiny",      # Core reactive web framework
  "bslib",      # Bootstrap 5 theming for Shiny
  "DT",         # Interactive DataTables
  "dplyr",      # Data manipulation
  "ggplot2",    # Static charts
  "plotly",     # Interactive charts (wraps ggplot2)
  "RSQLite",    # SQLite database driver
  "DBI",        # Database interface
  "tidytext",   # Text mining & sentiment
  "stringr",    # String utilities
  "readr",      # Fast CSV reading
  "scales"      # Axis / colour scale helpers
), repos = "https://cloud.r-project.org", lib = user_lib)

# Verify all packages load correctly
pkgs <- c("shiny","bslib","DT","dplyr","ggplot2","plotly",
          "RSQLite","DBI","tidytext","stringr","readr","scales")

invisible(lapply(pkgs, function(p) {
  if (!requireNamespace(p, quietly = TRUE)) {
    warning("Package not installed: ", p)
  } else {
    cat("OK:", p, "\n")
  }
}))
