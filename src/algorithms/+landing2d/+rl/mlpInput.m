function X = mlpInput(agent,X)
% MLPINPUT  Actor/Critic MLP 입력의 running 표준화 (planar PPO 공통 구성요소).
% agent.inputNorm이 있으면 (X-mean)/sqrt(var+epsilon)을 [-clip,clip]으로 자릅니다.
% 표준 PPO 구현(SB3 VecNormalize, CleanRL NormalizeObservation)의 관측 정규화와
% 같은 연산이며, 정책 입력 자체(12차원 o_t 또는 같은 o_t의 그래프 특징)는 바꾸지
% 않습니다. 통계는 학습 중 수집한 정책 입력에서만 갱신합니다
% (landing2d.rl.updateInputNorm). 필드가 없으면(3차원 옵션, 이전 체크포인트) 항등입니다.
if ~isfield(agent,'inputNorm') || isempty(agent.inputNorm), return; end
n = agent.inputNorm;
X = (X-n.mean)./sqrt(n.var+n.epsilon);
X = min(max(X,-n.clip),n.clip);
end
