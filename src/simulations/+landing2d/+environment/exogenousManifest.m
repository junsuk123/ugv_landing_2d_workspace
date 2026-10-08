function manifest = exogenousManifest(env)
% EXOGENOUSMANIFEST  비교군이 공유하는 한 에피소드의 외생 조건과 SHA-256 해시 (평가 전용).
% reset 직후의 환경에서 만듭니다. 담는 내용: 난수열 시드와 잡음 색인 방식, 초기 물리
% 상태, UGV 운동 일정(시나리오 파라미터), dropout·pitch 외란 일정, 시간 기준 센서
% 잡음표의 배율과 해시. 미래 사건을 담고 있으므로 정책 입력이 아니며 평가·로그에만
% 씁니다. 같은 시드·같은 배율이면 비교군과 무관하게 hash가 같아야 합니다.
assert(env.stepCount == 0,'landing2d:ExogenousManifest', ...
    'The exogenous manifest is taken right after reset.');
noise = struct('indexing',env.provenance.noiseIndexing, ...
    'scale',env.provenance.noiseScale,'tableHash','');
if ~isempty(env.noise)
    bytes = [typecast(env.noise.tracker(:)','uint8'), ...
        typecast(env.noise.marker(:)','uint8'), ...
        typecast(env.noise.navigation(:)','uint8')];
    noise.tableHash = landing2d.util.sha256(bytes);
    noise.tableSize = struct('tracker',size(env.noise.tracker), ...
        'marker',size(env.noise.marker),'navigation',size(env.noise.navigation));
end
manifest = struct('schemaVersion','exogenous_manifest_v1', ...
    'provenance',env.provenance,'scenario',env.scenario, ...
    'initialPhysicalState',env.initialPhysicalState, ...
    'sensorEvents',env.sensorEvents,'noise',noise);
% Inf/-Inf (no event) are encoded as strings so they stay distinct in the hash.
manifest.hash = landing2d.util.sha256(jsonencode(finiteForJson(manifest)));
end

function value = finiteForJson(value)
if isstruct(value)
    names = fieldnames(value);
    for i = 1:numel(names)
        value.(names{i}) = finiteForJson(value.(names{i}));
    end
elseif isnumeric(value) && ~all(isfinite(value(:)))
    text = arrayfun(@num2str,value,'UniformOutput',false);
    value = text;
end
end
