function test_segment_background()
% TEST_SEGMENT_BACKGROUND  반투명 패치 범위/색상/높이/범례 비노출 확인.
c = landing2d.config.defaultConfig();
c.animate = false; c.figureVisible = false; c.saveResults = false;
[results,~,~] = landing2d.simulation.initialize(c);
segments = landing2d.scenario.segmentMetadata(results(1),c);
fig = figure('Visible','off');
cleanup = onCleanup(@()close(fig)); %#ok<NASGU>
ax = axes('Parent',fig);
plot(ax,[0,70],[0,2]); xlim(ax,[0,70]); ylim(ax,[-1,3]);
p = landing2d.viz.addSegmentBackground(ax,segments,'time',c);
assert(numel(p) == 3);
for i = 1:3
    assert(abs(p(i).FaceAlpha-c.segmentAlpha) < 1e-12);
    assert(isequal(p(i).FaceColor,c.segmentColors(i,:)));
    assert(strcmp(p(i).HandleVisibility,'off'));
    % patch의 XData/YData는 열 벡터이므로 방향을 맞춰 비교.
    assert(isequal(p(i).XData(:)',[segments(i).tStart,segments(i).tEnd, ...
        segments(i).tEnd,segments(i).tStart]));
end
ylim(ax,[-5,10]); drawnow;
assert(isequal(p(1).YData(:)',[-5,-5,10,10]));
end
