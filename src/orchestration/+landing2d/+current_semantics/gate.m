function decision = gate(runs,results,d,phase)
% GATE One predeclared decision. Development is not confirmatory evidence.
assert(ismember(phase,{'development','confirmation'}));
if strcmp(phase,'development'), seeds=d.developmentSeeds; else, seeds=d.confirmationSeeds; end
assert(~results.isSmoke && numel(runs)==4*numel(seeds));
validationRows={};
for i=1:numel(d.methods)
    selectedRuns=runs(strcmp({runs.id},d.methods{i}));
    assert(isequal(sort([selectedRuns.trainSeed]),seeds));
    for k=1:numel(selectedRuns)
        h=selectedRuns(k).history;
        assert(~isempty(h) && sum([h.selected])==1, ...
            'landing2d:CurrentSemanticsValidation','Exactly one validation-selected checkpoint is required.');
        chosen=h([h.selected]);
        validationRows{end+1}=struct('MethodId',string(d.methods{i}), ...
            'TrainSeed',selectedRuns(k).trainSeed, ...
            'Reached80',any([h.landingRate]>=d.developmentRule.selectedValidationMinimum), ...
            'Selected80',chosen.landingRate>=d.developmentRule.selectedValidationMinimum, ...
            'SelectedSuccess',chosen.landingRate,'SelectedUnsafe',chosen.unsafeRate); %#ok<AGROW>
    end
end
validation=struct2table([validationRows{:}]);
learnable=all(validation.Reached80 & validation.Selected80);
C=results.primaryContrasts;
assert(height(C)==2 && all(C.Seeds==numel(seeds)));
P=results.ppoContrasts; assert(height(P)==1 && P.Seeds==numel(seeds));
G=results.guardContrasts;
id=G(G.Metric=="IDSuccess",:); risk=G(G.Metric=="OODUnsafe",:);
if strcmp(phase,'development')
    primaryPassed=all(C.Delta_OODSuccess>0);
    practicalEligible=true;
    practicalPassed=P.Delta_OODSuccess>0;
    idPassed=id.Delta>=-d.guard.idSuccessMargin-1e-12;
    riskPassed=risk.Delta<=d.guard.oodUnsafeMargin+1e-12;
else
    primaryPassed=all(isfinite(C.PrimaryLower) & C.PrimaryLower>0);
    practicalEligible=primaryPassed;
    practicalPassed=practicalEligible && isfinite(P.PracticalLower) && P.PracticalLower>0;
    idPassed=isfinite(id.Lower) && id.Lower>=-d.guard.idSuccessMargin-1e-12;
    riskPassed=isfinite(risk.Upper) && risk.Upper<=d.guard.oodUnsafeMargin+1e-12;
end
decision=struct('phase',phase,'validation',validation,'learnabilityPassed',learnable, ...
    'primaryPassed',primaryPassed,'practicalSuccessEligible',practicalEligible, ...
    'practicalSuccessPassed',practicalPassed,'idGuardPassed',idPassed,'riskGuardPassed',riskPassed, ...
    'passed',logical(learnable && primaryPassed && practicalPassed && idPassed && riskPassed), ...
    'confirmationOpened',strcmp(phase,'confirmation'),'seedsExcluded',false, ...
    'claim','No confirmatory claim from development or smoke.');
decision.goalComplete=strcmp(phase,'confirmation') && decision.passed;
if strcmp(phase,'confirmation')
    decision.claim='Raw-PPO confirmatory superiority is eligible only after both primary comparisons pass; all intervals and prespecified guards remain reported.';
end
end
