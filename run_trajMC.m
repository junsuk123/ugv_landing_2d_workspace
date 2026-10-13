function output = run_trajMC(scenarioId,options)
% RUN_TRAJMC  Paired Monte-Carlo trajectory/action consistency comparison.
%
%   run_trajMC
%   run_trajMC('S1')
%   run_trajMC('S3',struct('numRuns',1000,'sigmaMultiplier',1))
%   run_trajMC('S3',struct('validationSeed',2015))
%
% The physical scenario, exogenous events, and environment seed are fixed in
% every repetition.  By default only the time-indexed observation-noise table
% changes and both policies use their deterministic actor mean.  The newest
% compatible same-train-seed checkpoint pair is selected by completion time;
% no training or test-seed checkpoint selection occurs.

if nargin < 1 || isempty(scenarioId), scenarioId = 'S3'; end
if nargin < 2, options = struct(); end
root = fileparts(mfilename('fullpath'));
sourceRoots = {fullfile(root,'src','orchestration'), ...
    fullfile(root,'src','simulations'),fullfile(root,'src','algorithms')};
for i = 1:numel(sourceRoots)
    if ~contains([path pathsep],[sourceRoots{i} pathsep])
        addpath(sourceRoots{i});
    end
end

defaults = struct('numRuns',1000,'policySeed',20261012, ...
    'checkpointDir',fullfile(root,'results'),'trainSeeds',[], ...
    'validationSeed',[], ...
    'monteCarloSource','sensor_noise','sensorNoiseSeedStride',1009, ...
    'sensorNoiseScale',1, ...
    'policyNoiseMode','matched','matchedPolicySigma',[0.18 0.18], ...
    'timeSamples',401,'sigmaMultiplier',1,'minimumActiveFraction',0.05, ...
    'trajectoryFrame','world','horizontalDisplayScale',0.15, ...
    'parallel',true,'parallelWorkers',0,'figureVisible',true, ...
    'showProgress',true,'progressLogEvery',5, ...
    'saveResults',false,'outputDir',fullfile(root,'results','trajectory_mc'));
options = parseOptions(options,defaults);
scenarioId = upper(string(scenarioId));
base = landing2d.config.primaryConfig(root);
base.outputDir = options.checkpointDir;
if isempty(options.validationSeed)
    assert(isscalar(scenarioId) && ismember(scenarioId,["S1","S2","S3"]), ...
        'landing2d:ScenarioId','scenarioId must be S1, S2, or S3.');
    specs = landing2d.paper.representativeScenarios(base);
    spec = specs(strcmp({specs.id},char(scenarioId)));
    scenarioSelection = 'predefined_representative';
else
    seed = options.validationSeed;
    assert(ismember(seed,base.experiment.manifest.validationSeeds) ...
        && ~ismember(seed,base.experiment.manifest.testSeeds), ...
        'landing2d:MonteCarloValidationSeed', ...
        'validationSeed must belong exclusively to the validation split.');
    [env,~,resetInfo] = landing2d.environment.reset(base,seed);
    scenarioId = "V"+string(seed);
    spec = struct('id',char(scenarioId),'seed',seed, ...
        'scenario',env.scenario,'sensorEvents', ...
        resetInfo.evaluatorMetadata.sensorEvents);
    scenarioSelection = 'explicit_validation_seed';
end
methodIds = {'ppo','onto_rgat_ppo'};
if options.parallel
    base.rl.parallelEpisodes = true;
    base.rl.parallelWorkers = options.parallelWorkers;
    base.rl = landing2d.rl.ensurePool(base.rl);
end
useParallel = options.parallel && ~isempty(ver('parallel')) && ~isempty(gcp('nocreate'));

agents = cell(1,2); arms = cell(1,2); files = strings(1,2);
labels = strings(1,2); colors = zeros(2,3); trainSeeds = zeros(1,2);
learnedSigma = zeros(2,2); evaluationSigma = zeros(2,2);
resolvedTrainSeeds = options.trainSeeds;
if isempty(resolvedTrainSeeds)
    resolvedTrainSeeds = latestCommonTrainSeed(base,methodIds,options.checkpointDir);
end
for m = 1:2
    requestedSeed = requestedTrainSeed(resolvedTrainSeeds,m);
    [agents{m},arms{m},files(m),trainSeeds(m)] = newestCheckpoint( ...
        base,methodIds{m},requestedSeed,options.checkpointDir);
    labels(m) = string(arms{m}.dashboardAgentLabel);
    learnedSigma(m,:) = exp(agents{m}.policy.logStd(:))';
    if strcmp(options.monteCarloSource,'policy_sampling') ...
            && strcmp(options.policyNoiseMode,'matched')
        agents{m}.policy.logStd = log(options.matchedPolicySigma(:));
    end
    evaluationSigma(m,:) = exp(agents{m}.policy.logStd(:))';
    registry = landing2d.config.methodRegistry();
    entry = registry.methods(strcmp({registry.methods.id},methodIds{m}));
    colors(m,:) = entry.color;
end
fingerprints = string(cellfun(@landing2d.environment.taskFingerprint,arms, ...
    'UniformOutput',false));
assert(all(fingerprints==fingerprints(1)),'landing2d:MonteCarloTaskMismatch', ...
    'The selected checkpoints do not share the same task fingerprint.');

fprintf('\nTrajectory Monte Carlo: %s, fixed environment seed %d\n', ...
    scenarioId,spec.seed);
for m = 1:2
    fprintf('  %-20s train seed %d, %s\n',labels(m),trainSeeds(m),files(m));
end
fprintf('  %d Monte Carlo rollouts per method (%s)\n',options.numRuns, ...
    ternary(useParallel,'parallel','serial'));
fprintf('  Monte Carlo source: %s\n',options.monteCarloSource);
if strcmp(options.monteCarloSource,'policy_sampling')
    fprintf('  policy noise: %s | PPO [%.3f %.3f], R-GAT [%.3f %.3f]\n', ...
        options.policyNoiseMode,evaluationSigma(1,:),evaluationSigma(2,:));
else
    fprintf(['  deterministic actor mean; time-indexed sensor noise tables vary ' ...
        'by run and are paired across methods (noise scale %.3g)\n'], ...
        options.sensorNoiseScale);
end

progressFigure = createProgressFigure(labels,colors,options);
progressQueue = [];
if useParallel
    progressQueue = parallel.pool.DataQueue;
    afterEach(progressQueue,@(message) updateProgress( ...
        progressFigure,message,labels,options));
end
rollouts = cell(2,options.numRuns);
for m = 1:2
    agent = agents{m}; arm = arms{m};
    methodRollouts = cell(1,options.numRuns);
    firstPolicySeed = options.policySeed;
    if useParallel
        parfor r = 1:options.numRuns
            methodRollouts{r} = oneRollout(agent,arm,spec,r,firstPolicySeed+r-1,options);
            send(progressQueue,progressMessage(m,methodRollouts{r}));
        end
    else
        for r = 1:options.numRuns
            methodRollouts{r} = oneRollout(agent,arm,spec,r,firstPolicySeed+r-1,options);
            updateProgress(progressFigure,progressMessage(m,methodRollouts{r}), ...
                labels,options);
        end
    end
    rollouts(m,:) = methodRollouts;
end
variationContract = landing2d.orchestration.validateConditionalMonteCarlo( ...
    rollouts,spec,options.monteCarloSource);
fprintf('  design verified: fixed={%s}; varied={%s}\n', ...
    strjoin(variationContract.fixedVariables,', '), ...
    strjoin(variationContract.variedVariables,', '));

time = linspace(0,spec.scenario.deadline,options.timeSamples);
stats = cell(1,2); summaryRows = cell(1,2);
for m = 1:2
    [stats{m},summaryRows{m}] = summarizeRollouts(rollouts(m,:),time, ...
        options.minimumActiveFraction,methodIds{m},labels(m),files(m), ...
        trainSeeds(m),'ugv_relative');
end
summary = struct2table(vertcat(summaryRows{:}));
summary.TrajectoryVarianceReductionVsPPO_pct = ...
    100*(summary.MeanPositionVariance_m2(1)-summary.MeanPositionVariance_m2) ...
    /summary.MeanPositionVariance_m2(1);
summary.SuccessRateDeltaVsPPO_pp = 100*(summary.SuccessRate-summary.SuccessRate(1));
summary.AxVarianceReductionVsPPO_pct = ...
    100*(summary.MeanAxVariance_m2s4(1)-summary.MeanAxVariance_m2s4) ...
    /summary.MeanAxVariance_m2s4(1);
summary.AzVarianceReductionVsPPO_pct = ...
    100*(summary.MeanAzVariance_m2s4(1)-summary.MeanAzVariance_m2s4) ...
    /summary.MeanAzVariance_m2s4(1);
summary.NormalVarianceReductionVsPPO_pct = ...
    100*(summary.MeanNormalVariance_m2(1)-summary.MeanNormalVariance_m2) ...
    /summary.MeanNormalVariance_m2(1);
summary.AlongTrackVarianceReductionVsPPO_pct = ...
    100*(summary.MeanAlongTrackVariance_m2(1)-summary.MeanAlongTrackVariance_m2) ...
    /summary.MeanAlongTrackVariance_m2(1);
validVariance = isfinite(stats{1}.positionVariance) ...
    & isfinite(stats{2}.positionVariance);
lowerVarianceTimeFraction = mean(stats{2}.positionVariance(validVariance) ...
    < stats{1}.positionVariance(validVariance));
successMask = false(2,options.numRuns);
for m = 1:2
    successMask(m,:) = cellfun(@(q)strcmp(q.terminalReason,'SUCCESS'), ...
        rollouts(m,:));
end
pairedSuccess = find(all(successMask,1));
landingProgress = linspace(0,1,201);
landingGeometry = cell(1,2);
for m = 1:2
    landingGeometry{m} = summarizeLandingGeometry(rollouts(m,:), ...
        pairedSuccess,landingProgress,options.trajectoryFrame);
end
fig = plotComparison(stats,time,landingGeometry,labels,colors,spec, ...
    base,options,summary,numel(pairedSuccess));

output = struct('schemaVersion','trajectory_mc_v5','generatedAt',datetime('now'), ...
    'scenario',spec,'environmentSeed',spec.seed,'policySeeds', ...
    variationContract.policySamplingSeeds,'numRuns',options.numRuns, ...
    'methodIds',{methodIds},'labels',labels,'trainSeeds',trainSeeds, ...
    'checkpointFiles',files,'taskFingerprint',fingerprints(1), ...
    'monteCarloSource',options.monteCarloSource, ...
    'sensorNoiseScale',options.sensorNoiseScale, ...
    'scenarioSelection',scenarioSelection, ...
    'policyNoiseMode',options.policyNoiseMode,'learnedSigma',learnedSigma, ...
    'evaluationSigma',evaluationSigma, ...
    'trajectoryFrame',options.trajectoryFrame, ...
    'metricFrame','ugv_relative', ...
    'horizontalDisplayScale',options.horizontalDisplayScale, ...
    'rgatLowerVarianceTimeFraction',lowerVarianceTimeFraction, ...
    'pairedCommonSuccessCount',numel(pairedSuccess), ...
    'landingProgress',landingProgress,'landingGeometry',{landingGeometry}, ...
    'variationContract',variationContract, ...
    'time',time,'statistics',{stats},'summary',summary,'figure',fig, ...
    'progressFigure',progressFigure);
if options.saveResults
    if ~isfolder(options.outputDir), mkdir(options.outputDir); end
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
    stem = sprintf('trajectory_mc_%s_noise_%g_%s',lower(char(scenarioId)), ...
        options.sensorNoiseScale,stamp);
    savedOutput = rmfield(output,{'figure','progressFigure'});
    save(fullfile(options.outputDir,[stem '.mat']),'savedOutput','-v7.3');
    writetable(summary,fullfile(options.outputDir,[stem '_summary.csv']));
    exportgraphics(fig,fullfile(options.outputDir,[stem '.png']),'Resolution',200);
    savefig(fig,fullfile(options.outputDir,[stem '.fig']));
end
if nargout==0, assignin('base','landingTrajectoryMC',output); end
end

function sample = oneRollout(agent,arm,spec,realizationIndex,policySeed,options)
deterministic = strcmp(options.monteCarloSource,'sensor_noise');
rs = [];
if deterministic
    streams = arm.experiment.commonObservation.randomStreams;
    delta = (realizationIndex-1)*options.sensorNoiseSeedStride;
    streams.markerOffset = streams.markerOffset+delta;
    streams.navigationOffset = streams.navigationOffset+delta;
    streams.trackerOffset = streams.trackerOffset+delta;
    arm.experiment.commonObservation.randomStreams = streams;
else
    rs = RandStream('threefry','Seed',policySeed);
end
opts = struct('deterministic',deterministic,'collect',false,'rs',rs, ...
    'scenario',spec.scenario,'sensorEvents',spec.sensorEvents, ...
    'sensorNoiseScale',options.sensorNoiseScale);
[result,traj] = landing2d.rl.rolloutEpisodeV2(agent,arm,spec.seed,opts);
sample = struct('time',result.time,'x',result.xDrone,'z',result.zDrone, ...
    'xPad',result.xPad,'actionTime',traj.time, ...
    'requestedAcceleration',traj.requestedAcceleration, ...
    'terminalReason',result.terminalReason,'return',result.return, ...
    'landingTime',result.landingTime, ...
    'scenario',result.scenario,'sensorEvents', ...
    result.resetInfo.evaluatorMetadata.sensorEvents, ...
    'provenance',result.resetInfo.provenance, ...
    'initialPhysicalState',[result.xDrone(1),result.zDrone(1), ...
        result.vxDrone(1),result.vzDrone(1),result.theta(1),result.pitchRate(1)], ...
    'policySamplingSeed',ternary(deterministic,NaN,policySeed));
end

function message = progressMessage(methodIndex,sample)
message = struct('methodIndex',methodIndex, ...
    'success',strcmp(sample.terminalReason,'SUCCESS'),'return',sample.return);
end

function fig = createProgressFigure(labels,colors,options)
if ~options.showProgress || ~options.figureVisible
    fig = gobjects(0);
    return;
end
fig = figure('Name','Trajectory Monte Carlo progress','Color','w', ...
    'NumberTitle','off','Position',[140 120 920 600]);
layout = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
axProgress = nexttile(layout,[1 2]);
bars = bar(axProgress,1:2,zeros(1,2),0.55,'FaceColor','flat');
bars.CData = colors;
ylim(axProgress,[0 options.numRuns]); xlim(axProgress,[0.4 2.6]);
xticks(axProgress,1:2); xticklabels(axProgress,labels);
ylabel(axProgress,'Completed rollouts'); grid(axProgress,'on');
progressText = gobjects(1,2);
for m = 1:2
    progressText(m) = text(axProgress,m,0,sprintf('0 / %d',options.numRuns), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom');
end
axSuccess = nexttile(layout); hold(axSuccess,'on'); grid(axSuccess,'on');
axReturn = nexttile(layout); hold(axReturn,'on'); grid(axReturn,'on');
successLines = gobjects(1,2); returnLines = gobjects(1,2);
for m = 1:2
    successLines(m) = animatedline(axSuccess,'Color',colors(m,:), ...
        'LineWidth',1.8,'DisplayName',labels(m));
    returnLines(m) = animatedline(axReturn,'Color',colors(m,:), ...
        'LineWidth',1.8,'DisplayName',labels(m));
end
xlabel(axSuccess,'Completed rollouts'); ylabel(axSuccess,'Cumulative success rate');
ylim(axSuccess,[0 1]); legend(axSuccess,'Location','best','Interpreter','none');
xlabel(axReturn,'Completed rollouts'); ylabel(axReturn,'Cumulative mean return');
legend(axReturn,'Location','best','Interpreter','none');
title(layout,'Monte Carlo running estimates');
state = struct('counts',zeros(1,2),'successes',zeros(1,2), ...
    'returnSums',zeros(1,2),'startTime',tic,'bars',bars, ...
    'progressText',progressText,'successLines',successLines, ...
    'returnLines',returnLines);
setappdata(fig,'trajectoryMCProgress',state);
end

function updateProgress(fig,message,labels,options)
persistent consoleCounts consoleStart
if isempty(consoleCounts) || (message.methodIndex==1 && consoleCounts(1)>=options.numRuns)
    consoleCounts = zeros(1,2); consoleStart = tic;
end
m = message.methodIndex;
consoleCounts(m) = consoleCounts(m)+1;
elapsed = toc(consoleStart);
if mod(consoleCounts(m),options.progressLogEvery)==0 || consoleCounts(m)==options.numRuns
    totalDone = sum(consoleCounts); totalTarget = 2*options.numRuns;
    eta = elapsed/max(totalDone,1)*(totalTarget-totalDone);
    fprintf('    %-20s %4d/%d | total %5.1f%% | elapsed %s | ETA %s\n', ...
        labels(m),consoleCounts(m),options.numRuns,100*totalDone/totalTarget, ...
        durationText(elapsed),durationText(eta));
end
if isempty(fig) || ~isgraphics(fig), return; end
state = getappdata(fig,'trajectoryMCProgress');
state.counts(m) = state.counts(m)+1;
state.successes(m) = state.successes(m)+double(message.success);
state.returnSums(m) = state.returnSums(m)+message.return;
state.bars.YData = state.counts;
state.progressText(m).Position(2) = state.counts(m);
state.progressText(m).String = sprintf('%d / %d (%.1f%%)', ...
    state.counts(m),options.numRuns,100*state.counts(m)/options.numRuns);
addpoints(state.successLines(m),state.counts(m), ...
    state.successes(m)/state.counts(m));
addpoints(state.returnLines(m),state.counts(m), ...
    state.returnSums(m)/state.counts(m));
setappdata(fig,'trajectoryMCProgress',state);
drawnow limitrate;
end

function text = durationText(seconds)
if ~isfinite(seconds), text='--'; return; end
seconds = max(0,round(seconds));
text = sprintf('%02d:%02d:%02d',floor(seconds/3600), ...
    floor(mod(seconds,3600)/60),mod(seconds,60));
end

function [s,row] = summarizeRollouts(samples,time,minActiveFraction,methodId,label,file,trainSeed,trajectoryFrame)
n = numel(samples); nt = numel(time);
X = nan(n,nt); Z = nan(n,nt); AX = nan(n,nt); AZ = nan(n,nt);
for r = 1:n
    q = samples{r};
    if strcmp(trajectoryFrame,'ugv_relative')
        trajectoryX = q.x-q.xPad;
    else
        trajectoryX = q.x;
    end
    X(r,:) = terminalHold(q.time,trajectoryX,time);
    Z(r,:) = terminalHold(q.time,q.z,time);
    if ~isempty(q.actionTime)
        AX(r,:) = interp1(q.actionTime,q.requestedAcceleration(1,:),time,'linear',NaN);
        AZ(r,:) = interp1(q.actionTime,q.requestedAcceleration(2,:),time,'linear',NaN);
    end
end
meanX = mean(X,1,'omitnan'); meanZ = mean(Z,1,'omitnan');
varianceX = var(X,0,1,'omitnan'); varianceZ = var(Z,0,1,'omitnan');
covarianceXZ = mean((X-meanX).*(Z-meanZ),1,'omitnan');
maxEigenVariance = 0.5*(varianceX+varianceZ+ ...
    sqrt((varianceX-varianceZ).^2+4*covarianceXZ.^2));
dx = gradient(meanX,time); dz = gradient(meanZ,time);
[tangentX,tangentZ] = persistentTangent(dx,dz);
normalX = -tangentZ; normalZ = tangentX;
normalDeviation = (X-meanX).*normalX+(Z-meanZ).*normalZ;
alongTrackDeviation = (X-meanX).*tangentX+(Z-meanZ).*tangentZ;
activeCount = sum(~isnan(AX),1);
actionMask = activeCount >= max(2,ceil(minActiveFraction*n));
meanAX = mean(AX,1,'omitnan'); meanAZ = mean(AZ,1,'omitnan');
stdAX = std(AX,0,1,'omitnan'); stdAZ = std(AZ,0,1,'omitnan');
meanAX(~actionMask)=NaN; meanAZ(~actionMask)=NaN;
stdAX(~actionMask)=NaN; stdAZ(~actionMask)=NaN;
reasons = string(cellfun(@(q)q.terminalReason,samples,'UniformOutput',false));
returns = cellfun(@(q)q.return,samples);
landingTimes = cellfun(@(q)q.landingTime,samples);
finalRelativeX = cellfun(@(q)q.x(end)-q.xPad(end),samples);
positionDispersion = sqrt(varianceX+varianceZ);
finiteDispersion = positionDispersion(isfinite(positionDispersion));
s = struct('meanX',meanX,'meanZ',meanZ,'varianceX',varianceX, ...
    'varianceZ',varianceZ,'covarianceXZ',covarianceXZ, ...
    'positionVariance',varianceX+varianceZ, ...
    'maxEigenVariance',maxEigenVariance,'normalX',normalX,'normalZ',normalZ, ...
    'normalVariance',var(normalDeviation,0,1,'omitnan'), ...
    'alongTrackVariance',var(alongTrackDeviation,0,1,'omitnan'), ...
    'meanAction',[meanAX;meanAZ],'actionVariance',[stdAX.^2;stdAZ.^2], ...
    'activeCount',activeCount,'terminalReasons',reasons);
row = struct('MethodId',string(methodId),'Method',string(label), ...
    'TrainSeed',trainSeed,'Checkpoint',string(file),'Runs',n, ...
    'SuccessRate',mean(reasons=="SUCCESS"),'MeanReturn',mean(returns), ...
    'MeanPositionVariance_m2',mean(s.positionVariance,'omitnan'), ...
    'MeanPositionDispersion_cm',100*mean(positionDispersion,'omitnan'), ...
    'P95PositionDispersion_cm',100*prctile(finiteDispersion,95), ...
    'LandingTimeStd_s',std(landingTimes,0,'omitnan'), ...
    'FinalRelativeXStd_cm',100*std(finalRelativeX,0,'omitnan'), ...
    'MeanNormalVariance_m2',mean(s.normalVariance,'omitnan'), ...
    'MeanAlongTrackVariance_m2',mean(s.alongTrackVariance,'omitnan'), ...
    'FinalXVariance_m2',s.varianceX(end),'FinalZVariance_m2',s.varianceZ(end), ...
    'MeanAxVariance_m2s4',mean(s.actionVariance(1,:),'omitnan'), ...
    'MeanAzVariance_m2s4',mean(s.actionVariance(2,:),'omitnan'));
end

function [tx,tz] = persistentTangent(dx,dz)
% Mean motion becomes exactly zero after terminal hold. Keep the most recent
% valid flight direction so terminal-position dispersion is not silently
% dropped from the normal/along-track decomposition.
speed = hypot(dx,dz);
valid = speed > 1e-8;
tx = zeros(size(dx)); tz = zeros(size(dz));
if ~any(valid)
    tx(:) = 1;
    return;
end
tx(valid) = dx(valid)./speed(valid);
tz(valid) = dz(valid)./speed(valid);
first = find(valid,1,'first');
tx(1:first-1) = tx(first); tz(1:first-1) = tz(first);
for k = first+1:numel(tx)
    if ~valid(k)
        tx(k) = tx(k-1); tz(k) = tz(k-1);
    end
end
end

function g = summarizeLandingGeometry(samples,selected,progress,trajectoryFrame)
% The geometric panel uses paired common-success runs and normalized episode
% progress. Failures remain part of the all-run dispersion and outcome plots.
n = numel(selected); nq = numel(progress);
X = nan(n,nq); Z = nan(n,nq); padEndX = nan(n,1);
for column = 1:n
    sample = samples{selected(column)};
    if strcmp(trajectoryFrame,'ugv_relative')
        trajectoryX = sample.x-sample.xPad;
        trajectoryZ = sample.z-sample.scenario.padHeight;
        padEndX(column) = 0;
    else
        trajectoryX = sample.x;
        trajectoryZ = sample.z;
        padEndX(column) = sample.xPad(end);
    end
    episodeProgress = (sample.time-sample.time(1)) ...
        /max(sample.time(end)-sample.time(1),eps);
    [episodeProgress,keep] = unique(episodeProgress,'stable');
    X(column,:) = interp1(episodeProgress,trajectoryX(keep),progress, ...
        'linear','extrap');
    Z(column,:) = interp1(episodeProgress,trajectoryZ(keep),progress, ...
        'linear','extrap');
end
if n==0
    g = struct('meanX',nan(1,nq),'meanVertical',nan(1,nq), ...
        'normalX',nan(1,nq),'normalVertical',nan(1,nq), ...
        'normalVariance',nan(1,nq),'sampleX',zeros(0,nq), ...
        'sampleVertical',zeros(0,nq),'meanPadEndX',NaN, ...
        'runIndices',zeros(1,0),'count',0);
    return;
end
meanX = mean(X,1,'omitnan'); meanVertical = mean(Z,1,'omitnan');
varianceX = var(X,0,1,'omitnan'); varianceVertical = var(Z,0,1,'omitnan');
covarianceXZ = mean((X-meanX).*(Z-meanVertical),1,'omitnan');
dx = gradient(meanX,progress); dz = gradient(meanVertical,progress);
[tangentX,tangentVertical] = persistentTangent(dx,dz);
normalX = -tangentVertical; normalVertical = tangentX;
normalVariance = normalX.^2.*varianceX ...
    + normalVertical.^2.*varianceVertical ...
    + 2*normalX.*normalVertical.*covarianceXZ;
shown = unique(round(linspace(1,n,min(24,n))));
g = struct('meanX',meanX,'meanVertical',meanVertical, ...
    'normalX',normalX,'normalVertical',normalVertical, ...
    'normalVariance',max(normalVariance,0), ...
    'sampleX',X(shown,:),'sampleVertical',Z(shown,:), ...
    'meanPadEndX',mean(padEndX,'omitnan'), ...
    'runIndices',selected(shown),'count',n);
end

function y = terminalHold(t,x,tq)
[t,uniqueIndex] = unique(t,'stable'); x = x(uniqueIndex);
y = interp1(t,x,tq,'linear',NaN);
y(tq<t(1)) = x(1); y(tq>t(end)) = x(end);
end

function fig = plotComparison(stats,time,geometry,labels,colors,spec,base,options,summary,pairedSuccessCount)
visibility = ternary(options.figureVisible,'on','off');
fig = figure('Name','Drone landing Monte Carlo','Color','w', ...
    'Visible',visibility,'Position',[80 40 1320 860]);
layout = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');

axTrajectory = nexttile(layout,[2 1]); hold(axTrajectory,'on');
grid(axTrajectory,'on'); box(axTrajectory,'on');
padTop = ternary(strcmp(options.trajectoryFrame,'world'),base.padHeight,0);
if strcmp(options.trajectoryFrame,'world')
    for m = 1:2
        if geometry{m}.count>0
            drawLandingPlatform(axTrajectory,geometry{m}.meanPadEndX, ...
                padTop,base.padHalfLength,colors(m,:));
        end
    end
else
    drawLandingPlatform(axTrajectory,0,padTop,base.padHalfLength,[0.25 0.25 0.25]);
end
for m = 1:2
    drawLandingTrajectory(axTrajectory,geometry{m},colors(m,:),labels(m), ...
        options.sigmaMultiplier);
end
startGeometry = find(cellfun(@(g)g.count>0,geometry),1,'last');
if ~isempty(startGeometry)
    drawDroneGlyph(axTrajectory,geometry{startGeometry}.meanX(1), ...
        geometry{startGeometry}.meanVertical(1));
end
xlabel(axTrajectory,landingHorizontalAxisLabel(options));
ylabel(axTrajectory,landingVerticalAxisLabel(options));
frameLabel = ternary(strcmp(options.trajectoryFrame,'world'), ...
    'world-frame','pad-relative');
title(axTrajectory,sprintf('%s %s landing paths (paired successful runs)', ...
    spec.id,frameLabel));
tightLandingLimits(axTrajectory,geometry,padTop,base.padHalfLength,options);
daspect(axTrajectory,[1/options.horizontalDisplayScale 1 1]);
legend(axTrajectory,'Location','best','Interpreter','none','Box','off');
text(axTrajectory,0.98,0.58,sprintf([ ...
    '%d/%d paired runs landed successfully\n' ...
    'thin: %d sampled flights | thick: mean | band: ±%.2gσ normal\n' ...
    'horizontal display scale: %.2g× (axis values remain physical)'], ...
    pairedSuccessCount,options.numRuns,min(24,pairedSuccessCount), ...
    options.sigmaMultiplier, ...
    options.horizontalDisplayScale), ...
    'Units','normalized','HorizontalAlignment','right', ...
    'VerticalAlignment','middle', ...
    'BackgroundColor','w','Margin',5,'EdgeColor',[0.75 0.75 0.75]);

axVariance = nexttile(layout); hold(axVariance,'on'); grid(axVariance,'on');
for m = 1:2
    dispersion = 100*sqrt(stats{m}.positionVariance);
    plot(axVariance,time,max(dispersion,0.01), ...
        'Color',colors(m,:),'LineWidth',2.0,'DisplayName',labels(m));
end
xlabel(axVariance,'Time [s]'); ylabel(axVariance,'RMS position spread [cm]');
set(axVariance,'YScale','log');
title(axVariance,'All runs: pad-relative position spread (log scale)');
legend(axVariance,'Location','best','Interpreter','none','Box','off');
text(axVariance,0.02,0.03,sprintf([ ...
    'mean position-variance reduction: %.3f%%\n' ...
    'path-normal variance reduction: %.2f%%'], ...
    summary.TrajectoryVarianceReductionVsPPO_pct(2), ...
    summary.NormalVarianceReductionVsPPO_pct(2)), ...
    'Units','normalized','VerticalAlignment','bottom', ...
    'BackgroundColor','w','Margin',4,'EdgeColor',[0.80 0.80 0.80]);

axOutcome = nexttile(layout); hold(axOutcome,'on'); grid(axOutcome,'on');
successPercent = 100*summary.SuccessRate;
bars = bar(axOutcome,1:2,successPercent,0.55,'FaceColor','flat');
bars.CData = colors;
ylim(axOutcome,[0 105]); xlim(axOutcome,[0.4 2.6]);
xticks(axOutcome,1:2); xticklabels(axOutcome,labels);
ylabel(axOutcome,'Successful landings [%]');
title(axOutcome,'All-run landing outcome');
for m = 1:2
    text(axOutcome,m,min(successPercent(m)+2,102), ...
        sprintf('%.1f%%  (%d/%d)',successPercent(m), ...
        round(summary.SuccessRate(m)*options.numRuns),options.numRuns), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontWeight','bold');
end

title(layout,sprintf('%s: drone landing under paired sensor-noise Monte Carlo',spec.id));
subtitle(layout,sprintf( ...
    '%d runs/method | fixed physical scenario and events (seed %d) | noise x%.3g', ...
    options.numRuns,spec.seed,options.sensorNoiseScale));
end

function drawLandingTrajectory(ax,g,color,label,k)
if g.count==0, return; end
sampleColor = 0.78*[1 1 1]+0.22*color;
for i = 1:size(g.sampleX,1)
    plot(ax,g.sampleX(i,:),g.sampleVertical(i,:), ...
        'Color',sampleColor,'LineWidth',0.55,'HandleVisibility','off');
end
sd = sqrt(g.normalVariance);
upperX = g.meanX+k*sd.*g.normalX;
upperZ = g.meanVertical+k*sd.*g.normalVertical;
lowerX = g.meanX-k*sd.*g.normalX;
lowerZ = g.meanVertical-k*sd.*g.normalVertical;
patch(ax,[upperX fliplr(lowerX)], ...
    [upperZ fliplr(lowerZ)],color, ...
    'FaceAlpha',0.18,'EdgeColor','none','HandleVisibility','off');
plot(ax,g.meanX,g.meanVertical,'Color',color, ...
    'LineWidth',2.4,'DisplayName',label);
plot(ax,g.meanX(1),g.meanVertical(1),'o', ...
    'Color',color,'MarkerFaceColor','w','MarkerSize',7, ...
    'LineWidth',1.4,'HandleVisibility','off');
plot(ax,g.meanX(end),g.meanVertical(end),'v', ...
    'Color',color,'MarkerFaceColor',color,'MarkerSize',7, ...
    'LineWidth',1.2,'HandleVisibility','off');
end

function drawLandingPlatform(ax,padCenter,padTop,padHalfLength,edgeColor)
padThickness = 0.06;
rectangle(ax,'Position',[padCenter-padHalfLength,padTop-padThickness, ...
    2*padHalfLength,padThickness], ...
    'FaceColor',[0.95 0.68 0.08],'EdgeColor',edgeColor, ...
    'LineWidth',1.2,'HandleVisibility','off');
end

function drawDroneGlyph(ax,x,vertical)
arm = 0.16; rotor = 0.055;
plot(ax,[x-arm x+arm],[vertical vertical],'-', ...
    'Color',[0.15 0.15 0.15],'LineWidth',2.0,'HandleVisibility','off');
plot(ax,x,vertical,'s','Color',[0.15 0.15 0.15], ...
    'MarkerFaceColor',[0.85 0.85 0.85],'MarkerSize',6, ...
    'HandleVisibility','off');
theta = linspace(0,2*pi,36);
for center = [x-arm x+arm]
    plot(ax,center+rotor*cos(theta),vertical+0.025*sin(theta), ...
        'Color',[0.15 0.15 0.15],'LineWidth',1.0, ...
        'HandleVisibility','off');
end
text(ax,x,vertical+0.12,'start','HorizontalAlignment','center', ...
    'VerticalAlignment','bottom','Color',[0.15 0.15 0.15], ...
    'HandleVisibility','off');
end

function label = landingHorizontalAxisLabel(options)
if strcmp(options.trajectoryFrame,'ugv_relative')
    prefix = 'Drone - pad horizontal position';
else
    prefix = 'World horizontal position x_D';
end
if options.horizontalDisplayScale==1
    label = sprintf('%s [m]',prefix);
else
    label = sprintf('%s [m] (display scale %.3g×)', ...
        prefix,options.horizontalDisplayScale);
end
end

function label = landingVerticalAxisLabel(options)
if strcmp(options.trajectoryFrame,'ugv_relative')
    label = 'Height above moving pad [m]';
else
    label = 'World altitude z_D [m]';
end
end

function tightLandingLimits(ax,geometry,padTop,padHalfLength,options)
extent = []; vertical = []; padCenters = [];
for m = 1:numel(geometry)
    g = geometry{m};
    sd = sqrt(g.normalVariance);
    extent = [extent,g.meanX-options.sigmaMultiplier*sd, ... %#ok<AGROW>
        g.meanX+options.sigmaMultiplier*sd,g.sampleX(:)']; %#ok<AGROW>
    vertical = [vertical,g.meanVertical-options.sigmaMultiplier*sd, ... %#ok<AGROW>
        g.meanVertical+options.sigmaMultiplier*sd,g.sampleVertical(:)']; %#ok<AGROW>
    padCenters = [padCenters,g.meanPadEndX]; %#ok<AGROW>
end
padCenters = padCenters(isfinite(padCenters));
extent = [extent,padCenters-padHalfLength,padCenters+padHalfLength];
extent = extent(isfinite(extent));
vertical = vertical(isfinite(vertical));
if isempty(extent) || isempty(vertical), return; end
xBounds = [min(extent),max(extent)];
xPadding = max(0.04*diff(xBounds),0.15);
xlim(ax,xBounds+[-xPadding xPadding]);
yTop = max(vertical);
ylim(ax,[padTop-0.08,yTop+max(0.04*(yTop-padTop),0.12)]);
end

function [agent,arm,file,seed] = newestCheckpoint(base,methodId,requestedSeed,checkpointDir)
if isempty(requestedSeed)
    listing = dir(fullfile(checkpointDir,'checkpoints',[methodId '_s*.mat']));
    [~,order] = sort([listing.datenum],'descend'); listing = listing(order);
    seeds = nan(1,numel(listing));
    for i = 1:numel(listing)
        token = regexp(listing(i).name,'_s(\d+)\.mat$','tokens','once');
        if ~isempty(token), seeds(i)=str2double(token{1}); end
    end
    seeds = seeds(isfinite(seeds));
else
    seeds = requestedSeed;
end
for seed = seeds
    arm = landing2d.config.applyMethod(base,methodId,seed);
    arm.outputDir = checkpointDir;
    try
        [agent,~,file] = landing2d.rl.loadCheckpoint(arm);
        file = string(file);
        return;
    catch err
        if ~ismember(err.identifier,{'landing2d:CheckpointNotFound', ...
                'landing2d:CheckpointMismatch','landing2d:InvalidCheckpoint'})
            rethrow(err);
        end
    end
end
error('landing2d:NoCompatibleCheckpoint', ...
    'No compatible %s checkpoint was found under %s.',methodId,checkpointDir);
end

function seed = requestedTrainSeed(value,index)
if isempty(value), seed=[]; return; end
if isscalar(value), seed=value; else, seed=value(index); end
end

function seed = latestCommonTrainSeed(base,methodIds,checkpointDir)
seedLists = cell(1,numel(methodIds)); fileLists = cell(1,numel(methodIds));
for m = 1:numel(methodIds)
    fileLists{m} = dir(fullfile(checkpointDir,'checkpoints',[methodIds{m} '_s*.mat']));
    seedLists{m} = nan(1,numel(fileLists{m}));
    for i = 1:numel(fileLists{m})
        token = regexp(fileLists{m}(i).name,'_s(\d+)\.mat$','tokens','once');
        if ~isempty(token), seedLists{m}(i)=str2double(token{1}); end
    end
end
candidates = intersect(seedLists{1}(isfinite(seedLists{1})), ...
    seedLists{2}(isfinite(seedLists{2})));
pairCompleted = -inf(size(candidates));
for i = 1:numel(candidates)
    dates = zeros(1,numel(methodIds)); compatible = true;
    for m = 1:numel(methodIds)
        index = find(seedLists{m}==candidates(i),1);
        dates(m) = fileLists{m}(index).datenum;
        arm = landing2d.config.applyMethod(base,methodIds{m},candidates(i));
        arm.outputDir = checkpointDir;
        try
            landing2d.rl.loadCheckpoint(arm);
        catch err
            if ismember(err.identifier,{'landing2d:CheckpointNotFound', ...
                    'landing2d:CheckpointMismatch','landing2d:InvalidCheckpoint'})
                compatible = false;
            else
                rethrow(err);
            end
        end
    end
    if compatible, pairCompleted(i)=max(dates); end
end
[latestDate,index] = max(pairCompleted);
assert(isfinite(latestDate),'landing2d:NoCompatibleCheckpointPair', ...
    ['No compatible same-train-seed PPO/R-GAT checkpoint pair was found. ' ...
    'Retrain the current R-GAT revision before running this comparison.']);
seed = candidates(index);
end

function options = parseOptions(options,defaults)
assert(isstruct(options) && isscalar(options),'landing2d:InvalidOptions', ...
    'options must be a scalar struct.');
unknown = setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption', ...
    'Unknown run_trajMC option: %s',strjoin(unknown,', '));
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(options,names{i}), options.(names{i})=defaults.(names{i}); end
end
validateattributes(options.numRuns,{'numeric'},{'scalar','integer','>=',2});
validateattributes(options.policySeed,{'numeric'},{'scalar','integer','nonnegative'});
validateattributes(options.timeSamples,{'numeric'},{'scalar','integer','>=',20});
validateattributes(options.sigmaMultiplier,{'numeric'},{'scalar','positive','finite'});
validateattributes(options.minimumActiveFraction,{'numeric'},{'scalar','>',0,'<=',1});
validateattributes(options.parallelWorkers,{'numeric'},{'scalar','integer','nonnegative'});
validateattributes(options.progressLogEvery,{'numeric'},{'scalar','integer','positive'});
options.policyNoiseMode = validatestring(options.policyNoiseMode,{'matched','learned'});
options.monteCarloSource = validatestring(options.monteCarloSource, ...
    {'sensor_noise','policy_sampling'});
options.trajectoryFrame = validatestring(options.trajectoryFrame, ...
    {'ugv_relative','world'});
validateattributes(options.horizontalDisplayScale,{'numeric'}, ...
    {'scalar','positive','finite'});
validateattributes(options.sensorNoiseSeedStride,{'numeric'}, ...
    {'scalar','integer','positive','finite'});
validateattributes(options.sensorNoiseScale,{'numeric'}, ...
    {'scalar','real','finite','nonnegative'});
if ~isempty(options.validationSeed)
    validateattributes(options.validationSeed,{'numeric'}, ...
        {'scalar','integer','positive'});
end
validateattributes(options.matchedPolicySigma,{'numeric'}, ...
    {'vector','numel',2,'positive','finite'});
assert(isempty(options.trainSeeds) || (isnumeric(options.trainSeeds) && ...
    isvector(options.trainSeeds) && ismember(numel(options.trainSeeds),[1 2]) && ...
    all(options.trainSeeds>0) && all(mod(options.trainSeeds,1)==0)), ...
    'landing2d:TrainSeeds','trainSeeds must be empty, one seed, or [ppo rgat].');
options.parallel = logical(options.parallel);
options.figureVisible = logical(options.figureVisible);
options.showProgress = logical(options.showProgress);
options.saveResults = logical(options.saveResults);
options.checkpointDir = char(options.checkpointDir);
options.outputDir = char(options.outputDir);
end

function value = ternary(condition,a,b)
if condition, value=a; else, value=b; end
end
