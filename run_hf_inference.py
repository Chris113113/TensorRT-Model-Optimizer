"""An example script to run the tensorrt_llm engine."""

import argparse

import torch
from example_utils import get_tokenizer
from transformers import AutoModelForCausalLM, PreTrainedTokenizerBase

from tensorrt_llm._torch import LLM as TRTLLM
from tensorrt_llm.sampling_params import SamplingParams


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tokenizer", type=str, default="")
    parser.add_argument("--max_output_len", type=int, default=100)
    parser.add_argument("--engine_dir", type=str, default="/tmp/modelopt")
    parser.add_argument(
        "--input_texts",
        type=str,
        default=(
            "Born in north-east France, Soyer trained as a|Born in California, Soyer trained as a"
        ),
        help="Input texts. Please use | to separate different batches.",
    )
    parser.add_argument(
        "--trust_remote_code",
        help="Set trust_remote_code for Huggingface models and tokenizers",
        default=False,
        action="store_true",
    )

    return parser.parse_args()


def run(args):
    if not args.tokenizer:
        # Assume the tokenizer files are saved in the engine_dr.
        args.tokenizer = args.engine_dir

    if isinstance(args.tokenizer, PreTrainedTokenizerBase):
        tokenizer = args.tokenizer
    else:
        tokenizer = get_tokenizer(
            ckpt_path=args.tokenizer, trust_remote_code=args.trust_remote_code
        )

    with open("long_input.txt", "r") as f:
        input_texts = [f.read()]

    free_memory_before = torch.cuda.mem_get_info()

    print("TensorRT-LLM example outputs:")
    sampling_params = SamplingParams(max_tokens=args.max_output_len)

    # Load the Hugging Face model

    # Create the TRTLLM object from the Hugging Face model
    llm = TRTLLM(model=args.engine_dir, tokenizer=tokenizer)
    torch.cuda.cudart().cudaProfilerStart()
    outputs = llm.generate(input_texts, sampling_params)
    torch.cuda.cudart().cudaProfilerStop()

    free_memory_after = torch.cuda.mem_get_info()
    print(
        f"Use GPU memory: {(free_memory_before[0] - free_memory_after[0]) / 1024 / 1024 / 1024} GB"
    )
    print(f"Generated outputs: {outputs}")


if __name__ == "__main__":
    args = parse_arguments()
    run(args)
