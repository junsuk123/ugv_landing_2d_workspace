function cfg = applySpatialDimension(cfg,dimension)
% APPLYSPATIALDIMENSION  공간 차원 옵션(2 또는 3)을 실험 계약에 반영.
%
%   cfg = landing2d.config.applySpatialDimension(cfg)     % cfg.spatialDimension 사용
%   cfg = landing2d.config.applySpatialDimension(cfg,3)
%
% 2: 아무것도 바꾸지 않습니다. 기존 평면 계약과 체크포인트 서명이 그대로입니다.
% 3: 측방 y축·roll 축을 추가합니다. 바뀌는 항목은 아래뿐이며 세 비교군에 공통입니다.
%    experiment.spatial            3차원 계약(패드 반폭, 측방 가속도 한계, 최종 하강 단계)
%    experiment.reward.actionChangeWeight  결정 간 행동 변화량 비용
%    experiment.scenario.lateral*  UGV 측방 CV-CA-CV 범위
%    experiment.observationSchema  37차원 causal packet
%    rl.actionDim / observationDim 행동 [a_x,a_y,a_z], 관측 차원
%    rl.initialLogStd / lateralInitialLogStd   a_x·a_z / a_y 초기 탐색 잡음
%    rl.touchdownAttitudeCurriculumScale       학습 에피소드 착지 자세 허용치 커리큘럼
%    rl.trackAuthorizationCurriculumScale      학습 에피소드 추적 승인 조건 커리큘럼
%    graphState.spatialDimension   그래프 노드 특징에 측방 채널 2개 추가
%    outputDir                     <outputDir>/spatial3d (2차원 체크포인트와 분리)
% 이미 3차원으로 변환된 설정에 다시 적용해도 결과가 같습니다.
if nargin < 2 || isempty(dimension)
    dimension = 2;
    if isfield(cfg,'spatialDimension'), dimension = cfg.spatialDimension; end
end
validateattributes(dimension,{'numeric'},{'scalar','integer'},mfilename,'spatialDimension');
assert(ismember(dimension,[2,3]),'landing2d:SpatialDimension', ...
    'spatialDimension must be 2 or 3.');
alreadySpatial = landing2d.environment.isSpatial(cfg);
if dimension == 2
    assert(~alreadySpatial,'landing2d:SpatialDimension', ...
        'A 3D configuration cannot be converted back to 2D; rebuild primaryConfig.');
    cfg.spatialDimension = 2;
    return;
end
cfg.spatialDimension = 3;
if alreadySpatial, return; end
assert(isfield(cfg,'experiment') && cfg.experiment.enabled, ...
    'landing2d:SpatialDimension','3D option requires the planar_visibility_v2 contract.');
s = landing2d.config.defaultSpatialConfig();
e = cfg.experiment;
e.spatial = struct('dimension',s.dimension,'schemaVersion',s.schemaVersion, ...
    'padHalfWidth',s.padHalfWidth, ...
    'lateralAccelerationLimit',s.lateralAccelerationLimit, ...
    'finalDescentHeight',s.finalDescentHeight, ...
    'finalDescentExitHeight',s.finalDescentExitHeight, ...
    'finalDescentMaxDuration',s.finalDescentMaxDuration);
e.reward.actionChangeWeight = s.actionChangeWeight;
e.scenario.lateralV1Range = s.lateralV1Range;
e.scenario.lateralA2Range = s.lateralA2Range;
e.scenario.y0 = s.y0;
e.observationSchema = landing2d.sensing.observationSchema(3);
cfg.experiment = e;
cfg.rl.observationDim = e.observationSchema.dimension;
cfg.rl.actionDim = 3;
% 3D-only training settings (the planar rl config/signature is untouched).
cfg.rl.initialLogStd = s.initialLogStd;
cfg.rl.lateralInitialLogStd = s.lateralInitialLogStd;
cfg.rl.touchdownAttitudeCurriculumScale = s.touchdownAttitudeCurriculumScale;
cfg.rl.trackAuthorizationCurriculumScale = s.trackAuthorizationCurriculumScale;
cfg.graphState.spatialDimension = 3;
cfg.outputDir = fullfile(cfg.outputDir,s.outputSubdir);
end
