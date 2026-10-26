function result = runGate()
% RUNGATE Registered H3 informativeness gate (TEST ONLY; rules in landing2d.ugv_accel.config).
% 1 writes gate_registration.json (rules, code SHA-256) before any flight
% 2 calibration on validation seeds 2001-2020 selects q_x of the CA KF
% 3 the gate runs once on seeds 2021-2040 with that q_x
% Writes gate_result.json (passed, selected q_x, every criterion) and the
% episode tables. Refuses an existing gate folder; never recalibrates.
root = landing2d.orchestration.projectRoot();
d = landing2d.ugv_accel.config(root,1);                % rules only; q is selected below
g = d.gate;
assert(~isfolder(g.outputDir),'landing2d:UgvAccelGate','Preserve the existing gate %s.',g.outputDir);
mkdir(g.outputDir);
files = [dir(fullfile(fileparts(mfilename('fullpath')),'*.m')); ...
    dir(fullfile(root,'src','simulations','+landing2d','+observation','*.m'))];
code = arrayfun(@(f)struct('path',relativePath(root,fullfile(f.folder,f.name)), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(fullfile(f.folder,f.name)))),files);
writeJson(fullfile(g.outputDir,'gate_registration.json'),struct('version',d.version, ...
    'registeredAtUtc',string(datetime('now','TimeZone','UTC')),'rules',g,'code',code, ...
    'driver','landing2d.probe.referenceDriver, driver noise 0','training',false));
if isempty(gcp('nocreate')), parpool('threads'); end

strata = {'CV',1;'CA',1;'CV',g.noiseScale;'CA',g.noiseScale};
rows = {};
for q = g.jerkGrid
    dq = landing2d.ugv_accel.config(root,q);
    for s = 1:size(strata,1)
        cs = family(dq,strata{s,1});
        episodes = fly(cs,g.calibrationSeeds,strata{s,2});
        mse = arrayfun(@(e)mean((e.estimate-e.truth).^2),episodes);
        rows{end+1} = table(q,string(strata{s,1}),strata{s,2},mean(mse),numel(mse), ...
            'VariableNames',{'JerkSpectralDensityX','Motion','NoiseScale','MeanMSE','Episodes'}); %#ok<AGROW>
    end
    fprintf('[gate] calibration q_x = %g done\n',q);
end
calibration = vertcat(rows{:});
score = groupsummary(calibration,'JerkSpectralDensityX','mean','MeanMSE');
score = sortrows(score,{'mean_MeanMSE','JerkSpectralDensityX'});
selected = score.JerkSpectralDensityX(1);
writetable(calibration,fullfile(g.outputDir,'calibration.csv'));
writetable(score,fullfile(g.outputDir,'calibration_score.csv'));
fprintf('[gate] selected q_x = %g\n',selected);

dq = landing2d.ugv_accel.config(root,selected);
training = fly(family(dq,'CA'),g.gateSeeds,1);
motion = fly(family(dq,'CA_v2'),g.gateSeeds,1);
noise = fly(family(dq,'CV'),g.gateSeeds,g.noiseScale);
[T1,s1] = tracking(training,g); [T2,s2] = tracking(motion,g);
rmsNoise = arrayfun(@(e)rmsInitialized(e),noise);
checks = [criterion("CA training x1","mean Pearson r",s1.r,g.minCorrelation,s1.r>=g.minCorrelation); ...
    criterion("CA training x1","mean NRMSE",s1.nrmse,g.maxNrmse,s1.nrmse<=g.maxNrmse); ...
    criterion("CA training x1","detection share",s1.detected,g.detectionShare,s1.detected>=g.detectionShare); ...
    criterion("CA v2 motion x1","mean Pearson r",s2.r,g.minCorrelation,s2.r>=g.minCorrelation); ...
    criterion("CA v2 motion x1","mean NRMSE",s2.nrmse,g.maxNrmse,s2.nrmse<=g.maxNrmse); ...
    criterion("CA v2 motion x1","detection share",s2.detected,g.detectionShare,s2.detected>=g.detectionShare); ...
    criterion("CV x3","mean estimate RMS [m/s^2]",mean(rmsNoise),g.maxNoiseRms,mean(rmsNoise)<=g.maxNoiseRms)];
writetable([T1;T2],fullfile(g.outputDir,'gate_episodes.csv'));
writetable(table([noise.seed]',rmsNoise(:),'VariableNames',{'Seed','EstimateRMS'}),fullfile(g.outputDir,'gate_noise.csv'));
writetable(checks,fullfile(g.outputDir,'gate_checks.csv'));
result = struct('version',d.version,'passed',all(checks.Pass),'selectedJerkSpectralDensityX',selected, ...
    'checks',checks,'finishedAtUtc',string(datetime('now','TimeZone','UTC')));
writeJson(fullfile(g.outputDir,'gate_result.json'),result);
disp(checks);
fprintf('[gate] passed = %d (q_x = %g)\n',result.passed,selected);
end

function c = family(d,motion)
base = d.c; base.evaluation = d.v5.evaluation;
switch motion
    case 'CV'
        c = base; c.experiment.scenario.constantVelocityProbability = 1;
    case 'CA'
        c = landing2d.minimal.generalizationCondition(base,'motion','ID');
    case 'CA_v2'
        c = landing2d.minimal.generalizationCondition(base,'motion','OOD');
end
end

function episodes = fly(c,seeds,noiseScale)
parts = cell(1,numel(seeds));
parfor i = 1:numel(seeds)
    parts{i} = landing2d.ugv_accel.referenceEpisode(c,seeds(i),noiseScale);
end
episodes = [parts{:}];
end

function [T,summary] = tracking(episodes,g)
n = numel(episodes); r = zeros(n,1); nrmse = ones(n,1); delay = Inf(n,1); detected = false(n,1);
complete = false(n,1);
for i = 1:n
    e = episodes(i);
    w = e.time>=e.T1-g.window-1e-9 & e.time<=e.T1+e.T2+g.window+1e-9;
    complete(i) = e.endTime>=e.T1+e.T2+g.window && any(w) && all(e.initialized(w));
    if complete(i) && std(e.estimate(w))>0 && std(e.truth(w))>0
        cc = corrcoef(e.estimate(w),e.truth(w)); r(i) = cc(1,2);
        nrmse(i) = sqrt(mean((e.estimate(w)-e.truth(w)).^2))/sqrt(mean(e.truth(w).^2));
    end
    phase = find(e.time>=e.T1-1e-9 & e.time<e.T1+e.T2-1e-9);
    ok = sign(e.estimate(phase))==sign(e.truth(phase)) & abs(e.estimate(phase))>=abs(e.truth(phase))/2 ...
        & e.initialized(phase);
    k = find(ok(1:end-1) & ok(2:end),1);
    if ~isempty(k)
        delay(i) = e.time(phase(k+1))-e.T1;
        detected(i) = delay(i)<=min(g.detectionDelay,e.T2/2)+1e-9;
    end
end
T = table([episodes.seed]',repmat(episodes(1).a2>=1.5,n,1),[episodes.T1]',[episodes.T2]',[episodes.a2]', ...
    complete,r,nrmse,delay,detected,'VariableNames',{'Seed','V2Motion','T1','T2','A2', ...
    'CompleteWindow','PearsonR','NRMSE','DetectionDelay','DetectedInTime'});
summary = struct('r',mean(r),'nrmse',mean(nrmse),'detected',mean(detected));
end

function v = rmsInitialized(e)
v = Inf;
if any(e.initialized), v = sqrt(mean(e.estimate(e.initialized).^2)); end
end

function row = criterion(family,metric,value,threshold,pass)
row = table(family,metric,value,threshold,pass,'VariableNames',{'Family','Metric','Value','Threshold','Pass'});
end

function writeJson(file,value)
fid = fopen(file,'w','n','UTF-8'); assert(fid>=0);
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char'); fclose(fid);
end

function p = relativePath(root,file)
p = strrep(erase(string(file),string(root)+filesep),'\','/');
end
