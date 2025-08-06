#!/bin/bash
mkdir -p /mnt/disks/mlperf-scratch/quantized_models/tensorrt-llm
rm -rf /mnt/disks/mlperf-scratch/quantized_models/tensorrt-llm/meta-llama*
mv /mnt/disks/mlperf-scratch/quantized_models/meta-llama* /mnt/disks/mlperf-scratch/quantized_models/tensorrt-llm/