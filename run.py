#!/usr/bin/env python3

import argparse
import json
import sys
from pathlib import Path
from typing import Callable, SupportsFloat

import pandas as pd
from sklearn.metrics import (adjusted_rand_score, completeness_score, davies_bouldin_score,
                             fowlkes_mallows_score, homogeneity_score, calinski_harabasz_score,
                             normalized_mutual_info_score, silhouette_score, v_measure_score)

MetricFn = Callable[..., SupportsFloat]

METRIC_MAP: dict[str, dict[str, MetricFn]] = {
    "agreement": {
        "ari": adjusted_rand_score,
        "nmi": normalized_mutual_info_score,
        "fowlkes_mallows": fowlkes_mallows_score,
        "homogeneity": homogeneity_score,
        "completeness": completeness_score,
        "v_measure": v_measure_score,
    },
    "structure": {
        "silhouette": silhouette_score,
        "davies_bouldin": davies_bouldin_score,
        "calinski_harabasz": calinski_harabasz_score,
    },
}


def safe_structure_score(
    fn: MetricFn, X: pd.DataFrame, labels: pd.Series
) -> SupportsFloat:
    n_labels = labels.nunique(dropna=True)

    if len(labels) < 2 or n_labels < 2:
        return float("nan")
    return fn(X, labels)

def key_path(s):
    key, sep, path = s.partition("=")  # splits on the first "=" only
    if not sep or not key or not path:
        raise argparse.ArgumentTypeError(f"expected key=path, got {s!r}")
    return key, path

def replace_none(obj, value):
    if obj is None:
        return value
    if isinstance(obj, dict):
        return {k: replace_none(v, value) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [replace_none(v, value) for v in obj]
    return obj

def main():
    parser = argparse.ArgumentParser(description="Benchmarking entrypoint")

    # dummy args (old api)
    parser.add_argument("--output_dir", dest="output_dir")
    parser.add_argument("--name", dest="name")
    
    # inputs
    parser.add_argument("--methods_timings", dest="methods_timings", help="timings json path",
                        type=Path, required=True)
    parser.add_argument("--methods_clustering_info", dest="methods_clustering_info",
                        help="clustering info json path", type=Path, required=True)
    parser.add_argument("--methods_clusters", dest="methods_clusters", help="cluster tsv path",
                        type=Path, required=True)
    parser.add_argument("--methods_pca", dest="methods_pca", help="pca tsv path",
                        type=Path, required=True)
    parser.add_argument("--data_clusters_truth", dest="data_clusters_truth",
                        help="clusters_truth tsv path", type=Path, required=True)

    # outputs
    parser.add_argument("--output", type=key_path, action="append", default=[],
                        help="key=pair list of outputs")
    args, _ = parser.parse_known_args()
    outputs = dict(args.output)

    # Logging
    print(f"Full command: {' '.join(sys.argv)}")

    clusters = pd.read_csv(args.methods_clusters, sep="\t")
    pca = pd.read_csv(args.methods_pca, sep="\t")
    truths = pd.read_csv(args.data_clusters_truth, sep="\t").dropna(subset=["truths"])
    merged = clusters.merge(truths, on="cell_id", how="inner")

    # number of cells dropped due to no truth label
    n_dropped_rows = len(clusters) - len(merged)

    truth_labels = merged["truths"]
    leiden_labels = merged["leiden"]
    louvain_labels = merged["louvain"]

    merged_pca = clusters.merge(pca, on="cell_id", how="inner")
    pca_matrix = merged_pca[[c for c in merged_pca.columns if c.startswith("PC")]]

    with open(args.methods_timings, "r") as f:
        timings = json.load(f)

    with open(args.methods_clustering_info) as f:
        clustering_info = json.load(f)

    metrics = {
        "agreement": {
            key: {
                "leiden": fn(truth_labels, leiden_labels),
                "louvain": fn(truth_labels, louvain_labels),
            }
            for key, fn in METRIC_MAP["agreement"].items()
        },
        "structure": {
            key: {
                "leiden": safe_structure_score(fn, pca_matrix, merged_pca["leiden"]),
                "louvain": safe_structure_score(fn, pca_matrix, merged_pca["louvain"]),
            }
            for key, fn in METRIC_MAP["structure"].items()
        },
        "n_clusters": {
            "leiden": clusters["leiden"].nunique(),
            "louvain": clusters["louvain"].nunique(),
        },
        "dropped_cells": n_dropped_rows,
        "timings": timings,
        "clustering_info": clustering_info,
    }

    with open(outputs["metrics_json"], "w") as f:
        json.dump(replace_none(metrics, "NA"), f, indent=2, sort_keys=False)


if __name__ == "__main__":
    main()
