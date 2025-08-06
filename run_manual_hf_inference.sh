#!/bin/bash

set -euo pipefail

# Check if a model name is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <model_name>"
    echo "Example: $0 mistralai--Mixtral-8x7B-v0.1_fp8_tp1"
    exit 1
fi

MODEL_NAME=$1
# The base directory where quantized models are stored.
# This path is the same on the host and inside the Docker container thanks to the -v mount.
QUANTIZED_MODELS_BASE_DIR="/mnt/disks/mlperf-scratch/quantized_models"
ENGINE_DIR="${QUANTIZED_MODELS_BASE_DIR}/${MODEL_NAME}"

# Check if the model directory exists
if [ ! -d "${ENGINE_DIR}" ]; then
    echo "Error: Model directory not found at ${ENGINE_DIR}"
    exit 1
fi

# The root of the project inside the Docker container
PROJECT_ROOT_IN_DOCKER="/workspace/TensorRT-Model-Optimizer"
INFERENCE_SCRIPT_PATH="${PROJECT_ROOT_IN_DOCKER}/examples/llm_ptq/run_hf_inference.py"

echo "Starting inference for model: ${MODEL_NAME}"
echo "Engine directory: ${ENGINE_DIR}"

# Run the inference in a Docker container
# The project directory is mounted to /workspace/TensorRT-Model-Optimizer in the container
docker run --rm --gpus all \
    -v "/mnt/disks/mlperf-scratch:/mnt/disks/mlperf-scratch" \
    modelopt_examples:hf \
    python "${INFERENCE_SCRIPT_PATH}" \
    --engine_dir "${ENGINE_DIR}" \
    --max_output_len 1024

echo "Inference finished for model: ${MODEL_NAME}"
