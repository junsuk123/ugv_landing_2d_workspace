function range = curriculumRange(rl,iteration)
% CURRICULUMRANGE  학습 진행도에 따른 초기 고도 배율 범위.
%
% 처음부터 학습하는 정책은 하강 도중 시야가 좁아지며 쌓이는 포착 벌점을 통과해야
% 착륙에 닿습니다. 포착 가중치가 클수록 이 골짜기가 깊어 무작위 정책이 건너지
% 못합니다. 실제로 배분 0.30 이상에서는 2500회를 돌려도 착륙이 나오지 않았고,
% 그런데도 착륙 정책을 같은 보상으로 채점하면 점수가 훨씬 높습니다.
% 즉 착륙은 최적해인데 탐색이 닿지 못하는 상태였습니다.
%
% 그래서 낮은 고도에서 시작해 접지를 먼저 익히게 하고, 학습이 진행되면서 출발
% 고도를 공칭 조건까지 넓힙니다. 교사 시연을 쓰지 않으므로 처음부터 학습한다는
% 조건은 그대로입니다. 평가는 언제나 공칭 초기 조건이라 비교에는 영향이 없습니다.
range = rl.initialHeightRange;
if rl.curriculumFraction <= 0
    return;
end
span = max(1,round(rl.curriculumFraction*rl.ppoIterations));
progress = min(max((iteration-1)/span,0),1);
high = rl.curriculumStartHeight+(range(2)-rl.curriculumStartHeight)*progress;
range(2) = max(high,range(1));
end
