# How to Run Batch Quantization with `quantize_multiple.sh`

This guide provides step-by-step instructions on how to use the `quantize_multiple.sh` script to quantize multiple Hugging Face language models from scratch.

## Prerequisites

Before you begin, ensure you have the following installed and configured:

1.  **Docker:** The script relies on Docker to create a containerized environment with all necessary dependencies. You must also have the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed to enable GPU access within Docker containers.
2.  **`huggingface-cli`:** You need the Hugging Face command-line interface to download the models you intend to quantize. Make sure you are logged in with `huggingface-cli login`.
3.  **A Models Directory:** Create a directory on your system where you will download the source models and store the quantized outputs. In this guide, we will use `/mnt/disks/mlperf-scratch` as an example.
4.  **`gsutil`:** If you plan to upload your models to Google Cloud Storage, you will need the `gsutil` tool installed and configured.

---

## Step 1: Build the Docker Images

The quantization process requires two Docker images: `modelopt_examples:latest` for TensorRT-LLM exports and `modelopt_examples:hf` for Hugging Face exports.

Navigate to the `docker` directory and run the `build.sh` script for each Dockerfile:

```bash
cd docker

# Build the base image for TensorRT-LLM
bash build.sh --dockerfile Dockerfile

# Build the image for Hugging Face exports
bash build.sh --dockerfile Dockerfile.hf

cd ..
```

---

## Step 2: Download a Model

Use `huggingface-cli` to download the models you wish to quantize. The script expects the models to be in a subdirectory named `models--<organization>--<model-name>`.

For example, to download `meta-llama/Meta-Llama-3-70B`:

```bash
# Define your source directory
export MODEL_DIR="/mnt/disks/mlperf-scratch"
mkdir -p "${MODEL_DIR}"

# Download the model snapshot
huggingface-cli download meta-llama/Meta-Llama-3-70B \
  --local-dir "${MODEL_DIR}/models--meta-llama--Meta-Llama-3-70B" \
  --local-dir-use-symlinks False
```

Repeat this process for all the models you want to quantize.

---

## Step 3: Configure the Quantization Script

Open the `quantize_multiple.sh` script in a text editor. The script is configured through the `MODELS_TO_QUANTIZE` bash array.

Each entry in the array is a string with five parameters separated by semicolons (`;`).

**Format:**

```
"MODEL_NAME;SOURCE_DIR;QUANT_FORMAT;EXPORT_FORMAT;TENSOR_PARALLEL"
```

*   **`MODEL_NAME`**: The name of the model on the Hugging Face Hub (e.g., `meta-llama/Meta-Llama-3-70B`).
*   **`SOURCE_DIR`**: The base directory where your `models--...` folders are located (e.g., `/mnt/disks/mlperf-scratch`).
*   **`QUANT_FORMAT`**: The quantization format. Can be `fp8` or `nvfp4`.
*   **`EXPORT_FORMAT`**: The export format. Can be `tensorrt_llm` or `hf`.
*   **`TENSOR_PARALLEL`**: The number of GPUs to use for tensor parallelism.

**Example Configuration:**

To quantize `meta-llama/Meta-Llama-3-70B` to both `fp8` and `nvfp4` in the Hugging Face (`hf`) format, your `MODELS_TO_QUANTIZE` array would look like this:

```bash
MODELS_TO_QUANTIZE=(
  "meta-llama/Meta-Llama-3-70B;/mnt/disks/mlperf-scratch;fp8;hf;1"
  "meta-llama/Meta-Llama-3-70B;/mnt/disks/mlperf-scratch;nvfp4;hf;1"
)
```

Make sure to uncomment the lines for the models you wish to process.

---

## Step 4: Run the Script

Execute the script from the root of the repository:

```bash
bash quantize_multiple.sh
```

The script will loop through each entry in the `MODELS_TO_QUANTIZE` array and run the `quantize_model.sh` script for each configuration.

---

## Step 5: Check the Results

The quantized models will be saved in the `<SOURCE_DIR>/quantized_models/` directory. Each model will have a descriptive name, such as `meta-llama--Meta-Llama-3-70B_nvfp4_tp1`.

A log file named `quantization_results.log` will be created in the root of the repository, summarizing the outcome (SUCCESS or FAILURE) for each quantization task.

---

## Step 6: Upload to Google Cloud Storage (Optional)

After quantization, you can upload the model directories to a Google Cloud Storage bucket using the `gsutil` command-line tool.

The `-m` flag enables parallel uploads, which is recommended for large directories.

**Command Format:**

```bash
gsutil -m cp -r <LOCAL_MODEL_PATH> gs://<YOUR_BUCKET_NAME>/<DESTINATION_PATH>/
```

**Example:**

This command uploads the `meta-llama--Meta-Llama-3-70B_nvfp4_tp1` model to the `gs://pirillo-sct-bucket/quantized_models/` bucket and path.

```bash
gsutil -m cp -r /mnt/disks/mlperf-scratch/quantized_models/meta-llama--Meta-Llama-3-70B_nvfp4_tp1/ gs://pirillo-sct-bucket/quantized_models/
```