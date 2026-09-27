function test_monte_carlo_evaluation()
% TEST_MONTE_CARLO_EVALUATION  공통 시드, 평균, 분산 요약의 재현성 확인.
c = landing2d.config.defaultConfig();
c.tEnd = 1;
c.segmentTimes = [0.3,0.7];
c.scenarioSpeeds = [1,2,1];
c.animate = false;
c.figureVisible = false;
c.evaluationMonteCarloRuns = 4;
landing2d.config.validateConfig(c);

a = landing2d.simulation.evaluateMonteCarlo(c,'PN guidance');
b = landing2d.simulation.evaluateMonteCarlo(c,'PN guidance');
assert(a.nRuns == 4 && isequal(a.meanX,b.meanX) && isequal(a.meanZ,b.meanZ), ...
    '같은 평가 시드는 같은 평균 궤적을 만들어야 합니다.');
assert(isequal(a.varX,b.varX) && isequal(a.varZ,b.varZ), ...
    '같은 평가 시드는 같은 분산 궤적을 만들어야 합니다.');
assert(all(a.varX >= 0) && all(a.varZ >= 0));
assert(any(a.varX > 0) && any(a.varZ > 0), ...
    '무작위 초기조건 평가의 궤적 분산이 모두 0이면 안 됩니다.');
assert(isfield(a,'eventMean') && isfield(a,'eventVariance') ...
    && size(a.eventSamples,2) == c.evaluationMonteCarloRuns);
assert(all(a.eventVariance(isfinite(a.eventVariance)) >= 0));
assert(isfield(a,'activeCount') && isfield(a,'terminalCount') ...
    && all(diff(a.activeCount) <= 0) ...
    && all(a.activeCount+a.terminalCount == a.nRuns), ...
    'Monte Carlo trajectory moments must explicitly exclude terminal samples.');
c.saveResults = false;
fig = landing2d.viz.plotMonteCarloComparison(struct('guidance',a),c);
cleanup = onCleanup(@()close(fig)); %#ok<NASGU>
assert(isgraphics(fig));

% R-GAT summaries must carry learned layer-2 edge attention, and the new
% surface/matrix view must render directly from those measured quantities.
gc = landing2d.graphstate.applyStateRepresentation(c,'ontology_rgat');
gc.evaluationMonteCarloRuns = 2;
rs = RandStream('threefry','Seed',19);
agent = landing2d.rl.agentInit(gc.rl,rs,gc.graphState);
g = landing2d.rl.evaluateMonteCarlo(agent,gc,'Ontology R-GAT');
assert(isfield(g,'edgeAttentionMean') ...
    && numel(g.edgeAttentionMean) == numel(g.graphSchema.src));
assert(all(isfinite(g.edgeAttentionMean)) ...
    && all(g.edgeAttentionMean >= 0 & g.edgeAttentionMean <= 1));
figGraph = landing2d.viz.plotMonteCarloComparison(struct('graph',g),gc);
cleanupGraph = onCleanup(@()close(figGraph)); %#ok<NASGU>
assert(numel(findall(figGraph,'Type','axes')) >= 4, ...
    'R-GAT Monte Carlo tab must include trajectory, surface and attention views.');
end
