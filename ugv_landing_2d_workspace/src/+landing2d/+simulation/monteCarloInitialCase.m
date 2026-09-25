function [r,s] = monteCarloInitialCase(c,index,rs)
% MONTECARLOINITIALCASE  비교군이 공통으로 쓰는 평가용 무작위 초기조건.
[r,s] = landing2d.simulation.initializeCase(c,index);
s.h = min(c.initialHeight*pick(c.evaluationHeightRange,rs),c.maxHeight);
s.heightReference = s.h;
s.x = s.x-pick(c.evaluationOffsetRange,rs);
s.vx = s.vx+pick(c.evaluationSpeedRange,rs);
end

function value = pick(range,rs)
value = range(1)+(range(2)-range(1))*rand(rs);
end
