function report = integrationCheck(output)
% INTEGRATIONCHECK Exercise saved smoke fixtures, plotting and exact live replay.
% Fixtures live in a temporary directory; never in production checkpoints.
assert(output.results.isSmoke && output.config.rl.ppoIterations==1, ...
    'landing2d:SmokeFixture','Only a TEST ONLY one-update smoke fixture is accepted.');
folder = tempname; mkdir(folder); mkdir(fullfile(folder,'checkpoints'));
c = output.config; c.outputDir = folder;
for j = 1:numel(output.runs)
    r = output.runs(j); agent = r.agent; %#ok<NASGU>
    info = struct('history',r.history,'testOnly',true); %#ok<NASGU>
    signature = landing2d.rl.trainingSignature(r.config); %#ok<NASGU>
    save(fullfile(folder,r.config.rl.policyFile),'agent','info','signature');
end
seeds = unique([output.runs.trainSeed]);
loaded = landing2d.orchestration.loadRuns(c,struct('trainSeeds',seeds));
for j = 1:numel(loaded)
    assert(isequaln(loaded(j).agent,output.runs(j).agent),'Checkpoint round trip changed parameters.');
end
scenario = landing2d.orchestration.runScenario('S2', ...
    struct('trainSeeds',seeds,'replicates',2,'visible',false),c);
live = landing2d.orchestration.runLive('S3',struct('trainSeeds',seeds, ...
    'replicates',2,'visible',false,'drawEvery',100,'metrics',true),c);
assert(~live.stopped && height(live.episodes)==6,'Live replay was incomplete.');
figureFolder = fullfile(c.outputDir,'TEST_ONLY_figures');
figures = landing2d.minimal.plotResults(output.results,c,false,figureFolder);
% The normal run omits old held-out/case diagnostics; exercise that branch
% with the same smoke data, without another rollout or optimizer update.
compact = rmfield(output.results,{'caseSummary'});
compactFigures = landing2d.minimal.plotResults(compact,c,false,'');
assert(~isfield(compactFigures,'cases'));
for name = fieldnames(compactFigures)', close(compactFigures.(name{1})); end
for name = fieldnames(output.results)'
    if ~istable(output.results.(name{1})), continue; end
    file = fullfile(folder,[name{1},'.csv']);
    writetable(output.results.(name{1}),file);
    readBack = readtable(file);
    assert(height(readBack)==height(output.results.(name{1})),'CSV lost rows.');
end
for name = fieldnames(figures)', close(figures.(name{1})); end
close(scenario.figure); close(scenario.timeSeries);
close(live.figures);
report = struct('testOnly',true,'passed',true,'fixtureFolder',folder, ...
    'checkpointRoundTrips',numel(loaded),'liveReplayEpisodes',height(live.episodes));
fprintf('TEST ONLY integration: %d checkpoint round trips, %d exact live replays, CSV/PNG export PASS\n', ...
    report.checkpointRoundTrips,report.liveReplayEpisodes);
end
