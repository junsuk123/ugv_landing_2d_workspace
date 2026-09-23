function agent = normalizeAgent(agent,rl)
% NORMALIZEAGENT  예전 형식으로 저장된 에이전트를 현재 구조로 맞춥니다.
%
% 상태 표현 부호기를 넣기 전에는 agent.value가 다층 퍼셉트론 자체였고
% 부호기 항목이 없었습니다. results 폴더에 남아 있는 정책 파일을 그대로 다시
% 쓸 수 있도록, 불러온 뒤 여기서 현재 구조로 감싸 줍니다.
% 항등 부호기를 넣는 것이므로 정책의 동작은 달라지지 않습니다.
if nargin < 2 || isempty(rl)
    rl = agent.rl;
end
if ~isfield(agent,'encoderSpec') || isempty(agent.encoderSpec)
    gs = landing2d.graphstate.defaultGraphStateConfig();
    [~,spec] = landing2d.graphstate.encoderInit(gs,rl.observationDim, ...
        RandStream('threefry','Seed',0));
    agent.encoderSpec = spec;
end
if ~isfield(agent.policy,'encoder')
    agent.policy.encoder = struct();
end
if ~isfield(agent.value,'net')
    net = agent.value;
    agent.value = struct('net',net,'encoder',struct());
elseif ~isfield(agent.value,'encoder')
    agent.value.encoder = struct();
end
end
