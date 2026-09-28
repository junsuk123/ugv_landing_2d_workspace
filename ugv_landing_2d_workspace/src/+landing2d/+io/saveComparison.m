function saveComparison(runs,summaryTable,cfg,baseName,experiment)
% SAVECOMPARISON  비교 결과 MAT/CSV 저장. 제어기별 시간 로그를 따로 남깁니다.
if nargin < 4 || isempty(baseName)
    baseName = 'rl_comparison';
end
if nargin < 5
    experiment = struct();
end
if ~exist(cfg.outputDir,'dir')
    [ok,message] = mkdir(cfg.outputDir);
    if ~ok, error('landing2d:OutputDirectory','%s',message); end
end
manifest = buildManifest(runs,cfg,baseName,experiment);
save(fullfile(cfg.outputDir,[baseName,'.mat']),'runs','summaryTable','cfg','manifest');
writetable(summaryTable,fullfile(cfg.outputDir,[baseName,'_summary.csv']));
writeManifest(manifest,fullfile(cfg.outputDir,[baseName,'_manifest.json']));
for i = 1:numel(runs)
    tag = lower(regexprep(runs(i).label,'[^A-Za-z0-9]+','_'));
    for j = 1:numel(runs(i).results)
        logTable = landing2d.io.resultToTable(runs(i).results(j),cfg);
        writetable(logTable,fullfile(cfg.outputDir, ...
            sprintf('scenario_%d_%s_log.csv',j,tag)));
    end
end

function manifest = buildManifest(runs,cfg,baseName,experiment)
manifest = struct();
manifest.schemaVersion = 2;
manifest.runId = [baseName,'_',datestr(now,'yyyymmddTHHMMSSFFF')]; %#ok<DATST>
manifest.generatedAt = char(datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
manifest.algorithmVersion = landing2d.rl.algorithmVersion();
manifest.segmentTimes_s = cfg.segmentTimes;
manifest.scenarioSpeeds_mps = cfg.scenarioSpeeds;
manifest.dt_s = cfg.dt;
manifest.tEnd_s = cfg.tEnd;
manifest.ugvAccelMax_mps2 = cfg.ugvAccelMax;
manifest.droneAxMax_mps2 = cfg.axMax;
manifest.cameraFov_deg = cfg.cameraFovDeg;
manifest.captureBoundaryValue = cfg.rl.captureBoundaryValue;
manifest.captureOutsideScale = cfg.rl.captureOutsideScale;
manifest.agentLabels = {runs.label};
if isfield(experiment,'baselineCfg') && isfield(experiment,'proposedCfg')
    baseline = experiment.baselineCfg;
    proposed = experiment.proposedCfg;
    schema = landing2d.graphstate.schemaFor( ...
        proposed.graphState.stateRepresentation);
    semanticNodeCount = schema.nNodes;
    policyNode = '';
    valueNode = '';
    if isfield(schema,'ontologyNodes')
        semanticNodeCount = numel(schema.ontologyNodes);
    end
    if isfield(schema,'policyNode')
        policyNode = schema.nodeNames{schema.policyNode};
        valueNode = schema.nodeNames{schema.valueNode};
    end
    manifest.commonProblemVerified = true;
    manifest.reward = struct( ...
        'formula','captureWeight*captureSignal + distanceWeight*distanceSignal', ...
        'captureWeight',baseline.rl.captureWeight, ...
        'distanceWeight',baseline.rl.distanceWeight, ...
        'captureMode',baseline.rl.captureMode, ...
        'distanceMode',baseline.rl.distanceMode, ...
        'terminalOutcome', ...
        'landed=+1, failed=-1 in both terms; discounted finite-horizon absorbing tail');
    manifest.baselineState = struct( ...
        'representation','11D observation vector', ...
        'observationDim',baseline.rl.observationDim);
    manifest.proposedState = struct( ...
        'representation',proposed.graphState.stateRepresentation, ...
        'readout',proposed.graphState.readout, ...
        'semanticNodeCount',semanticNodeCount, ...
        'totalNodeCount',schema.nNodes, ...
        'edgeCount',numel(schema.src), ...
        'nodeFeatureDim',schema.inDim, ...
        'policyNode',policyNode, ...
        'valueNode',valueNode, ...
        'nodeNames',{schema.nodeNames}, ...
        'relationNames',{schema.relationNames});
    manifest.sensorInformation = ...
        'same sensors/history; no hidden pad truth in policy state';
    if isfield(experiment,'trainingDifferences')
        manifest.trainingDifferences = experiment.trainingDifferences;
        manifest.sameTrainingConditions = isempty(experiment.trainingDifferences);
    end
    manifest.training = struct( ...
        'baselineUseBehaviorClone',baseline.rl.useBehaviorClone, ...
        'proposedUseBehaviorClone',proposed.rl.useBehaviorClone, ...
        'baselinePpoIterations',baseline.rl.ppoIterations, ...
        'proposedPpoIterations',proposed.rl.ppoIterations);
end
end

function writeManifest(manifest,file)
fid = fopen(file,'w');
if fid < 0
    error('landing2d:ManifestWrite','Could not open manifest: %s',file);
end
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,jsonencode(manifest,'PrettyPrint',true),'char');
end
end
