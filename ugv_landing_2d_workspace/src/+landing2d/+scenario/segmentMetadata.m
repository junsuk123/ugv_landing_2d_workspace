function segments = segmentMetadata(r, c)
% SEGMENTMETADATA  시간 구간과 해당 시각의 UGV 위치를 한 곳에서 계산.
% x-z 배경은 UGV 위치 기준이며 드론의 시간 구간 경계와 다를 수 있음.
edges = [r.time(1), reshape(c.segmentTimes,1,[]), r.time(end)];
xEdges = interp1(r.time, r.xUgv, edges, 'linear');
blank = struct('id',0,'tStart',0,'tEnd',0,'xStart',0,'xEnd',0, ...
    'targetSpeed',0,'color',[0,0,0],'label','');
segments = repmat(blank,1,3);
for i = 1:3
    segments(i).id = i;
    segments(i).tStart = edges(i);
    segments(i).tEnd = edges(i+1);
    segments(i).xStart = xEdges(i);
    segments(i).xEnd = xEdges(i+1);
    segments(i).targetSpeed = r.speeds(i);
    segments(i).color = c.segmentColors(i,:);
    segments(i).label = sprintf('S%d\n%.2g m/s', i, r.speeds(i));
end
end
