function agent = toolboxAgent(source,c,stage,horizon)
% TOOLBOXAGENT  landing2d 정책 구조체 -> RL Toolbox rlPPOAgent.
%
%   agent = landing2d.rlsim.toolboxAgent(structAgent,c,'raw',horizon)
%   agent = landing2d.rlsim.toolboxAgent(structAgent,c,'relation',horizon)
%
% 망 구조와 가중치는 landing2d.rl.agentInit/policyAction/valueForward와
% 같습니다.
%   Actor 평균 = f_pi(s_t) [+ 하강 gate(W_pi c_t)],  표준편차 = exp(logStd)
%   Critic    = f_V(s_t)  [+ w_V' c_t]
% stage는 landing2d.rl.ppoTrain의 단계 학습을 학습률 계수로 재현합니다.
%   'value'    Critic raw MLP만 학습 (valueWarmup 반복)
%   'raw'      raw MLP와 logStd만 학습, 관계 경로 고정 (1단계)
%   'relation' raw MLP·logStd 고정, attention·readout·관계 head만 학습 (2단계)
% 정적 관계 변환 E1, W0, b0은 freezeStaticBackbone에 따라 항상 고정합니다.
if nargin < 3 || isempty(stage), stage = 'raw'; end
if nargin < 4 || isempty(horizon), horizon = 2048; end
assert(ismember(stage,{'value','raw','relation'}),'landing2d:TrainingStage', ...
    'stage must be value, raw, or relation.');
rl = c.rl;
spec = source.encoderSpec;
relational = isfield(source.policy,'relation');
directGraph = ismember(spec.mode,{'context_gat','context_rgat'}) ...
    && ismember(spec.readout,{'grouped','grouped_factorized','observation_plus_groups'}) ...
    && ~relational;
[obsInfo,actInfo] = landing2d.rlsim.specs(c,spec.stateDim);

actorNet = actorNetwork(source,spec,rl,relational,directGraph);
criticNet = criticNetwork(source,spec,relational,directGraph);
[actorNet,criticNet] = applyStage(actorNet,criticNet,stage,relational,directGraph,c);
meanName = 'raw_fc3';
if relational, meanName = 'mean'; end
actor = rlContinuousGaussianActor(actorNet,obsInfo,actInfo, ...
    'ObservationInputNames','obs','ActionMeanOutputNames',meanName, ...
    'ActionStandardDeviationOutputNames','std');
valueName = 'raw_fc3';
if relational, valueName = 'value'; end
critic = rlValueFunction(criticNet,obsInfo,'ObservationInputNames','obs');
assert(strcmp(criticNet.OutputNames{1},valueName),'landing2d:CriticOutput', ...
    'Unexpected critic output %s.',criticNet.OutputNames{1});

horizon = max(rl.miniBatch,round(horizon));
options = rlPPOAgentOptions( ...
    'SampleTime',c.experiment.policyDt, ...
    'DiscountFactor',rl.gamma, ...
    'ExperienceHorizon',horizon, ...
    'LearningFrequency',horizon, ...
    'MiniBatchSize',rl.miniBatch, ...
    'NumEpoch',rl.ppoEpochs, ...
    'MaxMiniBatchPerEpoch',ceil(horizon/rl.miniBatch), ...
    'ClipFactor',rl.clipRatio, ...
    'EntropyLossWeight',rl.entropyWeight, ...
    'AdvantageEstimateMethod','gae', ...
    'GAEFactor',rl.lambda, ...
    'NormalizedAdvantageMethod','current', ...
    'ActorOptimizerOptions',optimizer(rl.policyLearnRate,rl), ...
    'CriticOptimizerOptions',optimizer(rl.valueLearnRate,rl));
agent = rlPPOAgent(actor,critic,options);
end

% ------------------------------------------------------------------ Actor
function net = actorNetwork(source,spec,rl,relational,directGraph)
net = dlnetwork;
net = addLayers(net,featureInputLayer(spec.stateDim,'Name','obs', ...
    'Normalization','none'));
net = addMlp(net,source.policy.mean,'raw');
if directGraph
    net = addLayers(net,contextLayer(source.policy.encoder,spec,'relation_context'));
    net = connectLayers(net,'obs','relation_context');
    net = connectLayers(net,'relation_context','raw_fc1');
else
    net = connectMlpInput(net,source);
end
net = addLayers(net,landing2d.rlsim.StateIndependentStdLayer( ...
    source.policy.logStd,rl.minimumLogStd,'std'));
net = connectLayers(net,'obs','std');
if relational
    net = addLayers(net,landing2d.rlsim.RelationalContextLayer( ...
        source.policy.encoder,spec,'relation_context'));
    net = addLayers(net,fullyConnectedLayer(size(source.policy.relation.W,1), ...
        'Name','relation_head','Weights',source.policy.relation.W, ...
        'Bias',zeros(size(source.policy.relation.W,1),1), ...
        'BiasLearnRateFactor',0));
    net = addLayers(net,additionLayer(2,'Name','mean'));
    net = connectLayers(net,'obs','relation_context');
    net = connectLayers(net,'relation_context','relation_head');
    net = connectLayers(net,'raw_fc3','mean/in1');
    if strcmp(spec.readout,'observation_plus_groups')
        net = connectLayers(net,'relation_head','mean/in2');
    else
        net = addLayers(net,landing2d.rlsim.DescentGateLayer( ...
            spec.descentEligibilityIndex,'descent_gate'));
        net = connectLayers(net,'relation_head','descent_gate/residual');
        net = connectLayers(net,'obs','descent_gate/state');
        net = connectLayers(net,'descent_gate','mean/in2');
    end
end
net = initialize(net);
end

% ----------------------------------------------------------------- Critic
function net = criticNetwork(source,spec,relational,directGraph)
net = dlnetwork;
net = addLayers(net,featureInputLayer(spec.stateDim,'Name','obs', ...
    'Normalization','none'));
net = addMlp(net,source.value.net,'raw');
if directGraph
    net = addLayers(net,contextLayer(source.value.encoder,spec,'relation_context'));
    net = connectLayers(net,'obs','relation_context');
    net = connectLayers(net,'relation_context','raw_fc1');
else
    net = connectMlpInput(net,source);
end
if relational
    net = addLayers(net,landing2d.rlsim.RelationalContextLayer( ...
        source.value.encoder,spec,'relation_context'));
    net = addLayers(net,fullyConnectedLayer(1,'Name','relation_head', ...
        'Weights',source.value.relation.W,'Bias',0,'BiasLearnRateFactor',0));
    net = addLayers(net,additionLayer(2,'Name','value'));
    net = connectLayers(net,'obs','relation_context');
    net = connectLayers(net,'relation_context','relation_head');
    net = connectLayers(net,'raw_fc3','value/in1');
    net = connectLayers(net,'relation_head','value/in2');
end
net = initialize(net);
end

function net = connectMlpInput(net,source)
% landing2d.rl.mlpInput: the raw MLP reads the standardized state when the
% policy has input statistics; the relation path and descent gate read obs.
inputName='obs';
if strcmp(source.encoderSpec.readout,'observation_plus_groups')
    net=addLayers(net,landing2d.rlsim.PrefixLayer( ...
        source.encoderSpec.rawDim,'observation_prefix'));
    net=connectLayers(net,'obs','observation_prefix');
    inputName='observation_prefix';
end
if isfield(source,'inputNorm') && ~isempty(source.inputNorm)
    net = addLayers(net,landing2d.rlsim.InputNormLayer(source.inputNorm,'input_norm'));
    net = connectLayers(net,inputName,'input_norm');
    net = connectLayers(net,'input_norm','raw_fc1');
else
    net = connectLayers(net,inputName,'raw_fc1');
end
end

function net = addMlp(net,mlp,prefix)
% landing2d.rl.mlpForward: tanh 은닉층 + 선형 출력층
nLayer = numel(mlp.W);
layers = [];
for l = 1:nLayer
    layers = [layers;fullyConnectedLayer(size(mlp.W{l},1), ...
        'Name',sprintf('%s_fc%d',prefix,l),'Weights',mlp.W{l}, ...
        'Bias',mlp.b{l})]; %#ok<AGROW>
    if l < nLayer
        layers = [layers;tanhLayer('Name',sprintf('%s_tanh%d',prefix,l))]; %#ok<AGROW>
    end
end
net = addLayers(net,layers);
end

% ------------------------------------------------------------ 단계 학습률
function [actorNet,criticNet] = applyStage(actorNet,criticNet,stage,relational,directGraph,c)
raw = double(strcmp(stage,'raw'));
gs = c.graphState;
actorNet = setMlpFactor(actorNet,raw);
criticNet = setMlpFactor(criticNet,double(ismember(stage,{'value','raw'})));
actorNet = setLearnRateFactor(actorNet,'std','LogStd',raw);
if directGraph
    actorEncoder = raw*gs.encoderLearnRate/c.rl.policyLearnRate;
    criticActive = double(ismember(stage,{'value','raw'}));
    criticEncoder = criticActive*gs.encoderLearnRate/c.rl.valueLearnRate;
    actorNet = setEncoderFactor(actorNet,actorEncoder,false);
    criticNet = setEncoderFactor(criticNet,criticEncoder,false);
    return;
end
if ~relational, return; end
relation = double(strcmp(stage,'relation'));
% 인코더 학습률은 graphState.encoderLearnRate가 되도록 본체 학습률 대비 비율로 둡니다.
actorEncoder = relation*gs.encoderLearnRate/c.rl.policyLearnRate;
criticEncoder = relation*gs.encoderLearnRate/c.rl.valueLearnRate;
actorNet = setEncoderFactor(actorNet,actorEncoder,gs.freezeStaticBackbone);
criticNet = setEncoderFactor(criticNet,criticEncoder,gs.freezeStaticBackbone);
actorNet = setLearnRateFactor(actorNet,'relation_head','Weights',relation);
criticNet = setLearnRateFactor(criticNet,'relation_head','Weights',relation);
end

function net = setMlpFactor(net,factor)
for l = 1:3
    name = sprintf('raw_fc%d',l);
    net = setLearnRateFactor(net,name,'Weights',factor);
    net = setLearnRateFactor(net,name,'Bias',factor);
end
end

function net = setEncoderFactor(net,factor,freezeStatic)
for name = {'W1','a1','Wg','Wc','Wn','bg'}
    if hasLearnable(net,'relation_context',name{1})
        net = setLearnRateFactor(net,'relation_context',name{1},factor);
    end
end
static = factor;
if freezeStatic, static = 0; end
for name = {'E1','W0','b0'}
    net = setLearnRateFactor(net,'relation_context',name{1},static);
end
end

function layer = contextLayer(params,spec,name)
if strcmp(spec.readout,'grouped_factorized')
    layer=landing2d.rlsim.FactorizedRelationalContextLayer(params,spec,name);
else
    layer=landing2d.rlsim.RelationalContextLayer(params,spec,name);
end
end

function yes = hasLearnable(net,layer,parameter)
t=net.Learnables;
yes=any(string(t.Layer)==layer & string(t.Parameter)==parameter);
end

function o = optimizer(learnRate,rl)
% landing2d.util.adamUpdate와 같은 Adam, L2 없음, 전역 노름 기울기 자르기
o = rlOptimizerOptions('LearnRate',learnRate, ...
    'GradientThreshold',rl.maxGradNorm, ...
    'GradientThresholdMethod','global-l2norm', ...
    'L2RegularizationFactor',0,'Algorithm','adam');
end
