function checkGeneralization()
% CHECKGENERALIZATION Fixed ranges, matched causes and seed-level statistics.
c = landing2d.minimal.config(); g = c.evaluation.generalization;
assert(g.oodA2Range(1)>c.experiment.scenario.a2Range(2));
assert(g.oodDropoutDuration(1)>c.experiment.sensor.perturbation.severeDropoutDuration(2));
assert(g.oodNoiseScale>1);
assert(isempty(intersect(c.experiment.manifest.stressSeeds(1:100), ...
    c.experiment.manifest.stressSeeds(101:200))));
for factor = g.conditions
    [id,ni] = landing2d.minimal.generalizationCondition(c,factor{1},'ID');
    [ood,no] = landing2d.minimal.generalizationCondition(c,factor{1},'OOD');
    switch factor{1}
        case 'motion'
            restored = ood; restored.experiment.scenario.a2Range = id.experiment.scenario.a2Range;
            assert(isequaln(restored,id) && ni==no);
        case 'dropout'
            restored = ood;
            restored.experiment.sensor.perturbation.severeDropoutDuration = ...
                id.experiment.sensor.perturbation.severeDropoutDuration;
            assert(isequaln(restored,id) && ni==no);
        case 'noise'
            assert(isequaln(id,ood) && ni==1 && no==g.oodNoiseScale);
    end
    % Common episode draws keep initial conditions, timing and exogenous
    % event onset fixed; compare sampled parameters without policy outcomes.
    for seed = c.experiment.manifest.stressSeeds(:)'
        base = c.experiment.scenario.baseSeed+seed;
        scSeed = base+c.experiment.randomStreams.scenarioOffset;
        a = landing2d.scenario.sampleParameters(id.experiment.scenario,scSeed);
        b = landing2d.scenario.sampleParameters(ood.experiment.scenario,scSeed);
        for name = {'v1','T1','T2','T3','height','initialSpeedOffset','initialPositionOffset','deadline'}
            assert(isequaln(a.(name{1}),b.(name{1})),'Condition changes an unregistered scenario factor.');
        end
        sensorSeed = base+c.experiment.randomStreams.sensorOffset;
        ea = landing2d.sensing.sampleEvents(id.experiment.sensor,a,RandStream('threefry','Seed',sensorSeed));
        eb = landing2d.sensing.sampleEvents(ood.experiment.sensor,b,RandStream('threefry','Seed',sensorSeed));
        assert(ea.dropoutStart==eb.dropoutStart && strcmp(ea.dropoutKind,eb.dropoutKind));
        if strcmp(factor{1},'motion'), assert(a.a2<=.8 && b.a2>=1); end
        if strcmp(factor{1},'dropout')
            assert(ea.dropoutEnd-ea.dropoutStart<=1+1e-12 ...
                && eb.dropoutEnd-eb.dropoutStart>=1.2-1e-12);
        end
    end
end
% Synthetic TEST ONLY fixture. Every seed has two episodes in each cell.
% Known macro rate 1/2 and a 1/2 drop; repeated episodes must not inflate n.
rows = {};
for seed = [251,252]
    for factor = g.conditions
        for shift = {'ID','OOD'}
            for episode = 1:2
                rows{end+1} = struct('MethodId',"onto_rgat_ppo",'Method',"TEST ONLY", ...
                    'TrainSeed',seed,'Factor',string(factor{1}),'Shift',string(shift{1}), ...
                    'EpisodeSeed',9000+episode,'Success',double(strcmp(shift{1},'ID') || episode==1), ...
                    'Unsafe',0,'AimErrorRMS_m',1,'CommandRateRMS_mps3',1); %#ok<AGROW>
            end
        end
    end
end
T = struct2table([rows{:}]); out = landing2d.minimal.generalizationSummary(T);
assert(all(out.primaryBySeed.OODSuccess==.5) && all(out.primaryBySeed.SuccessDrop==.5));
assert(out.primarySummary.Seeds==2 && out.primarySummary.OODSuccess_n==2);
baseline = T; baseline.MethodId(:) = "ppo"; baseline.Method(:) = "TEST ONLY PPO";
baseline.Success(baseline.Shift=="OOD") = double(baseline.TrainSeed(baseline.Shift=="OOD")==252);
shuffled = T; shuffled.MethodId(:) = "shuffled_rgat_ppo"; shuffled.Method(:) = "TEST ONLY Shuffled";
shuffled.Success(shuffled.Shift=="OOD") = 0;
full = landing2d.minimal.generalizationSummary([T;baseline;shuffled]);
C = full.primaryContrasts; C = C(C.MethodB=="ppo",:);
% With two seeds, t_1 is Cauchy; differences [.5,-.5] have SE=.5.
expectedHalf = .5/tan(pi*.0125);
assert(C.Seeds==2 && abs(C.PrimaryUpper-expectedHalf)<1e-9 ...
    && abs(C.PrimaryLower+expectedHalf)<1e-9,'Primary family interval is incorrect.');
bad = T; bad(1,:) = []; rejected = false;
try
    landing2d.minimal.generalizationSummary(bad);
catch err
    rejected = strcmp(err.identifier,'landing2d:GeneralizationPair');
end
assert(rejected,'Incomplete paired episodes were silently accepted.');
% Evaluation changes must preserve exact old signatures in every arm.
for method = {'ppo','onto_rgat_ppo','shuffled_rgat_ppo'}
    a = landing2d.config.applyMethod(c,method{1},251); b = a;
    b.evaluation = landing2d.config.defaultEvaluationConfig();
    assert(isequaln(landing2d.rl.trainingSignature(a),landing2d.rl.trainingSignature(b)));
end
end
