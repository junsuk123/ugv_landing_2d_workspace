function out = closedLoopJerk(c,options)
% CLOSEDLOOPJERK  Closed-loop J_policy of trained runs on the fixed probe episodes.
%   out = landing2d.consistency.closedLoopJerk(c,struct('trainSeeds',1))
% Every registered run whose checkpoint exists and matches its training
% signature (landing2d.consistency.loadRun) flies the same split seeds as the
% probe banks (first c.consistency.probe.<split>EpisodeCount seeds of the
% manifest; deterministic policy, nominal sensor noise) with the command log on.
% J_policy and the supervisor-applied jerk come from
% landing2d.consistency.policyJerk inside the exogenous steady windows of each
% episode. Commands of diverged closed-loop trajectories are never paired
% across runs (that is D_obs/D_seed on the fixed probes). With an open pool
% evaluateV2 runs the episodes in parallel (same results).
%   episodes  one row per run and episode: terminal reason, J_policy (norm and
%             per axis), J_applied, steady-window seconds, rate samples, weights
%   perRun    per run: J_policy/J_applied pooled over all windows of all
%             episodes (time-weighted RMS), episode mean/median, episodes
%             without a window, and the terminal-outcome rates of the episodes
%   missing   runs without a compatible checkpoint
if nargin < 2, options = struct(); end
registry = landing2d.config.methodRegistry();
known = [registry.methods,registry.ablations]; % ablations only when requested
defaults = struct('split','test','methods',{{registry.methods.id}},'trainSeeds',1, ...
    'graphSeeds',1);
names = fieldnames(options);
for i = 1:numel(names)
    assert(isfield(defaults,names{i}),'landing2d:ClosedLoopJerkOption', ...
        'Unknown option %s.',names{i});
    defaults.(names{i}) = options.(names{i});
end
options = defaults;
manifest = c.experiment.manifest;
switch options.split
    case 'test'
        seeds = manifest.testSeeds(1:c.consistency.probe.testEpisodeCount);
    case 'validation'
        seeds = manifest.validationSeeds(1:c.consistency.probe.validationEpisodeCount);
    otherwise
        error('landing2d:ProbeSplit','Unknown split %s.',options.split);
end
episodes = table(); perRun = table();
missing = strings(0,1);
for m = 1:numel(options.methods)
    index = find(strcmp({known.id},options.methods{m}),1);
    method = known(index);
    graphSeeds = NaN;
    if ~strcmp(method.graphPerturbation,'none'), graphSeeds = options.graphSeeds; end
    for g = graphSeeds(:)'
        for s = options.trainSeeds(:)'
            arm = landing2d.config.applyMethod(c,method.id,s,g);
            [agent,~,file,ok] = landing2d.consistency.loadRun(arm);
            if ~ok
                missing(end+1,1) = string(arm.rl.policyFile); %#ok<AGROW>
                continue;
            end
            run = landing2d.rl.runIdentity(agent,arm,file);
            [~,configHash] = landing2d.util.resolvedConfig(arm);
            [results,~,info] = landing2d.rl.evaluateV2(agent,arm,seeds, ...
                struct('commandLog',true,'run',run,'configHash',configHash, ...
                'sensorNoiseScale',c.consistency.nominalScale));
            jerk = arrayfun(@(r)landing2d.consistency.policyJerk(r.commandLog, ...
                c.consistency.jerk),results);
            n = numel(results);
            id = table(repmat(string(method.id),n,1),repmat(s,n,1),repmat(g,n,1), ...
                'VariableNames',{'MethodId','TrainSeed','GraphSeed'});
            rows = [id,table(seeds(:),string({results.terminalReason})', ...
                arrayfun(@(r)r.commandLog.truth.time(end),results(:)), ...
                [jerk.J_policy]',vertcat(jerk.J_policyAxis),[jerk.J_applied]', ...
                [jerk.windowSeconds]',[jerk.policySamples]',[jerk.policyWeight]', ...
                [jerk.appliedWeight]','VariableNames',{'EpisodeSeed','TerminalReason', ...
                'Duration','J_policy','J_policyAxis','J_applied','WindowSeconds', ...
                'PolicySamples','PolicyWeight','AppliedWeight'})];
            episodes = [episodes;rows]; %#ok<AGROW>
            perRun = [perRun;[id(1,:),table(string(run.GraphHash), ...
                run.RelationalPathActive,n,sum(rows.PolicyWeight>0), ...
                pooled(rows.J_policy,rows.PolicyWeight), ...
                mean(rows.J_policy,'omitnan'),median(rows.J_policy,'omitnan'), ...
                pooled(rows.J_applied,rows.AppliedWeight), ...
                100*info.landingRate,100*info.unsafeRate,100*info.safeAbortRate, ...
                100*info.timeoutRate,'VariableNames',{'GraphHash', ...
                'RelationalPathActive','Episodes','EpisodesWithWindow','J_policy', ...
                'J_policy_episodeMean','J_policy_episodeMedian','J_applied', ...
                'LandingPct','UnsafePct','SafeAbortPct','TimeoutPct'})]]; %#ok<AGROW>
        end
    end
end
out = struct('split',options.split,'seeds',seeds,'episodes',episodes, ...
    'perRun',perRun,'missing',missing);
end

function value = pooled(J,weight)
% Time-weighted RMS over episodes from per-episode RMS and rate-interval weights.
in = weight > 0 & isfinite(J);
value = sqrt(sum(J(in).^2.*weight(in))/sum(weight(in)));
if ~any(in), value = NaN; end
end
