function value = predictValue(agent,state)
% PREDICTVALUE  강화학습 에이전트의 가치망 출력. 온톨로지의 PolicyValue 노드에 사용.
% 부호기를 넣은 뒤에는 agent.value가 구조체이므로 landing2d.rl.valueForward로 돌립니다.
value = landing2d.rl.valueForward(agent,state);
end
