function gate = developmentGate(runs,results,seeds)
% DEVELOPMENTGATE The v5 development rule (landing2d.residual_context.developmentGate)
% for a registered seed list: learnability, three positive OOD mean contrasts,
% and motion/noise mean directions of TOSM against PPO, Residual-MLP and Shuffled.
assert(numel(runs)==4*numel(seeds) && isequal(sort(unique([runs.trainSeed])),seeds(:)'));
methodIds = {'ppo','residual_mlp_ppo','onto_rgat_ppo','shuffled_rgat_ppo'};
n = numel(seeds);
reached = zeros(4,1); selected = reached; landingMedian = reached; unsafeMedian = reached;
for i = 1:4
    r = runs(strcmp({runs.id},methodIds{i})); assert(numel(r)==n);
    success = zeros(n,1); unsafe = success;
    for k = 1:n
        h = r(k).history; chosen = [h.selected]; assert(sum(chosen)==1);
        reached(i) = reached(i)+any([h.landingRate]>=.8);
        success(k) = h(chosen).landingRate; unsafe(k) = h(chosen).unsafeRate;
    end
    selected(i) = sum(success>=.8); landingMedian(i) = median(success); unsafeMedian(i) = median(unsafe);
end
validation = table(string(methodIds(:)),reached,selected,landingMedian,unsafeMedian, ...
    'VariableNames',{'MethodId','Reached80','Selected80','ValidationMedian','UnsafeMedian'});
learnable = all(reached==n & selected==n) ...
    && all(landingMedian(3)>=landingMedian([1 2])-.05-1e-12) ...
    && all(unsafeMedian(3)<=unsafeMedian([1 2])+.02+1e-12);
C = results.primaryContrasts;
assert(height(C)==3 && all(C.Seeds==n));
meanDirection = all(C.Delta_OODSuccess>0);
robustDirection = true;
S = results.generalizationBySeed;
for factor = ["motion","noise"]
    t = S(S.MethodId=="onto_rgat_ppo" & S.Factor==factor & S.Shift=="OOD",:);
    for id = {'ppo','residual_mlp_ppo','shuffled_rgat_ppo'}
        b = S(S.MethodId==string(id{1}) & S.Factor==factor & S.Shift=="OOD",:);
        assert(height(t)==n && height(b)==n && all(isfinite(t.AimErrorRMS_m)) && all(isfinite(b.AimErrorRMS_m)));
        robustDirection = robustDirection && mean(t.Success)>=mean(b.Success)-1e-12 ...
            && mean(t.Unsafe)<=mean(b.Unsafe)+1e-12 ...
            && mean(t.AimErrorRMS_m)<=mean(b.AimErrorRMS_m)+1e-12;
    end
end
gate = struct('validation',validation,'learnabilityPassed',learnable, ...
    'oodMeanDirectionPassed',meanDirection,'robustMeanDirectionPassed',robustDirection, ...
    'passed',learnable && meanDirection && robustDirection,'seeds',seeds, ...
    'confirmationOpened',false,'goalComplete',false);
end
