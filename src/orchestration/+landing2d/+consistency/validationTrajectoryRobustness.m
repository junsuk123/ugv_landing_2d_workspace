function out = validationTrajectoryRobustness(agents,configs,options)
% VALIDATIONTRAJECTORYROBUSTNESS  Select policies by paired validation noise.
% Physical scenario, initial state, and exogenous events are fixed within
% each validation seed. Only the three time-indexed measurement-noise tables
% vary across repetitions, and every candidate receives the same realization.
% This function rejects test seeds and is intended for checkpoint/snapshot
% selection before the held-out split is opened.
if nargin < 3, options = struct(); end
assert(iscell(agents) && iscell(configs) && numel(agents)==numel(configs) ...
    && ~isempty(agents),'landing2d:ValidationRobustnessCandidates', ...
    'agents and configs must be nonempty, equally sized cell arrays.');
base = configs{1};
defaults = struct('labels',string(1:numel(agents)), ...
    'seeds',base.experiment.manifest.validationSeeds(1:min(20, ...
        numel(base.experiment.manifest.validationSeeds))), ...
    'replications',20,'sensorNoiseSeedStride',1009,'timeSamples',101, ...
    'parallel',true);
names = fieldnames(options);
for i = 1:numel(names)
    assert(isfield(defaults,names{i}),'landing2d:ValidationRobustnessOption', ...
        'Unknown option %s.',names{i});
    defaults.(names{i}) = options.(names{i});
end
o = defaults;
o.labels = string(o.labels);
o.seeds = double(o.seeds(:)');
validateattributes(o.replications,{'numeric'},{'scalar','integer','>=',2});
validateattributes(o.sensorNoiseSeedStride,{'numeric'}, ...
    {'scalar','integer','positive'});
validateattributes(o.timeSamples,{'numeric'},{'scalar','integer','>=',11});
assert(numel(o.labels)==numel(agents),'landing2d:ValidationRobustnessLabels', ...
    'One label is required per candidate.');
validationSeeds = base.experiment.manifest.validationSeeds;
assert(all(ismember(o.seeds,validationSeeds)) ...
    && isempty(intersect(o.seeds,base.experiment.manifest.testSeeds)), ...
    'landing2d:ValidationRobustnessSplit', ...
    'Trajectory-robustness selection may use validation seeds only.');
fingerprints = string(cellfun(@landing2d.environment.taskFingerprint, ...
    configs,'UniformOutput',false));
assert(all(fingerprints==fingerprints(1)), ...
    'landing2d:ValidationRobustnessTaskMismatch', ...
    'All candidates must share one task fingerprint.');

methodCount = numel(agents); seedCount = numel(o.seeds);
jobCount = methodCount*seedCount*o.replications;
samples = cell(methodCount,seedCount,o.replications);
useParallel = o.parallel && ~isempty(ver('parallel')) ...
    && ~isempty(gcp('nocreate'));
linearSamples = cell(jobCount,1);
if useParallel
    parfor job = 1:jobCount
        [m,s,r] = jobIndex(job,seedCount,o.replications); %#ok<PFBNS>
        linearSamples{job} = oneRollout(agents{m},configs{m},o.seeds(s), ...
            r,o.sensorNoiseSeedStride); %#ok<PFBNS>
    end
else
    for job = 1:jobCount
        [m,s,r] = jobIndex(job,seedCount,o.replications);
        linearSamples{job} = oneRollout(agents{m},configs{m},o.seeds(s), ...
            r,o.sensorNoiseSeedStride);
    end
end
for job = 1:jobCount
    [m,s,r] = jobIndex(job,seedCount,o.replications);
    samples{m,s,r} = linearSamples{job};
end
verifyPairing(samples);
episodeTable = outcomeTable(samples,o.labels,o.seeds);

rows = repmat(emptyRow(),methodCount,1);
details = cell(methodCount,seedCount);
for m = 1:methodCount
    seedMetrics = repmat(emptyMetrics(),seedCount,1);
    for s = 1:seedCount
        q = reshape(samples(m,s,:),1,[]);
        [seedMetrics(s),details{m,s}] = summarizeSeed(q,o.timeSamples);
    end
    rows(m) = summarizeCandidate(o.labels(m),seedMetrics);
end
summary = struct2table(rows);
reference = summary(1,:);
summary.TotalVarianceReductionVsReference_pct = 100*( ...
    reference.MeanPositionVariance_m2-summary.MeanPositionVariance_m2) ...
    /reference.MeanPositionVariance_m2;
summary.NormalVarianceReductionVsReference_pct = 100*( ...
    reference.MeanNormalVariance_m2-summary.MeanNormalVariance_m2) ...
    /reference.MeanNormalVariance_m2;
summary.FinalXVarianceReductionVsReference_pct = 100*( ...
    reference.MeanFinalRelativeXVariance_m2- ...
    summary.MeanFinalRelativeXVariance_m2) ...
    /reference.MeanFinalRelativeXVariance_m2;
summary.SuccessRateDeltaVsReference_pp = 100*( ...
    summary.SuccessRate-reference.SuccessRate);
summary.UnsafeRateDeltaVsReference_pp = 100*( ...
    summary.UnsafeRate-reference.UnsafeRate);
summary.MeanReturnDeltaVsReference = summary.MeanReturn-reference.MeanReturn;
summary.MeetsMissionSafetyAndDispersion = ...
    summary.SuccessRate>=reference.SuccessRate ...
    & summary.UnsafeRate<=reference.UnsafeRate ...
    & summary.MeanReturn>=reference.MeanReturn ...
    & summary.MeanPositionVariance_m2<reference.MeanPositionVariance_m2 ...
    & summary.MeanNormalVariance_m2<reference.MeanNormalVariance_m2 ...
    & summary.MeanFinalRelativeXVariance_m2< ...
        reference.MeanFinalRelativeXVariance_m2;
out = struct('schemaVersion','validation_trajectory_robustness_v1', ...
    'split','validation','seeds',o.seeds,'replications',o.replications, ...
    'sensorNoiseSeedStride',o.sensorNoiseSeedStride, ...
    'fixedVariables',{{'scenario and UGV trajectory','initial physical state', ...
        'dropout/pitch event schedule','dynamics and termination', ...
        'deterministic policy weights'}}, ...
    'variedVariables',{{'tracker noise table','marker-corner noise table', ...
        'navigation noise table'}},'pairedAcrossCandidates',true, ...
    'summary',summary,'episodes',episodeTable, ...
    'perSeed',{{details}},'options',o);
end

function [m,s,r] = jobIndex(job,seedCount,replications)
zero = job-1;
r = mod(zero,replications)+1;
zero = floor(zero/replications);
s = mod(zero,seedCount)+1;
m = floor(zero/seedCount)+1;
end

function sample = oneRollout(agent,c,seed,replication,stride)
streams = c.experiment.commonObservation.randomStreams;
delta = (replication-1)*stride;
streams.markerOffset = streams.markerOffset+delta;
streams.navigationOffset = streams.navigationOffset+delta;
streams.trackerOffset = streams.trackerOffset+delta;
c.experiment.commonObservation.randomStreams = streams;
opts = struct('deterministic',true,'collect',false,'rs',[]);
[result,~] = landing2d.rl.rolloutEpisodeV2(agent,c,seed,opts);
p = result.resetInfo.provenance;
sample = struct('time',result.time,'x',result.xDrone-result.xPad, ...
    'z',result.zDrone,'terminalReason',result.terminalReason, ...
    'return',result.return,'landingTime',result.landingTime, ...
    'scenario',result.scenario,'sensorEvents', ...
    result.resetInfo.evaluatorMetadata.sensorEvents, ...
    'initialPhysicalState',[result.xDrone(1),result.zDrone(1), ...
        result.vxDrone(1),result.vzDrone(1),result.theta(1),result.pitchRate(1)], ...
    'noiseSeeds',[p.trackerNoiseSeed,p.markerNoiseSeed,p.navigationNoiseSeed], ...
    'finalRelativeX',result.xDrone(end)-result.xPad(end), ...
    'finalRelativeVx',result.vxDrone(end)-result.vxPad(end), ...
    'finalVz',result.vzDrone(end),'finalTheta',result.theta(end));
end

function episodes = outcomeTable(samples,labels,seeds)
[methodCount,seedCount,replications] = size(samples);
n = methodCount*seedCount*replications;
candidate = strings(n,1); validationSeed = zeros(n,1);
replication = zeros(n,1); terminalReason = strings(n,1);
episodeReturn = zeros(n,1); landingTime = nan(n,1);
finalRelativeX = zeros(n,1); finalRelativeVx = zeros(n,1);
finalVz = zeros(n,1); finalTheta = zeros(n,1);
trackerNoiseSeed = zeros(n,1); markerNoiseSeed = zeros(n,1);
navigationNoiseSeed = zeros(n,1);
row = 0;
for m = 1:methodCount
    for s = 1:seedCount
        for r = 1:replications
            row = row+1; q = samples{m,s,r};
            candidate(row) = labels(m); validationSeed(row) = seeds(s);
            replication(row) = r; terminalReason(row) = q.terminalReason;
            episodeReturn(row) = q.return; landingTime(row) = q.landingTime;
            finalRelativeX(row) = q.finalRelativeX;
            finalRelativeVx(row) = q.finalRelativeVx;
            finalVz(row) = q.finalVz; finalTheta(row) = q.finalTheta;
            trackerNoiseSeed(row) = q.noiseSeeds(1);
            markerNoiseSeed(row) = q.noiseSeeds(2);
            navigationNoiseSeed(row) = q.noiseSeeds(3);
        end
    end
end
episodes = table(candidate,validationSeed,replication,terminalReason, ...
    episodeReturn,landingTime,finalRelativeX,finalRelativeVx,finalVz, ...
    finalTheta,trackerNoiseSeed,markerNoiseSeed,navigationNoiseSeed, ...
    'VariableNames',{'Candidate','ValidationSeed','Replication', ...
    'TerminalReason','Return','LandingTime_s','FinalRelativeX_m', ...
    'FinalRelativeVx_mps','FinalVz_mps','FinalTheta_rad', ...
    'TrackerNoiseSeed','MarkerNoiseSeed','NavigationNoiseSeed'});
end

function verifyPairing(samples)
[methodCount,seedCount,replications] = size(samples);
for s = 1:seedCount
    reference = samples{1,s,1};
    for m = 1:methodCount
        for r = 1:replications
            q = samples{m,s,r};
            assert(isequaln(q.scenario,reference.scenario) ...
                && isequaln(q.sensorEvents,reference.sensorEvents) ...
                && isequaln(q.initialPhysicalState,reference.initialPhysicalState), ...
                'landing2d:ValidationRobustnessFixedVariableDrift', ...
                'A fixed physical or exogenous variable changed.');
            assert(isequaln(q.noiseSeeds,samples{1,s,r}.noiseSeeds), ...
                'landing2d:ValidationRobustnessNoisePairing', ...
                'Candidates did not receive the same measurement-noise realization.');
        end
    end
    noiseRows = cellfun(@(q)q.noiseSeeds,reshape(samples(1,s,:),[],1), ...
        'UniformOutput',false);
    triplets = vertcat(noiseRows{:});
    assert(size(unique(triplets,'rows'),1)==replications, ...
        'landing2d:ValidationRobustnessNoiseVariation', ...
        'Every repetition must use a distinct noise-table seed triplet.');
end
end

function [metrics,detail] = summarizeSeed(samples,timeSamples)
n = numel(samples);
deadline = samples{1}.scenario.deadline;
time = linspace(0,deadline,timeSamples);
X = nan(n,timeSamples); Z = nan(n,timeSamples);
for r = 1:n
    X(r,:) = terminalHold(samples{r}.time,samples{r}.x,time);
    Z(r,:) = terminalHold(samples{r}.time,samples{r}.z,time);
end
meanX = mean(X,1,'omitnan'); meanZ = mean(Z,1,'omitnan');
dx = gradient(meanX,time); dz = gradient(meanZ,time);
[tx,tz] = persistentTangent(dx,dz);
normal = (X-meanX).*(-tz)+(Z-meanZ).*tx;
along = (X-meanX).*tx+(Z-meanZ).*tz;
positionVariance = var(X,0,1,'omitnan')+var(Z,0,1,'omitnan');
reasons = string(cellfun(@(q)q.terminalReason,samples,'UniformOutput',false));
unsafe = ismember(reasons,["UNSAFE_CONTACT","UNAUTHORIZED_CONTACT", ...
    "MISSED_PAD_CONTACT","SAFETY_ENVELOPE_VIOLATION"]);
finalX = cellfun(@(q)q.x(end),samples);
landingTime = cellfun(@(q)q.landingTime,samples);
metrics = struct('SuccessRate',mean(reasons=="SUCCESS"), ...
    'UnsafeRate',mean(unsafe),'MeanReturn',mean(cellfun(@(q)q.return,samples)), ...
    'MeanPositionVariance_m2',mean(positionVariance,'omitnan'), ...
    'MeanNormalVariance_m2',mean(var(normal,0,1,'omitnan'),'omitnan'), ...
    'MeanAlongTrackVariance_m2',mean(var(along,0,1,'omitnan'),'omitnan'), ...
    'FinalRelativeXVariance_m2',var(finalX,0,'omitnan'), ...
    'LandingTimeVariance_s2',var(landingTime,0,'omitnan'));
detail = struct('time',time,'meanX',meanX,'meanZ',meanZ, ...
    'positionVariance',positionVariance, ...
    'normalVariance',var(normal,0,1,'omitnan'), ...
    'alongTrackVariance',var(along,0,1,'omitnan'));
end

function row = summarizeCandidate(label,metrics)
row = emptyRow();
row.Candidate = label;
fields = fieldnames(metrics);
for i = 1:numel(fields)
    values = [metrics.(fields{i})];
    target = fields{i};
    if strcmp(target,'FinalRelativeXVariance_m2')
        target = 'MeanFinalRelativeXVariance_m2';
    elseif strcmp(target,'LandingTimeVariance_s2')
        target = 'MeanLandingTimeVariance_s2';
    end
    row.(target) = mean(values,'omitnan');
end
end

function row = emptyRow()
row = struct('Candidate',"",'SuccessRate',NaN,'UnsafeRate',NaN, ...
    'MeanReturn',NaN,'MeanPositionVariance_m2',NaN, ...
    'MeanNormalVariance_m2',NaN,'MeanAlongTrackVariance_m2',NaN, ...
    'MeanFinalRelativeXVariance_m2',NaN,'MeanLandingTimeVariance_s2',NaN);
end

function metrics = emptyMetrics()
metrics = rmfield(emptyRow(),'Candidate');
metrics.FinalRelativeXVariance_m2 = ...
    metrics.MeanFinalRelativeXVariance_m2;
metrics.LandingTimeVariance_s2 = metrics.MeanLandingTimeVariance_s2;
metrics = rmfield(metrics,{'MeanFinalRelativeXVariance_m2', ...
    'MeanLandingTimeVariance_s2'});
end

function y = terminalHold(t,x,tq)
[t,index] = unique(t,'stable'); x = x(index);
y = interp1(t,x,tq,'linear',NaN);
last = find(tq<=t(end)+1e-10,1,'last');
if ~isempty(last), y(last+1:end)=x(end); end
end

function [tx,tz] = persistentTangent(dx,dz)
speed = hypot(dx,dz); valid = speed>1e-8;
tx = zeros(size(dx)); tz = zeros(size(dz));
if ~any(valid), tx(:)=1; return; end
tx(valid)=dx(valid)./speed(valid); tz(valid)=dz(valid)./speed(valid);
first=find(valid,1,'first'); tx(1:first-1)=tx(first); tz(1:first-1)=tz(first);
for k=first+1:numel(tx)
    if ~valid(k), tx(k)=tx(k-1); tz(k)=tz(k-1); end
end
end
