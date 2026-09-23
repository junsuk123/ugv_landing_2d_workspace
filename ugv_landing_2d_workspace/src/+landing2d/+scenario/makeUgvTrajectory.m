function [x, v, vCommand] = makeUgvTrajectory(t, speeds, c)
vCommand = speeds(1) + zeros(size(t));
vCommand(t >= c.segmentTimes(1)) = speeds(2);
vCommand(t >= c.segmentTimes(2)) = speeds(3);
x = zeros(size(t));
v = zeros(size(t));
v(1) = speeds(1);
for k = 1:numel(t)-1
    % 구간 내부는 등속, 구간 경계에서는 유한한 가속도로 목표 속도에 도달.
    dv = landing2d.util.saturate(vCommand(k) - v(k), c.ugvAccelMax * c.dt);
    v(k+1) = v(k) + dv;
    x(k+1) = x(k) + 0.5 * (v(k) + v(k+1)) * c.dt;
end
end
