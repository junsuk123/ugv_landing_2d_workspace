function value = predictValue(agent,state)
% PREDICTVALUE  강화학습 에이전트의 가치망 출력. 온톨로지의 PolicyValue 노드에 사용.
value = landing2d.rl.valueForward(agent,state);
end
