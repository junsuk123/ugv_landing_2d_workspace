function gate = developmentGate(runs,results)
% DEVELOPMENTGATE Predeclared learnability and development performance rules.
assert(numel(runs)==20 && isequal(sort(unique([runs.trainSeed])),361:365));
methodIds = {'ppo','residual_mlp_ppo','onto_rgat_ppo','shuffled_rgat_ppo'};
reached = zeros(4,1); selected = reached; landingMedian = reached; unsafeMedian = reached;
for i = 1:4
    r = runs(strcmp({runs.id},methodIds{i})); assert(numel(r)==5);
    success = zeros(5,1); unsafe = success;
    for k = 1:5
        h = r(k).history; chosen = [h.selected]; assert(sum(chosen)==1);
        reached(i) = reached(i)+any([h.landingRate]>=.8);
        success(k) = h(chosen).landingRate; unsafe(k) = h(chosen).unsafeRate;
    end
    selected(i) = sum(success>=.8); landingMedian(i) = median(success); unsafeMedian(i) = median(unsafe);
end
validation = table(string(methodIds(:)),reached,selected,landingMedian,unsafeMedian, ...
    'VariableNames',{'MethodId','Reached80','Selected80','ValidationMedian','UnsafeMedian'});
learnable = all(reached==5 & selected==5) ...
    && all(landingMedian(3)>=landingMedian([1 2])-.05-1e-12) ...
    && all(unsafeMedian(3)<=unsafeMedian([1 2])+.02+1e-12);
C = results.primaryContrasts;
assert(height(C)==3 && all(C.Seeds==5));
meanDirection = all(C.Delta_OODSuccess>0);
robustDirection = true;
S = results.generalizationBySeed;
for factor = ["motion","noise"]
    t = S(S.MethodId=="onto_rgat_ppo" & S.Factor==factor & S.Shift=="OOD",:);
    for id = {'ppo','residual_mlp_ppo','shuffled_rgat_ppo'}
        b = S(S.MethodId==string(id{1}) & S.Factor==factor & S.Shift=="OOD",:);
        assert(height(t)==5 && height(b)==5 && all(isfinite(t.AimErrorRMS_m)) && all(isfinite(b.AimErrorRMS_m)));
        robustDirection = robustDirection && mean(t.Success)>=mean(b.Success)-1e-12 ...
            && mean(t.Unsafe)<=mean(b.Unsafe)+1e-12 ...
            && mean(t.AimErrorRMS_m)<=mean(b.AimErrorRMS_m)+1e-12;
    end
end
gate = struct('validation',validation,'learnabilityPassed',learnable, ...
    'oodMeanDirectionPassed',meanDirection,'robustMeanDirectionPassed',robustDirection, ...
    'passed',learnable && meanDirection && robustDirection, ...
    'confirmationOpened',false,'goalComplete',false);
% These development directions are not confidence-qualified superiority or
% formal noninferiority conclusions. Fresh confirmation remains mandatory.
end
