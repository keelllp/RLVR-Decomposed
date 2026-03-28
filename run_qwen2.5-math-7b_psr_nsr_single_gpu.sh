export RAY_DEDUP_LOGS=0

# ======================
# DATA PATHS
# ======================
math_train_path=./data/math/train.parquet
math_test_path=./data/math/test.parquet
aime2025_test_path=./data/aime2025/test.parquet
amc23_test_path=./data/amc23/test.parquet

train_files="['$math_train_path']"
test_files="['$math_test_path', '$aime2025_test_path', '$amc23_test_path']"

# ======================
# TRAINING SETTINGS
# ======================
advantage="positive"   # PSR
# advantage="negative"  # NSR

kl_coef=0.0
lr=1e-6

# 🔥 SMALL MODEL (same architecture family)
model_name=Qwen/Qwen2.5-Math-1.5B

python3 -m verl.trainer.main_ppo \
    algorithm.adv_estimator=psr_nsr \
    algorithm.advantage=$advantage \
    
    # ======================
    # DATA
    # ======================
    data.train_files="$train_files" \
    data.val_files="$test_files" \
    data.train_batch_size=2 \
    
    data.max_prompt_length=256 \
    data.max_response_length=512 \
    
    data.filter_overlong_prompts=True \
    data.truncation='error' \
    
    # ======================
    # MODEL
    # ======================
    actor_rollout_ref.model.path=$model_name \
    actor_rollout_ref.actor.optim.lr=$lr \
    
    actor_rollout_ref.model.enable_gradient_checkpointing=True \
    actor_rollout_ref.model.use_remove_padding=False \
    
    # ======================
    # PPO SETTINGS (UNCHANGED LOGIC)
    # ======================
    actor_rollout_ref.actor.use_dynamic_bsz=True \
    actor_rollout_ref.actor.ppo_max_token_len_per_gpu=2048 \
    
    actor_rollout_ref.actor.ppo_mini_batch_size=2 \
    
    # ======================
    # ROLLOUT (NO vLLM)
    # ======================
    actor_rollout_ref.rollout.name=hf \
    actor_rollout_ref.rollout.n=1 \
    actor_rollout_ref.rollout.temperature=1.0 \
    
    actor_rollout_ref.rollout.log_prob_max_token_len_per_gpu=2048 \
    actor_rollout_ref.ref.log_prob_max_token_len_per_gpu=2048 \
    
    # ======================
    # DISABLE HEAVY FSDP
    # ======================
    actor_rollout_ref.actor.fsdp_config.param_offload=False \
    actor_rollout_ref.actor.fsdp_config.optimizer_offload=False \
    
    actor_rollout_ref.ref.fsdp_config.param_offload=False \
    
    # ======================
    # TRAINER
    # ======================
    trainer.experiment_name="colab-psr-nsr-run" \
    
    algorithm.kl_ctrl.kl_coef=$kl_coef \
    
    trainer.critic_warmup=0 \
    
    trainer.logger=[] \
    trainer.project_name='verl' \
    
    trainer.n_gpus_per_node=1 \
    trainer.nnodes=1 \
    
    trainer.total_epochs=1 \
    
    trainer.save_freq=1000 \
    trainer.test_freq=1000 \
    
    +trainer.val_before_train=True