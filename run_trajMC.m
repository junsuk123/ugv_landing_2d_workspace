function output = run_trajMC(scenarioId,options)
% RUN_TRAJMC  Paired Monte-Carlo trajectory/action consistency comparison.
%
%   run_trajMC
%   run_trajMC('S1')
%   run_trajMC('S3',struct('numRuns',1000,'sigmaMultiplier',1))
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
    'monteCarloSource','sensor_noise','sensorNoiseSeedStride',1009, ...
    'policyNoiseMode','matched','matchedPolicySigma',[0.18 0.18], ...
    'timeSamples',401,'sigmaMultiplier',1,'minimumActiveFraction',0.05, ...
    'parallel',true,'parallelWorkers',0,'figureVisible',true, ...
    'showProgress',true,'progressLogEvery',5, ...
    'saveResults',false,'outputDir',fullfile(root,'results','trajectory_mc'));
options = parseOptions(options,defaults);
scenarioId = upper(string(scenarioId));
assert(isscalar(scenarioId) && ismember(scenarioId,["S1","S2","S3"]), ...
    'landing2d:ScenarioId','scenarioId must be S1, S2, or S3.');

base = landing2d.config.primaryConfig(root);
base.outputDir = options.checkpointDir;
specs = landing2d.paper.representativeScenarios(base);
spec = specs(strcmp({specs.id},char(scenarioId)));
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
    fprintf('  deterministic actor mean; independent time-indexed sensor noise tables\n');
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

time = linspace(0,spec.scenario.deadline,options.timeSamples);
stats = cell(1,2); summaryRows = cell(1,2);
for m = 1:2
    [stats{m},summaryRows{m}] = summarizeRollouts(rollouts(m,:),time, ...
        options.minimumActiveFraction,methodIds{m},labels(m),files(m),trainSeeds(m));
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
fig = plotComparison(stats,time,labels,colors,spec,options,summary);

output = struct('schemaVersion','trajectory_mc_v1','generatedAt',datetime('now'), ...
    'scenario',spec,'environmentSeed',spec.seed,'policySeeds', ...
    options.policySeed+(0:options.numRuns-1),'numRuns',options.numRuns, ...
    'methodIds',{methodIds},'labels',labels,'trainSeeds',trainSeeds, ...
    'checkpointFiles',files,'taskFingerprint',fingerprints(1), ...
    'monteCarloSource',options.monteCarloSource, ...
    'policyNoiseMode',options.policyNoiseMode,'learnedSigma',learnedSigma, ...
    'evaluationSigma',evaluationSigma, ...
    'time',time,'statistics',{stats},'summary',summary,'figure',fig, ...
    'progressFigure',progressFigure);
if options.saveResults
    if ~isfolder(options.outputDir), mkdir(options.outputDir); end
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
    stem = sprintf('trajectory_mc_%s_%s',lower(char(scenarioId)),stamp);
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
    'scenario',spec.scenario,'sensorEvents',spec.sensorEvents);
[result,traj] = landing2d.rl.rolloutEpisodeV2(agent,arm,spec.seed,opts);
sample = struct('time',result.time,'x',result.xDrone,'z',result.zDrone, ...
    'xPad',result.xPad,'actionTime',traj.time, ...
    'requestedAcceleration',traj.requestedAcceleration, ...
    'terminalReason',result.terminalReason,'return',result.return);
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

function [s,row] = summarizeRollouts(samples,time,minActiveFraction,methodId,label,file,trainSeed)
n = numel(samples); nt = numel(time);
X = nan(n,nt); Z = nan(n,nt); AX = nan(n,nt); AZ = nan(n,nt);
for r = 1:n
    q = samples{r};
    X(r,:) = terminalHold(q.time,q.x,time);
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
scale = hypot(dx,dz); scale(scale<eps) = 1;
normalX = -dz./scale; normalZ = dx./scale;
normalDeviation = (X-meanX).*normalX+(Z-meanZ).*normalZ;
activeCount = sum(~isnan(AX),1);
actionMask = activeCount >= max(2,ceil(minActiveFraction*n));
meanAX = mean(AX,1,'omitnan'); meanAZ = mean(AZ,1,'omitnan');
stdAX = std(AX,0,1,'omitnan'); stdAZ = std(AZ,0,1,'omitnan');
meanAX(~actionMask)=NaN; meanAZ(~actionMask)=NaN;
stdAX(~actionMask)=NaN; stdAZ(~actionMask)=NaN;
reasons = string(cellfun(@(q)q.terminalReason,samples,'UniformOutput',false));
returns = cellfun(@(q)q.return,samples);
s = struct('meanX',meanX,'meanZ',meanZ,'varianceX',varianceX, ...
    'varianceZ',varianceZ,'covarianceXZ',covarianceXZ, ...
    'positionVariance',varianceX+varianceZ, ...
    'maxEigenVariance',maxEigenVariance,'normalX',normalX,'normalZ',normalZ, ...
    'normalVariance',var(normalDeviation,0,1,'omitnan'), ...
    'meanAction',[meanAX;meanAZ],'actionVariance',[stdAX.^2;stdAZ.^2], ...
    'activeCount',activeCount,'terminalReasons',reasons);
row = struct('MethodId',string(methodId),'Method',string(label), ...
    'TrainSeed',trainSeed,'Checkpoint',string(file),'Runs',n, ...
    'SuccessRate',mean(reasons=="SUCCESS"),'MeanReturn',mean(returns), ...
    'MeanPositionVariance_m2',mean(s.positionVariance,'omitnan'), ...
    'MeanNormalVariance_m2',mean(s.normalVariance,'omitnan'), ...
    'FinalXVariance_m2',s.varianceX(end),'FinalZVariance_m2',s.varianceZ(end), ...
    'MeanAxVariance_m2s4',mean(s.actionVariance(1,:),'omitnan'), ...
    'MeanAzVariance_m2s4',mean(s.actionVariance(2,:),'omitnan'));
end

function y = terminalHold(t,x,tq)
[t,uniqueIndex] = unique(t,'stable'); x = x(uniqueIndex);
y = interp1(t,x,tq,'linear',NaN);
y(tq<t(1)) = x(1); y(tq>t(end)) = x(end);
end

function fig = plotComparison(stats,time,labels,colors,spec,options,summary)
visibility = ternary(options.figureVisible,'on','off');
fig = figure('Name','Trajectory Monte Carlo consistency','Color','w', ...
    'Visible',visibility,'Position',[80 40 1320 860]);
layout = tiledlayout(fig,3,2,'TileSpacing','compact','Padding','compact');
axTrajectory = nexttile(layout,[3 1]); hold(axTrajectory,'on'); grid(axTrajectory,'on');
for m = 1:2
    drawTrajectoryBand(axTrajectory,stats{m},colors(m,:),options.sigmaMultiplier);
end
xlabel(axTrajectory,'x position [m]'); ylabel(axTrajectory,'z position [m]');
title(axTrajectory,sprintf('%s: mean trajectory and covariance envelope',spec.id));
axis(axTrajectory,'equal');
legend(axTrajectory,labels+" ±"+string(options.sigmaMultiplier)+"σ", ...
    'Location','best','Interpreter','none');
annotationText = sprintf(['R-GAT trajectory variance reduction: %.1f%%\n' ...
    'Success rate: PPO %.1f%% | R-GAT %.1f%%'], ...
    summary.TrajectoryVarianceReductionVsPPO_pct(2), ...
    100*summary.SuccessRate(1),100*summary.SuccessRate(2));
text(axTrajectory,0.02,0.02,annotationText,'Units','normalized', ...
    'VerticalAlignment','bottom','BackgroundColor','w','Margin',5, ...
    'EdgeColor',[0.75 0.75 0.75]);

axVariance = nexttile(layout); hold(axVariance,'on'); grid(axVariance,'on');
for m = 1:2
    plot(axVariance,time,stats{m}.positionVariance,'Color',colors(m,:), ...
        'LineWidth',1.8,'DisplayName',labels(m));
end
xlabel(axVariance,'Time [s]'); ylabel(axVariance,'Var(x)+Var(z) [m^2]');
title(axVariance,'Pointwise trajectory-position variance');
legend(axVariance,'Location','best','Interpreter','none');

actionNames = {'Requested a_x [m/s^2]','Requested a_z [m/s^2]'};
for a = 1:2
    ax = nexttile(layout); hold(ax,'on'); grid(ax,'on');
    for m = 1:2
        mu = stats{m}.meanAction(a,:);
        sd = sqrt(stats{m}.actionVariance(a,:));
        drawTimeBand(ax,time,mu,sd,colors(m,:),options.sigmaMultiplier);
    end
    xlabel(ax,'Time [s]'); ylabel(ax,actionNames{a});
    title(ax,sprintf('Policy action mean ± %.2gσ',options.sigmaMultiplier));
end
title(layout,sprintf(['Paired Monte Carlo (%d runs/method) | ' ...
    'fixed scenario/environment seed %d | %s'], ...
    options.numRuns,spec.seed,options.monteCarloSource));
end

function drawTrajectoryBand(ax,s,color,k)
% A normal-only ribbon hides along-track timing dispersion. The largest
% eigenvalue of the full 2-D position covariance gives a conservative tube
% around the mean trajectory while the adjacent panel shows its exact trace.
sd = sqrt(s.maxEigenVariance);
upperX = s.meanX+k*sd.*s.normalX; upperZ = s.meanZ+k*sd.*s.normalZ;
lowerX = s.meanX-k*sd.*s.normalX; lowerZ = s.meanZ-k*sd.*s.normalZ;
patch(ax,[upperX fliplr(lowerX)],[upperZ fliplr(lowerZ)],color, ...
    'FaceAlpha',0.18,'EdgeColor','none','HandleVisibility','off');
plot(ax,s.meanX,s.meanZ,'Color',color,'LineWidth',2.2);
end

function drawTimeBand(ax,time,mu,sd,color,k)
valid = isfinite(mu) & isfinite(sd);
segments = contiguousSegments(valid);
for i = 1:size(segments,1)
    q = segments(i,1):segments(i,2);
    patch(ax,[time(q) fliplr(time(q))], ...
        [mu(q)+k*sd(q) fliplr(mu(q)-k*sd(q))],color, ...
        'FaceAlpha',0.18,'EdgeColor','none','HandleVisibility','off');
end
plot(ax,time,mu,'Color',color,'LineWidth',1.8,'HandleVisibility','off');
end

function segments = contiguousSegments(mask)
edges = diff([false mask false]);
segments = [find(edges==1)' find(edges==-1)'-1];
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
validateattributes(options.sensorNoiseSeedStride,{'numeric'}, ...
    {'scalar','integer','positive','finite'});
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
