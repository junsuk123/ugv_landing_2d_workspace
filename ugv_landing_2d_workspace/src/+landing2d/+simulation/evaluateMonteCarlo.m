function summaries = evaluateMonteCarlo(c,label)
% EVALUATEMONTECARLO  유도 법칙을 공통 무작위 초기조건에서 반복 평가.
nCases = size(c.scenarioSpeeds,1);
nRuns = c.evaluationMonteCarloRuns;
items = cell(1,nCases);
for j = 1:nCases
    rs = RandStream('threefry','Seed',c.evaluationMonteCarloSeed+j-1);
    runs = repmat(landing2d.simulation.initializeCase(c,j),1,nRuns);
    for i = 1:nRuns
        [r,s] = landing2d.simulation.monteCarloInitialCase(c,j,rs);
        runs(i) = landing2d.simulation.rolloutCase(r,s,c);
        notify(label,j,i,nRuns);
    end
    items{j} = landing2d.viz.monteCarloSummary(runs,label,j,c);
    landing2d.viz.liveDashboard('monteCarlo',items{j});
end
summaries = [items{:}];
end

function notify(label,scenario,index,total)
landing2d.viz.liveDashboard('monteCarloProgress',struct( ...
    'label',label,'scenario',scenario,'index',index,'total',total));
end
