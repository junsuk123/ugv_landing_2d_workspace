# Relational policy representation for UGV landing (2D, MATLAB)

Three PPO policies are compared in a planar x–z landing task on a constant-velocity or accelerating UGV. They share the 12-D common observation, the reward (reward_v5), the PPO loss, budget and parameter count (6,101). Only the Actor/Critic state representation differs:

- `ppo`: the 12-D observation → MLP
- `onto_rgat_ppo`: the TOSM 7-node graph of the same observation → input-dependent R-GAT → MLP
- `shuffled_rgat_ppo`: the same with the semantic relation types permuted (control)

The question is whether the relational inductive bias improves learning efficiency, generalization outside the training ranges, and the response to marker dropout and UGV acceleration. It is not about expressive power: the graph is a deterministic function of the observation and adds no information. The design is described in `docs/EXPERIMENT_DESIGN_KO.md` (Korean).

```matlab
run_check                    % self-test + bounded smoke of every stage
run_check('learnability')    % pre-check: can plain PPO learn the easy corner?
run                          % 3 methods x training seeds 1-5: train, evaluate, figures
run_scenario('S4')           % one controlled case (needs trained checkpoints)
```

All summaries are means and 95% t intervals over training seeds. Method contrasts are paired by training seed. Outputs go to `results/` (checkpoints, evaluation CSV/MAT, figures).
