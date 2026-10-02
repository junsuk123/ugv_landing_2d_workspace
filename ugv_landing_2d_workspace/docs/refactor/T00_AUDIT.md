# T00 workspace audit

- Source repository: `C:\Users\user\Downloads\ugv_landing_2d_workspace`
- Isolated worktree: `C:\Users\user\Downloads\ugv_landing_2d_workspace_planar_visibility_v2`
- Branch: `codex/planar-visibility-ppo-v2`
- Starting HEAD: `385e993aeda747db490f53c791934dc871029e2a`
- Request artifact: `C:\Users\user\Downloads\ugv_landing_refactor_prompt_en.json`
- Baseline command: `run_tests(false)`
- Baseline result before edits: 19/19 passed.

No active writer or repository lock was found for this worktree. Existing MATLAB
and Claude processes were not terminated. The original working tree and
`tests/reference` are not modified by this refactor.

The `planar_visibility_v2` experiment supersedes only the old fixed-speed pad,
nadir-only/double-integrator primary model, legacy ontology schema, 11-D packet,
two-term reward, and imitation-learning defaults. Legacy behavior remains an
explicit compatibility path.
