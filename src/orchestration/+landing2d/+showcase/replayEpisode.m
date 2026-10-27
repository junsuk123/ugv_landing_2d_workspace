function records = replayEpisode(runs,factor,episodeSeed,stored,verify)
% REPLAYEPISODE One stored OOD episode of every method, re-flown deterministically.
% Each run flies landing2d.rl.rolloutEpisodeV2 on its own protocol cell
% (landing2d.minimal.generalizationCondition(run.config,factor,'OOD')) with the
% stored episode seed. With VERIFY the replay must reproduce the stored study
% row (Success, Unsafe, FailureClass, AimErrorRMS_m), so the view shows exactly
% the evaluated episode. Besides the physical trajectory each record holds
%   metric      landing2d.evaluation.episodeMetrics row of the replay
%   base, correction   pre-tanh actor mean split into the base MLP and the
%               mixed correction sigma(beta)*correction (residual arms; 2 x n)
%   attention   first-hop attention on the edges into RelativeState (graph
%               arms; one row per edge, labelled with the edge's relation)
%   gate        qualifiesEstimate modulation of RelativeState (C3 only)
%   ablation    TOSM only: the same episode with the correction switched off
%               (sigma(beta) = 0, landing2d.bias_diagnostics.response convention):
%               its result, height and metric; a counterfactual, not a trained policy
% Display only: nothing here is fed back to a policy.
records = struct('methodId',{},'label',{},'color',{},'result',{},'traj',{},'metric',{}, ...
    'aim',{},'height',{},'base',{},'correction',{},'mix',{},'attention',{},'edgeLabels',{},'gate',{},'ablation',{});
for k = 1:numel(runs)
    run = runs(k);
    [envConfig,scale] = landing2d.minimal.generalizationCondition(run.config,char(factor),'OOD');
    [result,traj] = landing2d.rl.rolloutEpisodeV2(run.agent,envConfig,episodeSeed, ...
        struct('deterministic',true,'run',run.identity,'sensorNoiseScale',scale));
    metric = landing2d.evaluation.episodeMetrics(result,traj,envConfig, ...
        struct('MethodId',string(run.id),'EpisodeSeed',episodeSeed),[]);
    if verify
        s = stored(stored.MethodId==string(run.id) & stored.EpisodeSeed==episodeSeed,:);
        assert(height(s)==1 && s.Success==metric.Success && s.Unsafe==metric.Unsafe ...
            && string(s.FailureClass)==string(metric.FailureClass) ...
            && abs(s.AimErrorRMS_m-metric.AimErrorRMS_m)<=1e-9*max(1,abs(s.AimErrorRMS_m)), ...
            'landing2d:ShowcaseReplay','%s seed %d episode %d differs from the stored evaluation.', ...
            run.id,run.trainSeed,episodeSeed);
    end
    n = traj.count;
    heightAbovePad = result.zDrone-result.scenario.padHeight;
    rec = struct('methodId',string(run.id),'label',string(run.label),'color',run.color, ...
        'result',result,'traj',traj,'metric',metric, ...
        'aim',landing2d.evaluation.aimError(result.xPad,result.xDrone,heightAbovePad,envConfig), ...
        'height',heightAbovePad,'base',[],'correction',[],'mix',NaN,'attention',[],'edgeLabels',strings(0,1),'gate',[], ...
        'ablation',[]);
    if run.id=="onto_rgat_ppo"
        off = run.agent; off.policy.encoder.beta = -1000;   % 1/(1+exp(1000)) == 0
        [offResult,offTraj] = landing2d.rl.rolloutEpisodeV2(off,envConfig,episodeSeed, ...
            struct('deterministic',true,'sensorNoiseScale',scale));
        rec.ablation = struct('result',offResult,'height',offResult.zDrone-offResult.scenario.padHeight, ...
            'metric',landing2d.evaluation.episodeMetrics(offResult,offTraj,envConfig, ...
            struct('MethodId',"onto_rgat_ppo_correction_off",'EpisodeSeed',episodeSeed),[]));
    end
    spec = run.agent.encoderSpec;
    if strcmp(spec.mode,'residual_actor')
        [~,cache] = landing2d.graphstate.encoderForward(run.agent.policy.encoder,spec,traj.state(:,1:n),'policy');
        rec.base = cache.baseMean; rec.correction = cache.mix*cache.correction; rec.mix = cache.mix;
        if strcmp(spec.correctionType,'graph')
            schema = spec.schema; goal = schema.goalNode;   % RelativeState
            into = find(schema.dst==goal);
            rec.attention = cache.cache1.alpha(into,:);
            rec.edgeLabels = strings(numel(into),1);
            for e = 1:numel(into)
                rec.edgeLabels(e) = sprintf('%s->%s (%s)',abbreviation(schema.nodeNames{schema.src(into(e))}), ...
                    abbreviation(schema.nodeNames{goal}),schema.relationNames{schema.rel(into(e))});
            end
            if isfield(cache,'semantic')
                rec.gate = reshape(mean(cache.semantic.layers{end}.G(:,goal,:),1),1,[]);
            end
        end
    end
    records(end+1) = rec; %#ok<AGROW>
end
end

function s = abbreviation(name)
s = regexprep(name,'[a-z]','');   % ObservationQuality -> OQ, RelativeState -> RS
end
