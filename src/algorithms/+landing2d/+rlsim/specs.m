function [obsInfo,actInfo] = specs(c,stateDim)
% SPECS  RL Toolbox 관측·행동 명세. 행동은 tanh 이전의 무한계 명령 u입니다.
% 환경은 aNorm = tanh(u)로 정규화하고 가속도 한계를 곱합니다(environment.step).
obsInfo = rlNumericSpec([stateDim 1]);
obsInfo.Name = 'observation';
obsInfo.Description = sprintf('%s policy state',c.graphState.stateRepresentation);
actInfo = rlNumericSpec([c.rl.actionDim 1]);
actInfo.Name = 'u';
actInfo.Description = 'pre-tanh horizontal/vertical acceleration command';
end
