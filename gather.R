#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(argparse)
  library(jsonlite)
  library(dplyr)
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

na_fix <- function(x) rapply(x, function(v) {
  if (all(v == "NA")) NA else replace(v, v == "NA", NA)
}, classes = "character", how = "replace")

# read JSON lineage file, get list of files
d <- read_json(args$`from-files`)
files <- sapply(d$members, .subset2, "files")
#ids <- sapply(d$members, .subset2, "node_id")
dirs <- sapply(d$members, .subset2, "dir")

cat(sprintf("Number of files to gather: %d\n", length(d$members)))
for (i in 1:length(files)) {
  cat(sprintf("File [%d/%d]: %s\n", i, length(files), files[i]))
}

jsons <- lapply(files, function(u) {                # read JSONs, fix NAs
  na_fix(fromJSON(u, simplifyVector = TRUE)) 
})
df <- bind_rows(lapply(jsons, data.frame))         # flatten the metrics, make df


tim_cols <- grepl("timings", colnames(df))

# write TSVs
write.table(cbind(dirname = dirs, df[,!tim_cols]), output[["metrics_tsv"]], 
            row.names = FALSE, sep = "\t", quote = FALSE)
write.table(cbind(dirname = dirs, df[,tim_cols]), output[["timings_tsv"]], 
            row.names = FALSE, sep = "\t", quote = FALSE)

