#!/bin/bash

set -e

BASE_DIR="/mnt/disks/mlperf-scratch/quantized_models"

echo "Scanning for quantized models in: $BASE_DIR"
echo "--------------------------------------------------"

# Loop through each subdirectory in the base directory
for MODEL_DIR in "$BASE_DIR"/*/; do
  if [ -d "$MODEL_DIR" ]; then
    FORMAT="Unknown or incomplete"
    # Check for .engine files for TensorRT-LLM format
    if [ -n "$(find "$MODEL_DIR" -name '*.engine' -print -quit)" ]; then
      FORMAT="TensorRT-LLM"
    # Check for .safetensors files for Hugging Face format
    elif [ -n "$(find "$MODEL_DIR" -name '*.safetensors' -print -quit)" ]; then
      FORMAT="Hugging Face"
    fi
    printf "%-80s %s\n" "$(basename "$MODEL_DIR")" "$FORMAT"
  fi
done