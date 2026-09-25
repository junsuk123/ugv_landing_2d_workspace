function summaries = evaluateMonteCarlo(agent,c,label)
% EVALUATEMONTECARLO  정책을 공통 무작위 초기조건에서 결정론적으로 반복 평가.
nCases = size(c.scenarioSpeeds,1);
nRuns = c.evaluationMonteCarloRuns;
traceGraph = ~strcmp(agent.encoderSpec.mode,'baseline');
options = struct('deterministic',true,'collect',false,'rs',[], ...
    'traceGraph',traceGraph);
items = cell(1,nCases);
for j = 1:nCases
    rs = RandStream('threefry','Seed',c.evaluationMonteCarloSeed+j-1);
    runs = repmat(landing2d.simulation.initializeCase(c,j),1,nRuns);
    if traceGraph
        schema = landing2d.graphstate.schemaFor(agent.encoderSpec.mode);
        finalNodeValues = zeros(schema.nNodes,nRuns);
    end
    for i = 1:nRuns
        [r,s] = landing2d.simulation.monteCarloInitialCase(c,j,rs);
        [runs(i),traj] = landing2d.rl.rolloutEpisode(agent,r,s,c,options);
        if traceGraph && ~isempty(traj.graphValues)
            finalNodeValues(:,i) = traj.graphValues(:,end);
        end
        landing2d.viz.liveDashboard('monteCarloProgress',struct( ...
            'label',label,'scenario',j,'index',i,'total',nRuns));
    end
    items{j} = landing2d.viz.monteCarloSummary(runs,label,j);
    if traceGraph
        items{j}.nodeMean = mean(finalNodeValues,2);
        items{j}.nodeVariance = var(finalNodeValues,0,2);
    end
    landing2d.viz.liveDashboard('monteCarlo',items{j});
end
summaries = [items{:}];
end
