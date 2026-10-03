function test_context_graph_v2()
c = landing2d.config.primaryConfig(fileparts(fileparts(mfilename('fullpath'))));
c = landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
[env] = landing2d.environment.reset(c,9);
[S,d] = landing2d.graphstate.contextGraph(env.packet,c);
schema=d.schema;
assert(numel(S)==schema.inDim*schema.nNodes);
assert(schema.nNodes==9 && schema.nRelations==5);
assert(numel(schema.src)==26); % 17 semantic + 9 self
assert(all(any(abs(d.X(:,schema.ontologyNodes))>0,1)));
assert(numel(d.support.scores)==12 && all(d.support.scores>=0 & d.support.scores<=1));
% Every semantic node belongs to exactly one meaningful readout group.
assert(isequal(schema.groupNames,{'Perception','Tracking','Vehicle','Safety'}));
assert(all(sum(schema.groupMatrix>0,1)==1));
assert(all(abs(sum(schema.groupMatrix,2)-1)<eps));
pm=find(strcmp(schema.nodeNames,'PadMotion'));
rt=find(strcmp(schema.nodeNames,'RelativeTracking'));
assert(any(schema.src==pm & schema.dst==rt));
assert(~any(schema.src==rt & schema.dst==pm));
% Flat and R-GAT branches receive the exact same raw informative tensor.
flat=c; flat=landing2d.graphstate.applyStateRepresentation(flat,'context_flat');
Sf=landing2d.graphstate.contextGraph(env.packet,flat);
assert(isequal(S,Sf));

% Information-leakage guard rejects hidden truth, outcomes, and future data.
bad=env.packet; bad.futurePadX=0;
assertThrows(@()landing2d.graphstate.contextGraph(bad,c), ...
    'landing2d:InformationLeakage');
bad=env.packet; bad.terminalReason='SUCCESS';
assertThrows(@()landing2d.graphstate.contextGraph(bad,c), ...
    'landing2d:InformationLeakage');

% The lightweight one-layer R-GAT receives finite analytic gradients.
c.graphState.hiddenDim=5; c.graphState.relationDim=3;
rs=RandStream('threefry','Seed',41);
[params,spec]=landing2d.graphstate.encoderInit(c.graphState,c.rl.observationDim,rs);
assert(~isfield(params,'W2') && ~isfield(params,'a2') && ~isfield(params,'E2'));
initial=landing2d.graphstate.encoderForward(params,spec,S,'policy');
assert(isequal(initial(1:numel(S)),S));
assert(all(initial(numel(S)+1:end)==0));
assert(spec.graphDim==spec.stateDim+numel(schema.groupNames));
params.Wg=0.05*randn(rs,size(params.Wg));
batchState=repmat(S,1,2)+1e-3*randn(rs,numel(S),2);
[g,cache]=landing2d.graphstate.encoderForward(params,spec,batchState,'policy');
dG=randn(rs,size(g));
grads=landing2d.graphstate.encoderBackward(params,spec,cache,dG);
assert(all(structfun(@(x)all(isfinite(x(:))) && norm(x(:))>0,grads)));
step=1e-6; plus=params; minus=params;
plus.W1(1)=plus.W1(1)+step; minus.W1(1)=minus.W1(1)-step;
numeric=(loss(plus,spec,batchState,dG)-loss(minus,spec,batchState,dG))/(2*step);
assert(abs(numeric-grads.W1(1))<1e-5*max(1,abs(numeric)));

% Actor/Critic share the static pretrained starting point and stay compact.
agent=landing2d.rl.agentInit(c.rl,rs,c.graphState);
for name={'W1','E1','W0','b0'}
    assert(isequal(agent.policy.encoder.(name{1}),agent.value.encoder.(name{1})));
end
profile=landing2d.rl.profileAgent(agent,c,1,2);
assert(profile.parameterCount<17621);
% The proposal starts as the exact semantic-flat policy/value function and
% can then add relation context without discarding raw information.
flatCfg=landing2d.graphstate.applyStateRepresentation(c,'context_flat');
flatAgent=landing2d.rl.agentInit(flatCfg.rl, ...
    RandStream('threefry','Seed',41),flatCfg.graphState);
flatMu=landing2d.rl.mlpForward(flatAgent.policy.mean,S);
[~,~,graphMu]=landing2d.rl.policyAction(agent,S,[],true);
assert(norm(flatMu-graphMu)<1e-12);
flatV=landing2d.rl.mlpForward(flatAgent.value.net,S);
graphV=landing2d.rl.valueForward(agent,S);
assert(norm(flatV-graphV)<1e-12);
end

function y=loss(params,spec,S,W)
g=landing2d.graphstate.encoderForward(params,spec,S,'policy');
y=sum(g(:).*W(:));
end

function assertThrows(f,id)
try
    f();
catch exception
    assert(strcmp(exception.identifier,id), ...
        'Expected %s, got %s.',id,exception.identifier);
    return;
end
error('Expected exception %s.',id);
end
