function agent = structAgent(toolbox,template)
% STRUCTAGENT  RL Toolbox rlPPOAgent -> landing2d 정책 구조체.
%
% template(같은 비교군의 구조체 정책)에 학습된 가중치를 덮어씁니다. 결과는
% landing2d.rl.evaluateV2, guardRelationalCandidate, 논문 그림 등 기존 MATLAB
% 평가 경로에서 그대로 쓸 수 있습니다.
%
% RL Toolbox 기본 층은 가중치를 single로 저장합니다. single로 보아 바뀌지 않은
% 파라미터(학습률 0으로 고정한 경로 포함)는 template의 double 값을 그대로 두어,
% 고정 경로의 비트 동일성 검사(assertRawPolicyPreserved)가 유지되게 합니다.
agent = template;
actor = learnables(getModel(getActor(toolbox)));
critic = learnables(getModel(getCritic(toolbox)));
agent.policy.mean = readMlp(actor,agent.policy.mean);
agent.value.net = readMlp(critic,agent.value.net);
logStd = actor('std/LogStd');
agent.policy.logStd = keep(agent.policy.logStd, ...
    max(logStd(:),agent.rl.minimumLogStd));
if isfield(agent.policy,'relation')
    agent.policy.relation.W = keep(agent.policy.relation.W, ...
        actor('relation_head/Weights'));
    agent.value.relation.W = keep(agent.value.relation.W, ...
        critic('relation_head/Weights'));
    agent.policy.encoder = readEncoder(actor,agent.policy.encoder);
    agent.value.encoder = readEncoder(critic,agent.value.encoder);
elseif ismember(agent.encoderSpec.mode,{'context_gat','context_rgat'}) ...
        && strcmp(agent.encoderSpec.readout,'grouped')
    agent.policy.encoder = readEncoder(actor,agent.policy.encoder);
    agent.value.encoder = readEncoder(critic,agent.value.encoder);
end
end

function map = learnables(net)
table = net.Learnables;
map = containers.Map();
for i = 1:height(table)
    key = sprintf('%s/%s',table.Layer(i),table.Parameter(i));
    value = table.Value{i};
    if isa(value,'dlarray'), value = extractdata(value); end
    map(key) = double(gather(value));
end
end

function mlp = readMlp(map,mlp)
for l = 1:numel(mlp.W)
    mlp.W{l} = keep(mlp.W{l},map(sprintf('raw_fc%d/Weights',l)));
    mlp.b{l} = keep(mlp.b{l},map(sprintf('raw_fc%d/Bias',l)));
end
end

function encoder = readEncoder(map,encoder)
for name = {'W1','a1','E1','W0','b0','Wg','bg'}
    encoder.(name{1}) = keep(encoder.(name{1}), ...
        map(['relation_context/' name{1}]));
end
end

function value = keep(previous,exported)
exported = reshape(exported,size(previous));
if isequal(single(previous),single(exported))
    value = previous;
else
    value = exported;
end
end
