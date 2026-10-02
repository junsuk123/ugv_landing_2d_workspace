function test_context_graph_v2()
c = landing2d.config.primaryConfig(fileparts(fileparts(mfilename('fullpath'))));
c.graphState.stateRepresentation='context_rgat';
[env] = landing2d.environment.reset(c,9);
[S,d] = landing2d.graphstate.contextGraph(env.packet,c);
schema=d.schema;
assert(numel(S)==schema.inDim*schema.nNodes);
assert(schema.nNodes==11 && schema.nRelations==6);
assert(numel(schema.src)==46); % 17 semantic + 18 query + 11 self
assert(all(any(abs(d.X(:,schema.ontologyNodes))>0,1)));
assert(all(d.X(1:10,schema.decisionNodes)==0,'all'));
assert(numel(d.support.scores)==12 && all(d.support.scores>=0 & d.support.scores<=1));
% Every semantic node has an explicit directed path to both query nodes.
A=false(schema.nNodes);
for k=1:numel(schema.src), A(schema.src(k),schema.dst(k))=true; end
reach=A;
for k=1:schema.nNodes, reach=reach | reach*A; end
assert(all(reach(schema.ontologyNodes,schema.policyNode)));
assert(all(reach(schema.ontologyNodes,schema.valueNode)));
pm=find(strcmp(schema.nodeNames,'PadMotion'));
rt=find(strcmp(schema.nodeNames,'RelativeTracking'));
assert(any(schema.src==pm & schema.dst==rt));
assert(~any(schema.src==rt & schema.dst==pm));
% Flat and R-GAT branches receive the exact same raw informative tensor.
c.graphState.stateRepresentation='context_flat'; Sf=landing2d.graphstate.contextGraph(env.packet,c);
assert(isequal(S,Sf));

% The compact two-layer R-GAT receives finite nonzero analytic gradients.
c.graphState.stateRepresentation='context_rgat';
c.graphState.hiddenDim=5; c.graphState.relationDim=3;
rs=RandStream('threefry','Seed',41);
[params,spec]=landing2d.graphstate.encoderInit(c.graphState,c.rl.observationDim,rs);
batchState=repmat(S,1,2)+1e-3*randn(rs,numel(S),2);
[g,cache]=landing2d.graphstate.encoderForward(params,spec,batchState,'policy');
dG=randn(rs,size(g));
grads=landing2d.graphstate.encoderBackward(params,spec,cache,dG);
assert(all(structfun(@(x)all(isfinite(x(:))) && norm(x(:))>0,grads)));
step=1e-6; plus=params; minus=params;
plus.W1(1)=plus.W1(1)+step; minus.W1(1)=minus.W1(1)-step;
numeric=(loss(plus,spec,batchState,dG)-loss(minus,spec,batchState,dG))/(2*step);
assert(abs(numeric-grads.W1(1))<1e-5*max(1,abs(numeric)));
end

function y=loss(params,spec,S,W)
g=landing2d.graphstate.encoderForward(params,spec,S,'policy');
y=sum(g(:).*W(:));
end
