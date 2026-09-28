function test_agent_comparison_replay()
% TEST_AGENT_COMPARISON_REPLAY  Three agents share one fixed-bounds tab.
c = landing2d.config.defaultConfig();
c.tEnd = 0.4;
c.segmentTimes = [0.1,0.3];
c.scenarioSpeeds = [1,2,1];
c.animate = false;
c.figureVisible = false;
c.saveResults = false;
c.playbackSpeed = Inf;
r = landing2d.simulation.run(c);
runs = struct('results',{r,r,r}, ...
    'label',{'PN guidance','PPO RL','Ontology-RGAT RL'});
fig = landing2d.viz.replayAgentComparison(runs,c);
cleanup = onCleanup(@()close(fig)); %#ok<NASGU>
assert(isgraphics(fig));
tabs = findobj(fig,'Type','uitab');
axesList = findobj(fig,'Type','axes');
assert(numel(tabs) == 1 && numel(axesList) == 1);
assert(strcmp(axesList.XLimMode,'manual') ...
    && strcmp(axesList.YLimMode,'manual'));
speedBands = findall(axesList,'Type','patch', ...
    'Tag','Landing2dSegmentBackground');
assert(numel(speedBands) == 3);
trails = findobj(axesList,'Type','line','-regexp','DisplayName','RL|guidance');
assert(numel(trails) == 3);
end
