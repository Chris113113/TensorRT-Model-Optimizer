#!/bin/bash

set -e

# --- Configuration ---
MODEL_NAME=$1
SOURCE_DIR=$2
QUANT_FORMAT=${3:-"fp8"} # Defaults to "fp8" if not provided
PROMPT=${4:-"What is the capital of France?"}
EXPORT_FORMAT=${5:-"tensorrt_llm"} # "tensorrt_llm" or "hf"
TENSOR_PARALLEL=${6:-1}         # Number of GPUs for tensor parallelism, defaults to 1

# --- Script Body ---
if [ -z "$MODEL_NAME" ] || [ -z "$SOURCE_DIR" ]; then
  echo "Usage: $0 <model-name> <source-directory> [quantization-format] [\"prompt\"] [export-format] [tensor-parallel-size]"
  echo "Example: $0 meta-llama/Llama-3.1-8B-Instruct /mnt/disks/mlperf-scratch nvfp4 \"Hello, how are you?\" hf 2"
  exit 1
fi

# Construct the path to the model directory
MODEL_DIR_NAME="models--$(echo "$MODEL_NAME" | sed 's#/#--#g')"
MODEL_PATH="$SOURCE_DIR/$MODEL_DIR_NAME"

if [ ! -d "$MODEL_PATH" ]; then
  echo "Error: Model directory not found at $MODEL_PATH"
  exit 1
fi

# Find the snapshot directory
SNAPSHOT_DIR=$(find "$MODEL_PATH/snapshots" -mindepth 1 -maxdepth 1 -type d | head -n 1)

if [ -z "$SNAPSHOT_DIR" ]; then
  echo "Error: Snapshot directory not found in $MODEL_PATH/snapshots"
  exit 1
fi

echo "Found snapshot directory: $SNAPSHOT_DIR"

# Define the output directory for the quantized model
OUTPUT_DIR="$SOURCE_DIR/quantized_models"
mkdir -p "$OUTPUT_DIR"

echo "Quantizing $MODEL_NAME to $QUANT_FORMAT with TP=$TENSOR_PARALLEL..."

# Run the quantization command in the Docker container
docker run --rm --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
  -v "$SOURCE_DIR:$SOURCE_DIR" \
  modelopt_examples \
  bash -c "
    export HF_PATH=$SNAPSHOT_DIR && \
    export ROOT_SAVE_PATH=$OUTPUT_DIR && \
    cd /workspace/TensorRT-Model-Optimizer/examples/llm_ptq/ && \
    scripts/huggingface_example.sh \
      --model \$HF_PATH \
      --quant $QUANT_FORMAT \
      --tp $TENSOR_PARALLEL \
      --export_fmt $EXPORT_FORMAT
  "

echo "Quantization complete."

# Rename the output directory for clarity
LATEST_DIR=$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
if [ -z "$LATEST_DIR" ]; then
    echo "Error: Could not find any recently created model directory in $OUTPUT_DIR"
    exit 1
fi

RENAMED_DIR="$OUTPUT_DIR/$(echo "$MODEL_NAME" | sed 's#/#--#g')_${QUANT_FORMAT}_tp${TENSOR_PARALLEL}"
if [ -d "$RENAMED_DIR" ]; then
    echo "Removing existing directory: $RENAMED_DIR"
    sudo rm -rf "$RENAMED_DIR"
fi
mv "$LATEST_DIR" "$RENAMED_DIR"
echo "Renamed output directory to $RENAMED_DIR"

if [ "$EXPORT_FORMAT" = "hf" ]; then
  echo "Copying original config.json for HF export..."
  sudo cp "$SNAPSHOT_DIR/config.json" "$RENAMED_DIR/config.json"
  echo "Copied config.json to $RENAMED_DIR"
fi



# --- Conditional Inference Test ---
if [ "$EXPORT_FORMAT" = "tensorrt_llm" ]; then
    echo "---"
    echo "Running inference test for TensorRT-LLM engine..."

    ENGINE_DIR=$(find "$RENAMED_DIR" -type d -name "*_engine" | head -n 1)
    if [ -z "$ENGINE_DIR" ] || [ ! -d "$ENGINE_DIR" ]; then
      echo "Error: Could not find the engine directory in $RENAMED_DIR"
      exit 1
    fi
    echo "Found engine directory: $ENGINE_DIR"

    # Run the inference command for the TRT-LLM engine
    docker run --rm --gpus all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 \
      -v "$SOURCE_DIR:$SOURCE_DIR" \
      modelopt_examples:hf \
      python "/workspace/TensorRT-Model-Optimizer/examples/llm_ptq/run_tensorrt_llm.py" \
        --engine_dir "$ENGINE_DIR" \
        --tokenizer "$SNAPSHOT_DIR" \
        --input_texts "$PROMPT"

    echo "---"
    echo "Inference test complete."
else
    echo "---"
    echo "Skipping separate inference test for HF export (already tested internally)."
    echo "---"
fi