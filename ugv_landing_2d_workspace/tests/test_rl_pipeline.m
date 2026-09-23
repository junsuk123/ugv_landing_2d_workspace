function test_rl_pipeline()
% TEST_RL_PIPELINE  모방 학습 + PPO 파이프라인이 끝까지 돌고 로그 형식이 같은지 확인.
% 학습 품질이 아니라 연결과 자료 구조를 검사합니다.
c = landing2d.config.defaultConfig();
c = landing2d.config.applyOptions(c,struct('tEnd',6,'segmentTimes',[2,4], ...
    'scenarioSpeeds',[1,3,1.5],'animate',false,'figureVisible',false, ...
    'saveResults',false));
c.rl.bcEpisodes = 2;
c.rl.bcEpochs = 3;
c.rl.ppoIterations = 2;
c.rl.episodesPerIteration = 2;
c.rl.ppoEpochs = 2;
c.rl.evaluateEvery = 1;
c.rl.valueWarmup = 0;
c.rl.verbose = false;
landing2d.config.validateConfig(c);
agent = landing2d.rl.trainAgent(c);
assert(all(isfinite(agent.policy.logStd)));
assert(all(isfinite(agent.policy.mean.W{1}(:))));
[rlResults,score,info] = landing2d.rl.evaluate(agent,c);
pdResults = landing2d.simulation.run(c);
assert(isequal(sort(fieldnames(rlResults)),sort(fieldnames(pdResults))), ...
    'RL results must keep the same log format as the PD results.');
assert(isfinite(score) && isscalar(score));
assert(numel(info.landed) == size(c.scenarioSpeeds,1));
assert(all(isfinite(rlResults(1).xDrone)) && all(isfinite(rlResults(1).zDrone)));
assert(isequal(rlResults(1).xUgv,pdResults(1).xUgv), ...
    'Both controllers must face the same UGV trajectory.');

% 같은 학습 설정이면 같은 결과가 나와야 함 (시드 고정).
repeated = landing2d.rl.trainAgent(c);
assert(isequal(repeated.policy.logStd,agent.policy.logStd));
assert(norm(repeated.policy.mean.W{1}(:)-agent.policy.mean.W{1}(:)) < 1e-12);

runs = struct('results',{pdResults,rlResults},'label',{'PD','PPO RL'});
summaryTable = landing2d.metrics.makeComparisonSummary(runs,c);
assert(height(summaryTable) == 2*numel(pdResults));
assert(all(summaryTable.PadCaptureRate >= 0 & summaryTable.PadCaptureRate <= 1));
end
