function s = backendSettings(c)
% BACKENDSETTINGS  Simulink 학습 실행 방식 설정 (c.simulink, 선택).
%
% 학습 문제(보상·환경·PPO 하이퍼파라미터)가 아니라 실행 방식만 담으므로
% landing2d.rl.trainingSignature에 들어가지 않습니다.
%   parallelMode  'sync' | 'async'  RL Toolbox 병렬 수집 방식
%   retries       병렬 학습 구간이 실패했을 때 풀을 다시 열어 재시도할 횟수
s = struct('parallelMode','async','retries',1);
if isfield(c,'simulink') && isstruct(c.simulink)
    names = fieldnames(c.simulink);
    unknown = setdiff(names,fieldnames(s));
    assert(isempty(unknown),'landing2d:UnknownOption', ...
        'Unknown simulink option: %s',strjoin(unknown,', '));
    for i = 1:numel(names), s.(names{i}) = c.simulink.(names{i}); end
end
assert(ismember(s.parallelMode,{'sync','async'}),'landing2d:ParallelMode', ...
    'simulink.parallelMode must be sync or async.');
end
