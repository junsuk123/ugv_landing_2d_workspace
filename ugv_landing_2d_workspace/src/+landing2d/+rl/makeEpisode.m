function [r,s] = makeEpisode(c,index,rl,rs,heightRange)
% MAKEEPISODE  학습용 에피소드 초기화. rs가 비면 평가와 같은 공칭 초기 조건.
% 무작위화는 학습에만 사용하고 비교 그림에는 공칭 조건만 사용합니다.
[r,s] = landing2d.simulation.initializeCase(c,index);
if nargin < 4 || isempty(rs)
    return;
end
if nargin < 5 || isempty(heightRange)
    heightRange = rl.initialHeightRange;
end
s.h = min(c.initialHeight*pick(heightRange,rs),c.maxHeight);
s.heightReference = s.h;
if isfield(rl,'initialOffsetFraction') && rl.initialOffsetFraction > 0
    % 시야 반폭에 비례한 초기 오차. 어떤 고도에서 시작해도 패드가 보이므로
    % 낮은 고도에서 시작하는 에피소드가 접지 연습에 쓰일 수 있습니다.
    halfWidth = s.h*tand(c.cameraFovDeg/2);
    s.x = s.x-(2*rand(rs)-1)*rl.initialOffsetFraction*halfWidth;
else
    s.x = s.x-pick(rl.initialOffsetRange,rs);
end
s.vx = s.vx+pick(rl.initialSpeedRange,rs);
end

function value = pick(range,rs)
value = range(1)+(range(2)-range(1))*rand(rs);
end
