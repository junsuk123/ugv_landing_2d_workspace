function out = semanticDiagnostics(runs,d)
% SEMANTICDIAGNOSTICS Same instantaneous inputs for every frozen policy.
% Large interaction is NOT an improvement score or a causal explanation.
[x,metadata]=landing2d.current_semantics.diagnosticInputs(d.c);
actionRows={}; interactionRows={};
for k=1:numel(runs)
    [~,~,mu]=landing2d.rl.policyAction(runs(k).agent,x,[],true);
    applied=landing2d.environment.actionLimits(runs(k).config).*tanh(mu);
    assert(isequal(size(mu),[2,size(x,2)]) && all(isfinite(applied),'all'));
    T=metadata;
    T.MethodId=repmat(string(runs(k).id),height(T),1);
    T.Method=repmat(string(runs(k).label),height(T),1);
    T.TrainSeed=repmat(runs(k).trainSeed,height(T),1);
    T.MeanX=mu(1,:)'; T.MeanZ=mu(2,:)';
    T.Ax_mps2=applied(1,:)'; T.Az_mps2=applied(2,:)';
    actionRows{end+1}=T; %#ok<AGROW>
    for first=1:4:height(T)
        index=first:first+3;
        interaction=applied(:,index(4))-applied(:,index(3))-applied(:,index(2))+applied(:,index(1));
        interactionRows{end+1}=struct('Probe',T.Probe(first),'Anchor',T.Anchor(first), ...
            'MethodId',string(runs(k).id),'Method',string(runs(k).label), ...
            'TrainSeed',runs(k).trainSeed,'InteractionX_mps2',interaction(1), ...
            'InteractionZ_mps2',interaction(2),'InteractionNorm_mps2',norm(interaction)); %#ok<AGROW>
    end
end
out.matchedActions=vertcat(actionRows{:});
out.semanticInteractions=struct2table([interactionRows{:}]);
metrics={'InteractionX_mps2','InteractionZ_mps2','InteractionNorm_mps2'};
out.semanticInteractionsBySeed=landing2d.evaluation.runMeans(out.semanticInteractions,{'Probe'},metrics);
out.semanticInteractionSummary=landing2d.evaluation.seedSummary(out.semanticInteractionsBySeed,{'Probe'},metrics);
out.diagnosticInputs=array2table(x','VariableNames',compose('o%d',1:10));
out.diagnosticInputs=[metadata,out.diagnosticInputs];
out.diagnosticInterpretation='Current-state functional interaction only; not history, temporal planning, robustness, or causal importance.';
end
