function d = infer(agent,c,observation,G,intervention)
% INFER Read-only inference. Only the registered common observation enters.
% A live-only post-softmax mask affects actual message aggregation, not just
% its visualization. Nominal and intervened outputs use the SAME observation.
if nargin<5 || isempty(intervention)
    intervention=struct('actorKeep',[],'criticKeep',[]);
end
if ~isfield(intervention,'actorNodeKeep'), intervention.actorNodeKeep=[]; end
S=observation;
if ~strcmp(agent.encoderSpec.mode,'baseline')
    S=landing2d.graphstate.observationVectorGraph(observation,G,c);
end
[~,~,mu]=landing2d.rl.policyAction(agent,S,[],true);
nominalValue=landing2d.rl.valueForward(agent,S);
nominalRequest=landing2d.environment.actionLimits(c).*tanh(mu);
d=struct('request',nominalRequest,'nominalRequest',nominalRequest, ...
    'value',nominalValue,'nominalValue',nominalValue, ...
    'actorAlpha',[],'criticAlpha',[],'actorNode',[],'criticNode',[], ...
    'actorCut',[],'criticCut',[],'actorDisabledNodes',[], ...
    'features',[],'graph',[],'nodeNames',{{}},'relationNames',{{}},'edgePurpose',{{}});
if strcmp(agent.encoderSpec.mode,'baseline')
    assert(isempty(intervention.actorKeep)&&isempty(intervention.criticKeep)&&isempty(intervention.actorNodeKeep), ...
        'landing2d:LiveTestMask','A baseline policy has no graph edges to cut.');
    return;
end
assert(strcmp(agent.encoderSpec.mode,'context_rgat'), ...
    'landing2d:LiveTestEncoder','This inspector supports planar context_rgat and baseline.');
if ~isempty(intervention.actorKeep) || ~isempty(intervention.actorNodeKeep)
    [~,~,mu]=landing2d.rl.policyAction(agent,S,[],true,intervention.actorKeep,intervention.actorNodeKeep);
    d.request=landing2d.environment.actionLimits(c).*tanh(mu);
end
if ~isempty(intervention.criticKeep)
    d.value=landing2d.rl.valueForward(agent,S,intervention.criticKeep);
end
[~,a]=landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,S, ...
    'policy',intervention.actorKeep,intervention.actorNodeKeep);
[~,v]=landing2d.graphstate.encoderForward(agent.value.encoder,agent.encoderSpec,S, ...
    'value',intervention.criticKeep);
d.actorAlpha=a.cache1.alpha(:); d.criticAlpha=v.cache1.alpha(:);
d.graph=agent.encoderSpec.T;
d.actorCut=false(d.graph.nEdges,1); d.criticCut=d.actorCut;
if isfield(a.cache1,'diagnosticEdgeKeep'), d.actorCut=~a.cache1.diagnosticEdgeKeep; end
if ~isempty(intervention.criticKeep), d.criticCut=~logical(intervention.criticKeep(:)); end
d.actorDisabledNodes=false(d.graph.nNodes,1);
if ~isempty(intervention.actorNodeKeep), d.actorDisabledNodes=~logical(intervention.actorNodeKeep(:)); end
d.nodeNames=agent.encoderSpec.schema.nodeNames;
d.relationNames=agent.encoderSpec.schema.relationNames;
if isfield(agent.encoderSpec.schema,'edgePurpose')
    d.edgePurpose=agent.encoderSpec.schema.edgePurpose;
else
    d.edgePurpose=repmat({''},d.graph.nEdges,1);
end
d.features=reshape(S,agent.encoderSpec.inDim,agent.encoderSpec.nNodes);
% Incoming attention sums to ~1 by construction and is NOT a node salience.
% Display each SOURCE node's mean outgoing alpha, excluding self edges.
% This is a descriptive aggregation, not causal importance or action attribution.
d.actorNode=sourceMean(d.actorAlpha,d.graph);
d.criticNode=sourceMean(d.criticAlpha,d.graph);
end

function values=sourceMean(alpha,t)
values=nan(t.nNodes,1);
for n=1:t.nNodes
    edges=t.src==n & t.dst~=n;
    if any(edges), values(n)=mean(alpha(edges)); end
end
end
