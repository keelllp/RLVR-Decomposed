#!/bin/bash
# run_pipeline.sh
# Automated script to run all training sessions followed by evaluations

set -e # Stop execution if any command fails

# Define directories
CKPT_DIR="./checkpoints"
EVAL_DIR="./eval_outputs"

mkdir -p "$CKPT_DIR"
mkdir -p "$EVAL_DIR"

# List of all available training scripts
declare -a SCRIPTS=(
  "run_qwen2.5-math-7b_grpo.sh"
  "run_qwen2.5-math-7b_ppo.sh"
  "run_qwen2.5-math-7b_psr_nsr.sh"
  "run_qwen3-4b_grpo.sh"
  "run_qwen3-4b_ppo.sh"
  "run_qwen3-4b_psr_nsr.sh"
)

echo "Starting Multi-Model Training and Evaluation Pipeline..."

# 1. Training Phase
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        exp_name="${script%.*}"
        echo "=========================================================="
        echo "🚀 TRAINING: $exp_name"
        echo "=========================================================="
        
        # We pass trainer.default_local_dir to control precisely where the checkpoint is saved
        bash "$script" trainer.default_local_dir="$CKPT_DIR/$exp_name"
    else
        echo "⚠️  WARNING: Script $script not found. Skipping."
    fi
done

# 2. Evaluation Phase
echo "=========================================================="
echo "🎯 ALL TRAINING COMPLETED. STARTING EVALUATION."
echo "=========================================================="

# Read the generated checkpoints and run evaluations automatically
for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        exp_name="${script%.*}"
        model_ckpt_base="$CKPT_DIR/$exp_name"
        
        if [ -d "$model_ckpt_base" ]; then
            # Find all sub-directories containing a 'config.json' (which denotes a valid HF checkpoint)
            checkpoint_dirs=$(find "$model_ckpt_base" -maxdepth 4 -name "config.json" -exec dirname {} \;)
            
            for ckpt in $checkpoint_dirs; do
                ckpt_basename=$(basename "$ckpt")
                out_dir="$EVAL_DIR/${exp_name}_${ckpt_basename}"
                mkdir -p "$out_dir"
                
                echo "----------------------------------------------------------"
                echo "🔎 EVALUATING CHECKPOINT: $ckpt"
                echo "   Outputting inferences to: $out_dir"
                echo "----------------------------------------------------------"
                
                # Execute the original evaluation parameters but dynamically replacing MODEL_PATH
                python eval.py \
                  --model_name="$ckpt" \
                  --datasets="TianHongZXY/AIME2025,TianHongZXY/amc23,TianHongZXY/MATH" \
                  --split="test" \
                  --output_dir="$out_dir" \
                  --batch_size=1000 \
                  --max_tokens=4096 \
                  --num_gpus=2 \
                  --temperature=0.6 \
                  --top_p=0.95 \
                  --num_generation=256
                  
                echo "📊 CALCULATING METRICS FOR: $ckpt"
                # Search for all the generated JSONL answers and compute unbiased Pass@k
                for jsonl_file in "$out_dir"/*.jsonl; do
                    if [ -f "$jsonl_file" ]; then
                        echo "Metrics for $jsonl_file:"
                        python calculate_metrics.py --file_path "$jsonl_file"
                    fi
                done
            done
        else
            echo "⚠️  WARNING: Checkpoint directory not found for $exp_name. Skipping evaluation."
        fi
    fi
done

echo "=========================================================="
echo "🎉 ALL PIPELINE TASKS COMPLETED SUCCESSFULLY!"
echo "=========================================================="
