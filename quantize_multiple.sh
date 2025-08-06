#!/bin/bash

# --- Log file setup ---
LOG_FILE="quantization_results.log"
echo "Starting quantization run. Results will be logged to $LOG_FILE"
echo "--- Quantization Log: $(date) ---" > "$LOG_FILE"
echo "" >> "$LOG_FILE"


# An array of models to quantize. Each element is a string with parameters separated by semicolons.
# Format: "MODEL_NAME;SOURCE_DIR;QUANT_FORMAT;EXPORT_FORMAT;TENSOR_PARALLEL"
MODELS_TO_QUANTIZE=(
  "mistralai/Mixtral-8x7B-Instruct-v0.1;/mnt/disks/mlperf-scratch;fp8;hf;1"
  "mistralai/Mixtral-8x7B-Instruct-v0.1;/mnt/disks/mlperf-scratch;nvfp4;hf;1"
  #"meta-llama/Llama-3.1-8B-Instruct;/mnt/disks/mlperf-scratch;fp8;hf;1"
  #"meta-llama/Llama-3.1-8B-Instruct;/mnt/disks/mlperf-scratch;nvfp4;hf;1"
  #"Qwen/Qwen3-4B;/mnt/disks/mlperf-scratch;nvfp4;hf;1"
  #"Qwen/Qwen3-4B;/mnt/disks/mlperf-scratch;fp8;hf;1"
  #"Qwen/Qwen3-32B;/mnt/disks/mlperf-scratch;nvfp4;hf;1"
  #"Qwen/Qwen3-32B;/mnt/disks/mlperf-scratch;fp8;hf;1"
  #"meta-llama/Llama-3.3-70B-Instruct;/mnt/disks/mlperf-scratch;nvfp4;tensorrt_llm;1"
  #"meta-llama/Llama-3.3-70B-Instruct;/mnt/disks/mlperf-scratch;fp8;tensorrt_llm;1"
  #"mistralai/Mixtral-8x7B-v0.1;/mnt/disks/mlperf-scratch;fp8;tensorrt_llm;1"
  #"mistralai/Mixtral-8x7B-v0.1;/mnt/disks/mlperf-scratch;nvfp4;tensorrt_llm;1"
  #"mistralai/Mixtral-8x7B-v0.1;/mnt/disks/mlperf-scratch;fp8;hf;1"
  #"mistralai/Mixtral-8x7B-v0.1;/mnt/disks/mlperf-scratch;nvfp4;hf;1"
)

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Loop through the array and call the quantization script for each model
for model_config in "${MODELS_TO_QUANTIZE[@]}"; do
  IFS=';' read -r -a params <<< "$model_config"

  MODEL_NAME="${params[0]}"
  SOURCE_DIR="${params[1]}"
  QUANT_FORMAT="${params[2]}"
  EXPORT_FORMAT="${params[3]}"
  TENSOR_PARALLEL="${params[4]}"

  # Construct the expected path for the quantized model
  RENAMED_DIR_BASENAME="$(echo "$MODEL_NAME" | sed 's#/#--#g')_${QUANT_FORMAT}_tp${TENSOR_PARALLEL}"
  QUANTIZED_MODEL_PATH="$SOURCE_DIR/quantized_models/$RENAMED_DIR_BASENAME"

  echo "================================================================="
  echo "Starting quantization for: $MODEL_NAME"
  echo "================================================================="

  # Run the quantization script and check its exit code
  if "$SCRIPT_DIR/quantize_model.sh" "$MODEL_NAME" "$SOURCE_DIR" "$QUANT_FORMAT" "" "$EXPORT_FORMAT" "$TENSOR_PARALLEL"; then
    echo "SUCCESS: $MODEL_NAME ($QUANT_FORMAT, $EXPORT_FORMAT, TP=$TENSOR_PARALLEL) - Path: $QUANTIZED_MODEL_PATH" >> "$LOG_FILE"
  else
    echo "FAILURE: $MODEL_NAME ($QUANT_FORMAT, $EXPORT_FORMAT, TP=$TENSOR_PARALLEL) - Path: $QUANTIZED_MODEL_PATH" >> "$LOG_FILE"
  fi

  echo "================================================================="
  echo "Finished quantization for: $MODEL_NAME"
  echo "================================================================="
  echo
done

echo "================================================================="
echo "All quantization tasks are complete."
echo "Summary of results:"
echo "--------------------------------------------------"
cat "$LOG_FILE"
echo "--------------------------------------------------"
echo "Full logs are available in the standard output."
