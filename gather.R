#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(argparse)
  library(jsonlite)
})

parser <- ArgumentParser(description = "Benchmarking entrypoint")

# dummy args (old API)
parser$add_argument("--output_dir", dest = "output_dir")
parser$add_argument("--name", dest = "name")

# files to gather from
parser$add_argument("--from-files", dest = "from-files", 
                    help = "JSON lineage file", required = TRUE)

# outputs
parser$add_argument("--output", action = "append", default = list(),
                    help = "Repeatable: key=path")
args <- parser$parse_args()
output <- setNames(sub("^[^=]*=", "", args$output),
                   sub("=.*$", "", args$output))

# logging
cat(sprintf("Full command: %s\n", paste(commandArgs(trailingOnly = FALSE), collapse = " ")))

cat(sprintf("LOG: command line args\n----------------------------------\n"))
for (i in 1:length(args)) {
  cat(sprintf("  %s: %s\n", names(args)[i], args[[i]]))
}
for (i in 1:length(output)) {
  cat(sprintf("[output] %s: %s\n", names(output)[i], output[[i]]))
}
cat(sprintf("----------------------------------\n"))

# Recursively flatten nested lists to a named numeric vector (null -> NA)
flatten <- function(x, prefix = NULL) {
  if (is.null(x)) return(setNames(NA_real_, prefix))
  if (!is.list(x)) return(setNames(as.numeric(x), prefix))
  unlist(lapply(names(x), function(n) flatten(x[[n]], paste(c(prefix, n), collapse = "_"))))
}


# read JSON lineage file, get list of files
d <- read_json(args$`from-files`)
files <- sapply(d$members, .subset2, "files")
ids <- sapply(d$members, .subset2, "node_id")

cat(sprintf("Number of files to gather: %d\n", length(d$members)))
for (i in 1:length(files)) {
  cat(sprintf("File [%d/%d]: %s\n", i, length(files), files[i]))
}

jsons <- lapply(files, fromJSON, simplifyVector = TRUE)  # read JSONs
dfs <- do.call(rbind, lapply(jsons, data.frame))         # flatten the metrics, make df





# Bind named vectors into a data frame, aligning columns across files
bind_rows_named <- function(rows, ids) {
  cols <- unique(unlist(lapply(rows, names)))
  m <- do.call(rbind, lapply(rows, function(r) unname(r[cols])))
  colnames(m) <- cols
  data.frame(file = ids, m, check.names = FALSE, row.names = NULL)
}

ids  <- sub("\\.json$", "", basename(files))
json <- lapply(files, fromJSON, simplifyVector = TRUE)

metrics <- bind_rows_named(lapply(json, function(j) c(
  flatten(j$agreement),                    # ari_leiden, nmi_louvain, ...
  flatten(j$structure),                    # silhouette_leiden, ...
  flatten(j$n_clusters, "n_clusters"),
  dropped_cells = as.numeric(j$dropped_cells),
  flatten(j$clustering_info)               # resolutions_leiden, num_runs_leiden, ...
)), ids)

timings <- bind_rows_named(lapply(json, function(j) flatten(j$timings)), ids)

write.csv(metrics, paste0(prefix, "_metrics.csv"), row.names = FALSE)
write.csv(timings, paste0(prefix, "_timings.csv"), row.names = FALSE)
print(metrics); print(timings)






