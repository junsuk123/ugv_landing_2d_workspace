function test_relation_performance_guard()
c=landing2d.config.primaryConfig(fileparts(fileparts(mfilename('fullpath'))));
c=landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
rs=RandStream('threefry','Seed',77);
anchor=landing2d.rl.agentInit(c.rl,rs,c.graphState);
candidate=anchor;
candidate.policy.encoder.Wg=0.1*randn(rs,size(candidate.policy.encoder.Wg));
candidate.value.encoder.Wg=0.1*randn(rs,size(candidate.value.encoder.Wg));
fullNorm=norm(candidate.policy.encoder.Wg,'fro');
options=struct('scaleGrid',[1 .5 .25 .1], ...
    'meanReturnTolerance',0.25,'selectionScoreTolerance',0.25, ...
    'minResidualNorm',1e-6,'maxResidualNorm',0.006, ...
    'evaluator',@(agent)mockInfo(agent,fullNorm));
[selected,report]=landing2d.rl.guardRelationalCandidate( ...
    anchor,candidate,c,options);
assert(report.accepted && abs(report.selectedScale-0.25)<eps);
assert(report.selectedActive);
assert(norm(selected.policy.encoder.Wg,'fro')>0);
assert(report.selectedInfo.landingRate==report.anchorInfo.landingRate);
assert(report.selectedInfo.unsafeRate==report.anchorInfo.unsafeRate);
end

function info=mockInfo(agent,fullNorm)
scale=norm(agent.policy.encoder.Wg,'fro')/fullNorm;
info=struct('landingRate',0.70,'unsafeRate',0.10, ...
    'safeAbortRate',0.15,'timeoutRate',0.05, ...
    'meanReturn',10-0.1*scale,'selectionScore',500-0.1*scale, ...
    'meanAbsRelationResidual',[0.01;0.02]*scale);
if scale>0.25+1e-12, info.unsafeRate=0.11; end
end
