function differences = assertSameProblem(baselineCfg,proposedCfg)
% ASSERTSAMEPROBLEM  두 비교군이 같은 문제를 푸는지 실행 중에 확인.
%
% 두 종류의 설정을 구분해서 다룹니다.
%
%   (1) 문제 정의  : 보상 함수와 계수, 행동 정의와 한계, 환경 동역학, 종료 조건.
%                    하나라도 다르면 **여기서 멈춥니다.** 이것이 달라지면 두
%                    비교군이 애초에 다른 과제를 푸는 것이라 비교가 무의미합니다.
%
%   (2) 학습 조건  : 모방 학습 사용 여부, PPO 반복 수, 탐색 잡음, 초기 조건 범위.
%                    다르면 멈추지 않고 **목록으로 돌려줍니다.** run_all이 이를
%                    출력하므로 어떤 변수가 함께 달라졌는지 결과와 같은 화면에
%                    남습니다.
%
% (2)를 멈춤 조건으로 두지 않는 이유: 제안 모델은 기준 유도 법칙을 교사로
% 모방하지 않고 처음부터 학습합니다. 모방 학습으로 초기화하면 정책이 유도
% 법칙의 거동을 그대로 물려받아, 패드가 시야에서 사라진 구간에서도 유도 법칙과
% 같은 움직임을 보입니다. 그러면 "온톨로지 그래프 상태로 무엇이 달라지는가"를
% 볼 수 없습니다. 실제로 두 비교군을 모두 모방 학습으로 초기화했을 때,
% 비가시 구간 수평 오차의 RMS 차이가 기준 모델과 제안 모델 사이에서 0.195 m로
% 유도 법칙 대비 차이(0.486~0.616 m)보다 훨씬 작았습니다.
%
% 대신 학습 조건이 함께 달라진다는 사실은 결과 해석에서 반드시 밝혀야 합니다.
% 상태 표현만의 효과를 보려면 두 비교군을 같은 조건으로 맞추십시오
% (cfg.graphState.useScratchSettings = false로 두거나, 기준 모델에도
% landing2d.rl.applyScratchSettings를 적용).

%% (1) 문제 정의 - 다르면 중단
% 보상 (요구사항 4번: r_t_proposed == r_t_baseline)
reward = {'captureWeight','distanceWeight','captureMode','distanceMode', ...
    'distanceRateShare','distanceRateScale','distanceScale','distanceExponent'};
mustMatch(baselineCfg.rl,proposedCfg.rl,reward,'reward');

% 행동 공간 (요구사항 5번)
mustMatch(baselineCfg.rl,proposedCfg.rl,{'actionDim','actionInterval'},'action');
mustMatch(baselineCfg,proposedCfg,{'axMax','azMax','vxMax','vzMax'},'action limit');

% 환경과 종료 조건
environment = {'dt','tEnd','segmentTimes','scenarioSpeeds','ugvAccelMax', ...
    'padHeight','padHalfLength','initialHeight','maxHeight','ceilingHeight', ...
    'cameraFovDeg','reacquireInnerRatio','reacquireHoldTime', ...
    'touchdownHeight','touchdownSpeedX','touchdownSpeedZ','controller'};
mustMatch(baselineCfg,proposedCfg,environment,'environment');

% 기준 모델 쪽이 실제로 기준 상태 표현인지
assert(strcmp(baselineCfg.graphState.stateRepresentation,'baseline'), ...
    'landing2d:BaselineStateChanged', ...
    'The baseline arm must keep stateRepresentation = baseline.');

% 제안 모델은 옛 보상 설계 경로를 쓰지 않아야 함 (요구사항 19번)
assert(~isfield(proposedCfg,'ontologyRewardApplied') ...
    || ~proposedCfg.ontologyRewardApplied, ...
    'landing2d:LegacyRewardInProposedPath', ...
    ['The proposed arm must run with the legacy ontology reward design ' ...
     'disabled. landing2d.ontology.applyDesign must not touch this config.']);

%% (2) 학습 조건 - 다르면 목록으로 보고
training = {'seed','hiddenSize','ppoIterations','episodesPerIteration', ...
    'ppoEpochs','miniBatch','clipRatio','gamma','lambda','policyLearnRate', ...
    'valueLearnRate','entropyWeight','initialLogStd','maxGradNorm', ...
    'valueWarmup','useBehaviorClone','bcEpisodes','bcEpochs','bcBatch', ...
    'bcLearnRate','initialHeightRange','initialOffsetRange', ...
    'initialSpeedRange','initialOffsetFraction','curriculumFraction', ...
    'curriculumStartHeight','teacherHeightRange','teacherNoise'};
differences = {};
for i = 1:numel(training)
    key = training{i};
    if ~isfield(baselineCfg.rl,key) || ~isfield(proposedCfg.rl,key)
        continue;
    end
    a = baselineCfg.rl.(key);
    b = proposedCfg.rl.(key);
    if ~isequal(a,b)
        differences{end+1} = sprintf('%-22s %s -> %s', ...
            key,valueText(a),valueText(b)); %#ok<AGROW>
    end
end
end

function mustMatch(a,b,fields,label)
for i = 1:numel(fields)
    key = fields{i};
    assert(isfield(a,key) && isfield(b,key), ...
        'landing2d:MissingSetting','Missing %s setting: %s',label,key);
    assert(isequal(a.(key),b.(key)), ...
        'landing2d:ProblemMismatch', ...
        ['The proposed model must keep the baseline %s unchanged, but %s ' ...
         'differs. Only the state representation and the training regime ' ...
         'may change.'],label,key);
end
end

function text = valueText(value)
if ischar(value)
    text = value;
elseif islogical(value) || (isnumeric(value) && isscalar(value))
    text = num2str(double(value),'%g');
else
    text = mat2str(value,4);
end
end
