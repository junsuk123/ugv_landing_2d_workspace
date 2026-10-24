% RUN  Full study: self-test -> train -> evaluate -> figures (relational_policy_v1).
% 아래 "실행 설정"을 고친 뒤 이 파일을 F5로 실행하거나 명령 창에 run을 입력한다.
% 결과는 작업 공간 변수 landingStudy와 results/ 아래에 남는다.
%   results/checkpoints  학습된 정책 (현재 설정과 맞으면 재사용, 중단된 실행은 이어서)
%   results/evaluation   CSV + results.mat
%   results/figures      PNG
% 설계는 docs/EXPERIMENT_DESIGN_KO.md에 있다. 코드에서 옵션 struct로 실행하려면
% landing2d.orchestration.runPipeline(options)를 쓴다(필드 이름은 아래 설정과 같고,
% 비교군별 학습 여부는 trainMethods 목록이다).

%% ================================ 실행 설정 ================================
runSettings = struct();   % 이전 실행의 값이 남지 않도록 새로 만든다

% 학습 시드. 비교군 차이는 학습 시드별 짝 차이로 보고한다.
runSettings.trainSeeds = 1:5;
% v2.15 개발: 학습 완료 후 landing2d.evaluation.v215DevelopmentGate()로 판정한다.
% v2.14 원본은 results/archive/v2.14_s01-05_2026-10-24에 보관되어 있다.

% 비교군별 학습 여부
%   true   학습한다. 현재 설정과 맞는 체크포인트가 있으면 다시 학습하지 않고 재사용한다.
%   false  학습하지 않는다. 가장 최근 검증 모델을 불러온다. 검증 모델은 PPO 학습 중
%          validation으로 고른 체크포인트이고, results/checkpoints와
%          results/archive/*/checkpoints에서 찾는다. 그래프 비교군의 이전 버전 모델
%          (v2.12-v2.15)은 학습 당시의 그래프 특징으로 평가하고 경고를 띄운다. 환경·보상·
%          PPO 설정이 다른 모델만 있거나 모델이 없으면 학습하지 않고 오류로 멈춘다.
runSettings.train.ppo = false;               % PPO: 고정 (relational-policy-v2.13부터)
runSettings.train.onto_rgat_ppo = true;      % TOSM-RGAT PPO (제안 모델)
runSettings.train.shuffled_rgat_ppo = true;  % Shuffled-RGAT PPO (관계 교란 대조군)

% 이번 실행에 넣을 비교군. 여기서 빼면 학습도 평가도 하지 않는다.
runSettings.methods = {'ppo','onto_rgat_ppo','shuffled_rgat_ppo'};

% true: train = true인 비교군을 맞는 체크포인트가 있어도 처음부터 다시 학습한다.
runSettings.retrain = false;

% 실시간 학습 그림 (표시 전용, 학습 결과와 무관). 기본은 MATLAB 데스크톱에서만 켠다.
runSettings.liveTraining = usejava('desktop');

% 동시에 학습할 run 수와 풀 종류 (실행 옵션: 직렬과 결과가 비트 단위로 같다).
runSettings.concurrentRuns = 1;
runSettings.concurrentPool = 'threads';     % 'threads' 또는 'processes'

% 평가 항목 (학습 효율·학습 진단·held-out·S1-S4·일반화·open-loop probe)
runSettings.sections = {'learning','training','heldout','factorial','generalization','probes'};

% 그림 창 표시 (PNG 저장은 항상 한다)
runSettings.figureVisible = false;

% 학습 전 self-test (14개 검사)
runSettings.runSelfTest = true;
%% ==========================================================================

landingStudy = runWithSettings(runSettings);

function output = runWithSettings(runSettings)
% Adds the sources and passes the settings to landing2d.orchestration.runPipeline.
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    folder = fullfile(root,'src',name{1});
    if ~contains([path pathsep],[folder pathsep]), addpath(folder); end
end
registry = landing2d.config.methodRegistry();
names = fieldnames(runSettings.train);
unknown = setdiff([names;runSettings.methods(:)],{registry.methods.id});
assert(isempty(unknown),'landing2d:UnknownMethod', ...
    'run.m names an unknown method: %s',strjoin(unknown,', '));
trained = cellfun(@(name)logical(runSettings.train.(name)),names);
options = rmfield(runSettings,'train');
options.trainMethods = names(trained)';
output = landing2d.orchestration.runPipeline(options);
end
