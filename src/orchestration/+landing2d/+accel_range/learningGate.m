function T = learningGate(runs,d)
% LEARNINGGATE Criterion L per method from the validation histories (same rule as v5).
% Reached80: seeds whose validation landing rate reached 80% at any evaluation;
% Selected80: seeds whose selected checkpoint has validation landing >= 80%.
rows = cell(numel(d.methods),1);
for i = 1:numel(d.methods)
    r = runs(strcmp({runs.id},d.methods{i}));
    assert(numel(r)==numel(d.trainSeeds),'landing2d:AccelRangeRuns','%s needs five seeds.',d.methods{i});
    reached = 0; landing = zeros(numel(r),1); unsafe = landing;
    for j = 1:numel(r)
        h = r(j).history; chosen = [h.selected]; assert(sum(chosen)==1);
        reached = reached+any([h.landingRate]>=.8);
        landing(j) = h(chosen).landingRate; unsafe(j) = h(chosen).unsafeRate;
    end
    rows{i} = table(string(d.methods{i}),reached,sum(landing>=.8),median(landing),median(unsafe), ...
        'VariableNames',{'MethodId','Reached80','Selected80','ValidationMedian','UnsafeMedian'});
end
T = vertcat(rows{:});
end
