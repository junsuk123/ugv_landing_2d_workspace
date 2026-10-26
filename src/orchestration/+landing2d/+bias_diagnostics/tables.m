function out = tables(d,S,P,importance,phases,episodes,B,X,runs)
% TABLES Seed-level tables for Q1-Q4 and P6; field names are 'folder__file'.
% Every metric is first reduced to one value per training seed (states,
% episodes and branches are within-seed samples), then summarized over seeds.
pairs = d.contrasts; out = struct();
v2 = readtable(fullfile(d.v2Evaluation,'generalizationBySeed.csv'),'TextType','string');
primary = readtable(fullfile(d.v2Evaluation,'primaryBySeed.csv'),'TextType','string');
outcome = outcomes(v2,primary);

% Q1 state similarity --------------------------------------------------------
q1 = {'NormSensitivity','NoiseStdX','NoiseStdZ','KLNoise'};
Pall = P; Pall.Class(:) = "all";
q1Seed = [seedMean([P;Pall],{'MethodId','TrainSeed','Family','Class'},q1), ...
    seedMedian([P;Pall],{'MethodId','TrainSeed','Family','Class'},{'NormSensitivity'},'Median')];
out.q1_state_similarity__probe_rows = P;
out.q1_state_similarity__by_seed = q1Seed;
[out.q1_state_similarity__method_summary,out.q1_state_similarity__contrasts] = ...
    landing2d.bias_diagnostics.summarize(q1Seed,{'Family','Class'},[q1,{'NormSensitivityMedian'}],pairs);
out.q1_state_similarity__input_importance = importance;
[out.q1_state_similarity__input_importance_summary,~] = landing2d.bias_diagnostics.summarize( ...
    importance,{'Axis','Input'},{'MeanAbsScaledJacobian'},pairs);
motion = P(P.Family=="motion_v2",:);
link = join([seedMean(motion,{'MethodId','TrainSeed'},{'NormSensitivity','NoiseStdX','KLNoise','KLUgv'}), ...
    seedMedian(motion,{'MethodId','TrainSeed'},{'RugvX','RdroneX','RposX'},'Median')],outcome);
out.q1_state_similarity__performance_link = link;
out.q1_state_similarity__performance_correlation = correlations(link, ...
    {'NormSensitivity','NoiseStdX','KLNoise','RugvXMedian','RdroneXMedian','RposXMedian'}, ...
    {'MotionOODSuccess','MotionOODAimRMS_m','MotionOODUnsafe','NoiseOODSuccess','OODSuccess'});

% Q2 state-dependent action --------------------------------------------------
q2 = {'RugvX','RdroneX','RposX','StaleDeltaX','AgreeUgvX','AgreeDroneX','AgreePosX', ...
    'ReferenceRugvX','ReferenceRdroneX','ReferenceRposX','ReferenceStaleDeltaX'};
q2Seed = seedMean(P,{'MethodId','TrainSeed','Family'},q2);
out.q2_state_dependent_action__by_seed = q2Seed;
[out.q2_state_dependent_action__method_summary,out.q2_state_dependent_action__contrasts] = ...
    landing2d.bias_diagnostics.summarize(q2Seed,{'Family'},q2,pairs);
out.q2_state_dependent_action__branch_rows = B;
branchSeed = branchSummary(B);
out.q2_state_dependent_action__branch_by_seed = branchSeed;
branchMetrics = {'PolicyBestReturn','AdvantageMinus','AdvantagePlus','SuccessPolicy', ...
    'SuccessMinus','SuccessPlus','AimPolicy','AimMinus','AimPlus'};
[out.q2_state_dependent_action__branch_summary,out.q2_state_dependent_action__branch_contrasts] = ...
    landing2d.bias_diagnostics.summarize(branchSeed,{'Point'},branchMetrics,pairs);

% Q3 reward density ----------------------------------------------------------
names = {'goal','view','control','readiness','shaping','terminal'};
out.q3_reward_density__phase_rows = phases;
out.q3_reward_density__episode_outcomes = episodes;
q3Seed = rewardSeed(phases,{'MethodId','TrainSeed','Phase'},names);
out.q3_reward_density__by_seed = q3Seed;
out.q3_reward_density__by_seed_cell = rewardSeed(phases,{'MethodId','TrainSeed','Factor','Shift','Phase'},names);
q3Metrics = [strcat(names,'PerStep'),strcat(names,'AbsPerStep'),strcat(names,'Nonzero'),strcat(names,'Share')];
[out.q3_reward_density__method_summary,out.q3_reward_density__contrasts] = ...
    landing2d.bias_diagnostics.summarize(q3Seed,{'Phase'},q3Metrics,pairs);
pooled = phases; pooled.MethodId(:) = "pooled"; pooled.TrainSeed(:) = 0;
out.q3_reward_density__pooled_composition = rewardSeed(pooled,{'Phase'},names);

% Q4 action topology ---------------------------------------------------------
q4Seed = actionSeed(phases,{'MethodId','TrainSeed','Phase'});
out.q4_action_topology__by_seed = q4Seed;
q4Metrics = {'SaturationX','SaturationZ','InterventionRate','RequestedAppliedGap', ...
    'CommandRateRmsX','CommandRateRmsZ','MeanAbsMuX','MeanAbsMuZ'};
[out.q4_action_topology__method_summary,out.q4_action_topology__contrasts] = ...
    landing2d.bias_diagnostics.summarize(q4Seed,{'Phase'},q4Metrics,pairs);
sigma = table(string({runs.id})',[runs.trainSeed]', ...
    arrayfun(@(r)exp(r.agent.policy.logStd(1)),runs)',arrayfun(@(r)exp(r.agent.policy.logStd(2)),runs)', ...
    'VariableNames',{'MethodId','TrainSeed','SigmaX','SigmaZ'});
probeTopology = join(seedMean(P,{'MethodId','TrainSeed','Family'}, ...
    {'KLNoise','KLUgv','NoiseStdX','NoiseStdZ','SaturatedX','SaturatedZ'}),sigma);
out.q4_action_topology__probe_by_seed = probeTopology;
[out.q4_action_topology__probe_summary,out.q4_action_topology__probe_contrasts] = ...
    landing2d.bias_diagnostics.summarize(probeTopology,{'Family'}, ...
    {'KLNoise','KLUgv','NoiseStdX','SaturatedX','SigmaX','SigmaZ'},pairs);
motionPhases = phases(phases.Factor=="motion" & phases.Shift=="OOD",:);
topologyLink = join(join(actionSeed(motionPhases,{'MethodId','TrainSeed'}), ...
    seedMean(motion,{'MethodId','TrainSeed'},{'KLNoise','KLUgv'})),outcome);
out.q4_action_topology__performance_link = topologyLink;
out.q4_action_topology__performance_correlation = correlations(topologyLink, ...
    {'CommandRateRmsX','SaturationX','InterventionRate','KLNoise','KLUgv'}, ...
    {'MotionOODSuccess','MotionOODAimRMS_m','MotionOODUnsafe'});

% P6 relation effect ---------------------------------------------------------
residual = P(~isnan(P.CorrectionOff),:);
residual.CorrectionShare = residual.CorrectionRms./max(residual.BaseMeanRms,eps);
correction = seedMean(residual,{'MethodId','TrainSeed','Family'},{'CorrectionOff','CorrectionShare'});
ablation = ablationTable(d.ablationSummary);
out.p6_relation_effect__correction_off_by_seed = correction;
out.p6_relation_effect__correction_off_closed_loop = ablation;
out.p6_relation_effect__typing_swap_rows = X;
swap = swapSeed(X);
probeSwap = seedMean(P(~isnan(P.TypingSwap),:),{'MethodId','TrainSeed','Family'},{'TypingSwap'});
out.p6_relation_effect__typing_swap_by_seed = swap;
out.p6_relation_effect__typing_swap_probe_by_seed = probeSwap;
decomposition = decompose(outcome,ablation,swap);
out.p6_relation_effect__decomposition_by_seed = decomposition;
out.p6_relation_effect__decomposition_summary = componentSummary(decomposition);
end

function T = outcomes(v2,primary)
pick = @(f,name)renamevars(v2(v2.Factor==f & v2.Shift=="OOD",{'MethodId','TrainSeed','Success','Unsafe','AimErrorRMS_m'}), ...
    {'Success','Unsafe','AimErrorRMS_m'},strcat(name,{'Success','Unsafe','AimRMS_m'}));
T = join(join(join(pick("motion","MotionOOD"),pick("noise","NoiseOOD")),pick("dropout","DropoutOOD")), ...
    primary(:,{'MethodId','TrainSeed','OODSuccess'}));
end

function T = seedMean(T,keys,metrics)
[g,T0] = findgroups(T(:,keys));
for m = metrics, T0.(m{1}) = splitapply(@(x)mean(x,'omitnan'),double(T.(m{1})),g); end
T0.States = splitapply(@numel,T.(metrics{1}),g); T = T0;
end

function T = seedMedian(T,keys,metrics,suffix)
[g,T0] = findgroups(T(:,keys));
for m = metrics, T0.([m{1},suffix]) = splitapply(@(x)median(x,'omitnan'),double(T.(m{1})),g); end
T = T0(:,setdiff(T0.Properties.VariableNames,keys,'stable'));
end

function R = correlations(T,metrics,targets)
rows = {};
for m = metrics
    for t = targets
        rows{end+1} = table(string(m{1}),string(t{1}), ...
            landing2d.bias_diagnostics.spearman(T.(m{1}),T.(t{1})),sum(isfinite(T.(m{1}))&isfinite(T.(t{1}))), ...
            'VariableNames',{'Metric','Outcome','SpearmanRho','Models'}); %#ok<AGROW>
    end
end
R = vertcat(rows{:});
end

function T = branchSummary(B)
[g,T] = findgroups(B(:,{'MethodId','TrainSeed','EnvironmentSeed','Point'}));
value = @(field,delta)splitapply(@(dl,v)pickDelta(dl,v,delta),B.Delta,B.(field),g);
R0 = value('ReturnToGo',0); Rm = value('ReturnToGo',-0.25); Rp = value('ReturnToGo',0.25);
T.PolicyBestReturn = double(R0>=max(Rm,Rp)); T.AdvantageMinus = Rm-R0; T.AdvantagePlus = Rp-R0;
T.SuccessPolicy = value('Success',0); T.SuccessMinus = value('Success',-0.25); T.SuccessPlus = value('Success',0.25);
T.AimPolicy = value('AimRmsHorizon',0); T.AimMinus = value('AimRmsHorizon',-0.25); T.AimPlus = value('AimRmsHorizon',0.25);
T = seedMean(T,{'MethodId','TrainSeed','Point'},{'PolicyBestReturn','AdvantageMinus','AdvantagePlus', ...
    'SuccessPolicy','SuccessMinus','SuccessPlus','AimPolicy','AimMinus','AimPlus'});
end

function v = pickDelta(deltas,values,delta)
k = find(abs(deltas-delta)<1e-12); assert(isscalar(k)); v = values(k);
end

function T = rewardSeed(phases,keys,names)
[g,T] = findgroups(phases(:,keys));
T.Steps = splitapply(@sum,phases.Steps,g); T.Seconds = splitapply(@sum,phases.Seconds,g);
total = zeros(height(T),1);
for j = 1:numel(names), total = total+splitapply(@sum,phases.([names{j},'AbsSum']),g); end
for j = 1:numel(names)
    n = names{j};
    T.([n,'PerStep']) = splitapply(@sum,phases.([n,'Sum']),g)./T.Steps;
    T.([n,'AbsPerStep']) = splitapply(@sum,phases.([n,'AbsSum']),g)./T.Steps;
    T.([n,'Nonzero']) = splitapply(@sum,phases.([n,'Nonzero']),g)./T.Steps;
    T.([n,'Share']) = splitapply(@sum,phases.([n,'AbsSum']),g)./max(total,eps);
end
end

function T = actionSeed(phases,keys)
[g,T] = findgroups(phases(:,keys));
steps = splitapply(@sum,phases.Steps,g); rateCount = splitapply(@sum,phases.RateCount,g);
T.SaturationX = splitapply(@sum,phases.SaturatedX,g)./steps;
T.SaturationZ = splitapply(@sum,phases.SaturatedZ,g)./steps;
T.InterventionRate = splitapply(@sum,phases.Intervened,g)./steps;
T.RequestedAppliedGap = splitapply(@sum,phases.RequestedAppliedGapSum,g)./steps;
T.CommandRateRmsX = sqrt(splitapply(@sum,phases.RateSqX,g)./max(rateCount,1));
T.CommandRateRmsZ = sqrt(splitapply(@sum,phases.RateSqZ,g)./max(rateCount,1));
T.MeanAbsMuX = splitapply(@sum,phases.MuAbsX,g)./steps;
T.MeanAbsMuZ = splitapply(@sum,phases.MuAbsZ,g)./steps;
T.Steps = steps;
end

function T = ablationTable(file)
s = jsondecode(fileread(file)); keys = fieldnames(s.by_seed_success_change);
rows = cell(numel(keys),1);
for i = 1:numel(keys)
    % jsondecode makes valid field names: method_factor_seed with x prefix when needed
    raw = string(keys{i}); parts = regexp(raw,'^(.*)_(motion|noise|dropout)_(\d+)$','tokens','once');
    rows{i} = table(string(parts{1}),string(parts{2}),str2double(parts{3}), ...
        s.by_seed_success_change.(keys{i}),'VariableNames',{'MethodId','Factor','TrainSeed','SuccessChangeOff'});
end
T = sortrows(vertcat(rows{:}),{'Factor','MethodId','TrainSeed'});
end

function T = swapSeed(X)
[g,T] = findgroups(X(:,{'MethodId','TrainSeed','Variant'}));
T.Success = splitapply(@mean,X.Success,g); T.Unsafe = splitapply(@mean,X.Unsafe,g);
T.AimRMS_m = splitapply(@mean,X.AimErrorRMS_m,g); T.Episodes = splitapply(@numel,X.Success,g);
own = renamevars(removevars(T(T.Variant=="own",:),'Variant'), ...
    {'Success','Unsafe','AimRMS_m'},{'OwnSuccess','OwnUnsafe','OwnAimRMS_m'});
other = renamevars(removevars(T(T.Variant=="partnerTyping",:),{'Variant','Episodes'}), ...
    {'Success','Unsafe','AimRMS_m'},{'PartnerTypingSuccess','PartnerTypingUnsafe','PartnerTypingAimRMS_m'});
T = join(own,other,'Keys',{'MethodId','TrainSeed'});
T.SuccessChange = T.PartnerTypingSuccess-T.OwnSuccess;
end

function T = decompose(outcome,ablation,swap)
% Three separable quantities per training seed (descriptive):
%   graphPath  closed-loop motion-OOD success change when the trained graph
%              correction is removed (dependence of a trained policy, not a
%              model trained without it)
%   structure  Shuffled - Residual-MLP: graph message passing with non-semantic
%              typing versus a same-size MLP correction (same base, same inputs)
%   typing     TOSM - Shuffled: semantic versus shuffled typing on the same topology
%   typingDependence  success change when a trained graph actor uses its
%              partner's typing (same parameters)
rows = {};
valueOf = @(m,s,field)outcome.(field)(outcome.MethodId==m & outcome.TrainSeed==s);
for s = unique(outcome.TrainSeed)'
    for metric = ["MotionOODSuccess","OODSuccess","NoiseOODSuccess"]
        rows{end+1} = row("structure",metric,s,valueOf("shuffled_rgat_ppo",s,metric)-valueOf("residual_mlp_ppo",s,metric)); %#ok<AGROW>
        rows{end+1} = row("typing",metric,s,valueOf("onto_rgat_ppo",s,metric)-valueOf("shuffled_rgat_ppo",s,metric)); %#ok<AGROW>
    end
    for m = ["onto_rgat_ppo","shuffled_rgat_ppo","residual_mlp_ppo"]
        v = ablation.SuccessChangeOff(ablation.MethodId==m & ablation.TrainSeed==s & ablation.Factor=="motion");
        rows{end+1} = row("graphPath:"+m,"MotionOODSuccessChangeOff",s,v); %#ok<AGROW>
        v = swap.SuccessChange(swap.MethodId==m & swap.TrainSeed==s);
        if ~isempty(v), rows{end+1} = row("typingDependence:"+m,"MotionOODSuccessChangeSwap",s,v); end %#ok<AGROW>
    end
end
T = vertcat(rows{:});
end

function r = row(component,metric,seed,value)
r = table(string(component),string(metric),seed,value,'VariableNames',{'Component','Metric','TrainSeed','Value'});
end

function T = componentSummary(D)
[g,T] = findgroups(D(:,{'Component','Metric'}));
T.Mean = splitapply(@mean,D.Value,g); T.SD = splitapply(@std,D.Value,g);
T.Seeds = splitapply(@numel,D.Value,g); T.PositiveSeeds = splitapply(@(v)sum(v>0),D.Value,g);
T.NegativeSeeds = splitapply(@(v)sum(v<0),D.Value,g);
q = arrayfun(@(n)betaincinv(0.05,(n-1)/2,0.5),T.Seeds);
hw = sqrt((T.Seeds-1).*(1-q)./q).*T.SD./sqrt(T.Seeds);
T.CI95Low = T.Mean-hw; T.CI95High = T.Mean+hw;
end
