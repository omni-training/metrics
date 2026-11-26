#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(argparse)
  library(jsonlite)
})

parser <- ArgumentParser(description = "Benchmarking entrypoint")

# dummy args (old API)
parser$add_argument("--output_dir", dest = "output_dir")
parser$add_argument("--name", dest = "name")

parser$add_argument("--from-files", dest = "from-files", type = "integer",
                    help = "number of highly variable genes to use", default = 1000, required = FALSE)

# logging
cat(sprintf("Full command: %s\n", paste(commandArgs(trailingOnly = FALSE), collapse = " ")))

cat(sprintf("LOG: command line args\n----------------------------------\n"))
for (i in 1:length(args)) {
  cat(sprintf("  %s: %s\n", names(args)[i], args[[i]]))
}
cat(sprintf("----------------------------------\n"))

