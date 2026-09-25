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
end
