function report = selfTest(gs)
% SELFTEST Meaningful native MATLAB checks of the new current-only algorithm.
% No environment rollout, training, history or performance assertion occurs.
% Includes all actor-parameter finite differences, input derivatives and the
% real common PPO-loss path. The caller must add all three src roots to PATH.
rl = landing2d.rl.defaultRlConfig();
rl.observationDim = 10; rl.actionDim = 2; rl.seed = 20261027;
if nargin < 1
    gs = struct('encoderVersion','current_semantics_v1','encoderMode','baseline', ...
        'stateRepresentation','baseline','hiddenDim',8,'layers',2, ...
        'policyHiddenSizes',110,'valueHiddenSizes',55,'readout','raw_goal_concat', ...
        'observationSource','commonObservation','observationFeatures','raw_current_v1', ...
        'encoderLearnRate',rl.policyLearnRate, ...
        'featureConstants',landing2d.current_semantics.featureConstants());
end
k = gs.featureConstants;
o = exampleInput(k);
[phi,X,detail,J] = landing2d.current_semantics.features(o,k);
assert(isequal(size(phi),[19 3]) && isequal(size(X),[6 7 3]) ...
    && isequal(size(J),[19 10 3]),'landing2d:CurrentSemanticsTest','Feature shape mismatch.');
rawRows = [3 4 5 6 8 9 10 11 1 2];
assert(isequal(phi(rawRows,:),o),'landing2d:CurrentSemanticsTest', ...
    'The shared semantic-MLP features must preserve every original observation exactly.');
assert(detail.currentOnly && ~detail.usesHistory && ~detail.usesPreviousAction);
[pAgain,xAgain] = landing2d.current_semantics.features(o,k);
assert(isequal(phi,pAgain) && isequal(X,xAgain),'landing2d:CurrentSemanticsTest', ...
    'Forward values must agree with and without a Jacobian request.');
landing2d.current_semantics.features(o(:,[3 1]),k);
[pAfter,xAfter] = landing2d.current_semantics.features(o,k);
assert(isequal(phi,pAfter) && isequal(X,xAfter),'landing2d:CurrentSemanticsTest', ...
    'Features must be independent of earlier calls.');
for b = 1:3
    assert(isequal(phi(:,b),landing2d.current_semantics.features(o(:,b),k)));
end
% Verify physical definitions, including the declared h<=0 convention.
ex = invScale(o(1,:),k.positionScale); h = invScale(o(2,:),k.heightScale);
rv = invScale(o(3,:),k.velocityScale); vz = invScale(o(5,:),k.verticalVelocityScale);
ea = ex-k.aimSlope*max(h,0); va = rv-k.aimSlope*(h>0).*vz;
expected = [bounded(ea,k.approachPositionScale);bounded(va,k.approachVelocityScale); ...
    bounded(ea.*va,k.approachProductScale)];
assert(max(abs(phi(12:14,:)-expected),[],'all')<1e-12);
bad = o(:,1); bad(1) = 1;
expectError(@()landing2d.current_semantics.features(bad,k),'landing2d:CurrentSemanticsSaturation');
uninitialized = o(:,1); uninitialized(1:4) = 0; uninitialized(9:10) = [0;1];
assert(all(isfinite(landing2d.current_semantics.features(uninitialized,k))));
contactHeight = o(:,1); contactHeight(2) = 0;
[atContact,~,~,contactJacobian] = landing2d.current_semantics.features(contactHeight,k);
assert(abs(atContact(12)-bounded(ex(1),k.approachPositionScale))<1e-12 ...
    && abs(atContact(13)-bounded(rv(1),k.approachVelocityScale))<1e-12 ...
    && all(contactJacobian(12:14,2)==0), ...
    'landing2d:CurrentSemanticsKink','The registered h=0 branch must use the h<=0 convention.');
featureError = featureDifference(o,k,J);
assert(featureError<2e-5,'landing2d:CurrentSemanticsDerivative','Feature Jacobian finite difference failed.');
[typed,Ttyped] = landing2d.current_semantics.schema('rgat');
[untyped,Tuntyped] = landing2d.current_semantics.schema('untyped');
assert(Ttyped.nEdges==16 && Ttyped.nRelations==5 && Tuntyped.nRelations==2 ...
    && isequal(typed.src,untyped.src) && isequal(typed.dst,untyped.dst) ...
    && nnz(typed.src==typed.dst)==7);
modes = {'baseline','semantic_mlp','untyped','rgat'};
widths = [110 65 55 46]; expectedCounts = [2095 2095 2094 2100];
counts = zeros(1,4); parameterErrors = NaN(1,4); inputErrors = NaN(1,4);
ppoErrors = NaN(1,4); critic = [];
for m = 1:4
    settings = gs; settings.encoderMode = modes{m}; settings.policyHiddenSizes = widths(m);
    settings.stateRepresentation = 'current_semantics_actor';
    if m==1, settings.stateRepresentation = 'baseline'; end
    agent = landing2d.current_semantics.agentInit(rl,RandStream('threefry','Seed',701),settings);
    counts(m) = landing2d.current_semantics.parameterCount(agent);
    assert(counts(m)==expectedCounts(m),'landing2d:CurrentSemanticsBudget','Unexpected trainable count.');
    if m==1
        critic = agent.value.net;
        expectedRaw = landing2d.rl.mlpInit([10 110 2],.1,RandStream('threefry','Seed',rl.seed+31001));
        assert(isequal(agent.policy.mean,expectedRaw),'landing2d:CurrentSemanticsBaseline', ...
            'The original raw-PPO actor initialization changed.');
        assert(isempty(fieldnames(agent.policy.encoder)) && agent.encoderSpec.graphDim==10);
        continue;
    end
    assert(isequal(agent.value.net,critic) && isempty(fieldnames(agent.value.encoder)), ...
        'landing2d:CurrentSemanticsCritic','All arms must share the same raw-critic initialization.');
    p = agent.policy.encoder; spec = agent.encoderSpec;
    [mu,c] = landing2d.current_semantics.encoderForward(p,spec,o);
    assert(isequal(mu,landing2d.current_semantics.encoderForward(p,spec,o)));
    dMu = [.31 -.27 .19;-.14 .23 .41];
    [g,dx] = landing2d.current_semantics.encoderBackward(p,spec,c,dMu);
    parameterErrors(m) = parameterDifference(p,spec,o,dMu,g);
    inputErrors(m) = inputDifference(p,spec,o,dMu,dx);
    assert(parameterErrors(m)<2e-5 && inputErrors(m)<2e-5, ...
        'landing2d:CurrentSemanticsDerivative','An actor derivative failed.');
    ppoErrors(m) = ppoDifference(agent,o,rl);
    assert(ppoErrors(m)<2e-5,'landing2d:CurrentSemanticsPpoDerivative', ...
        'The common PPO loss did not differentiate through the new actor correctly.');
    [value,~] = landing2d.rl.valueForward(agent,o);
    assert(isequal(value,landing2d.rl.mlpForward(agent.value.net,o)), ...
        'landing2d:CurrentSemanticsCritic','The critic must receive raw observations.');
end
report = struct('version','current_semantics_v1','passed',true,'testOnly',true, ...
    'modes',{modes},'parameterCounts',counts,'featureJacobianError',featureError, ...
    'differentiatedModes',{modes(2:4)}, ...
    'actorParameterErrors',parameterErrors,'actorInputErrors',inputErrors, ...
    'ppoDirectionalErrors',ppoErrors,'usesEnvironment',false,'trainingExecuted',false);
end

function o = exampleInput(k)
theta = [.08 -.03 .12];
o = [bounded([1.4 -.2 .75],k.positionScale);bounded([2.2 .4 -.1],k.heightScale); ...
    bounded([.4 -.25 .8],k.velocityScale);bounded([1.2 .8 1.6],k.velocityScale); ...
    bounded([-.18 .12 -.02],k.verticalVelocityScale);sin(theta);cos(theta); ...
    bounded([.11 -.07 .04],k.pitchRateScale);.2 .6 .9;.25 .4 .1];
end

function y = bounded(x,s)
y = x./(abs(x)+s);
end

function x = invScale(y,s)
x = s*y./(1-abs(y));
end

function e = featureDifference(o,k,J)
e = 0; epsilon = 1e-6;
for b = 1:size(o,2)
    for j = 1:10
        up = o(:,b); down = up; up(j) = up(j)+epsilon; down(j) = down(j)-epsilon;
        numeric = (landing2d.current_semantics.features(up,k)- ...
            landing2d.current_semantics.features(down,k))/(2*epsilon);
        e = max(e,scaledError(numeric,J(:,j,b)));
    end
end
end

function e = parameterDifference(p,spec,o,dMu,g)
epsilon = 1e-6; e = 0;
for name = fieldnames(p)'
    key = name{1};
    for j = 1:numel(p.(key))
        up = p; down = p;
        up.(key)(j) = up.(key)(j)+epsilon; down.(key)(j) = down.(key)(j)-epsilon;
        numeric = (actorLoss(up,spec,o,dMu)-actorLoss(down,spec,o,dMu))/(2*epsilon);
        e = max(e,scaledError(numeric,g.(key)(j)));
    end
end
end

function e = inputDifference(p,spec,o,dMu,dx)
epsilon = 1e-6; e = 0;
for j = 1:numel(o)
    up = o; down = o; up(j) = up(j)+epsilon; down(j) = down(j)-epsilon;
    numeric = (actorLoss(p,spec,up,dMu)-actorLoss(p,spec,down,dMu))/(2*epsilon);
    e = max(e,scaledError(numeric,dx(j)));
end
end

function L = actorLoss(p,spec,o,dMu)
mu = landing2d.current_semantics.encoderForward(p,spec,o);
L = sum(mu.*dMu,'all');
end

function e = ppoDifference(agent,o,rl)
[~,~,mu] = landing2d.rl.policyAction(agent,o,[],true);
action = mu+[.11 -.08 .14;-.09 .12 -.07];
sigma = exp(agent.policy.logStd);
currentLog = sum(-.5*((action-mu)./sigma).^2-agent.policy.logStd-.5*log(2*pi),1);
oldLog = currentLog-log([1.05 .9 1.3]); advantage = [1 -.7 .3];
[head,g] = landing2d.rl.policyLossGradient(agent,o,action,oldLog,advantage,rl);
rs = RandStream('threefry','Seed',9801); e = 0; epsilon = 1e-5;
for trial = 1:3
    direction = struct(); length2 = 0;
    for name = fieldnames(agent.policy.encoder)'
        key = name{1}; direction.(key) = randn(rs,size(agent.policy.encoder.(key)));
        length2 = length2+sum(direction.(key).^2,'all');
    end
    up = agent; down = agent; analytic = 0;
    for name = fieldnames(direction)'
        key = name{1}; delta = direction.(key)/sqrt(length2);
        up.policy.encoder.(key) = up.policy.encoder.(key)+epsilon*delta;
        down.policy.encoder.(key) = down.policy.encoder.(key)-epsilon*delta;
        analytic = analytic+sum(g.(key).*delta,'all');
    end
    numeric = (ppoLoss(up,o,action,oldLog,advantage,rl)- ...
        ppoLoss(down,o,action,oldLog,advantage,rl))/(2*epsilon);
    e = max(e,scaledError(numeric,analytic));
end
for j = 1:2
    up = agent; down = agent;
    up.policy.logStd(j) = up.policy.logStd(j)+epsilon;
    down.policy.logStd(j) = down.policy.logStd(j)-epsilon;
    numeric = (ppoLoss(up,o,action,oldLog,advantage,rl)- ...
        ppoLoss(down,o,action,oldLog,advantage,rl))/(2*epsilon);
    e = max(e,scaledError(numeric,head.logStd(j)));
end
end

function L = ppoLoss(agent,o,action,oldLog,advantage,rl)
[~,~,mu] = landing2d.rl.policyAction(agent,o,[],true);
sigma = exp(agent.policy.logStd);
logp = sum(-.5*((action-mu)./sigma).^2-agent.policy.logStd-.5*log(2*pi),1);
r = exp(logp-oldLog); clipped = min(max(r,1-rl.clipRatio),1+rl.clipRatio);
entropy = sum(agent.policy.logStd+.5*log(2*pi*exp(1)));
L = -mean(min(r.*advantage,clipped.*advantage))-rl.entropyWeight*entropy;
end

function e = scaledError(a,b)
e = max(abs(a-b)./max(1,max(abs(a),abs(b))),[],'all');
end

function expectError(f,id)
caught = false;
try
    f();
catch ex
    caught = strcmp(ex.identifier,id);
end
assert(caught,'landing2d:CurrentSemanticsTest','The expected input-contract error was not raised.');
end
