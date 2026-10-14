local({
  user_lib <- file.path(Sys.getenv("USERPROFILE"), "R", "win-library",
                        paste0(R.version$major, ".",
                               substr(R.version$minor, 1, 1)))
  if (dir.exists(user_lib) && !(user_lib %in% .libPaths())) {
    .libPaths(c(user_lib, .libPaths()))
  }
})
