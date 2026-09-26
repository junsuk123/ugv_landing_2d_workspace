function [sem,sources,signed,context] = observationSemantics(s,obs,memory,c)
% OBSERVATIONSEMANTICS  온톨로지 의미 채널을 "관측만으로" 계산하는 적응 계층.
%
% landing2d.ontology.semanticState와 같은 채널을 만들지만, 그쪽은 환경 참값
% (truth.error / truth.rate / truth.speed)을 받습니다. 참값은 보상 가중치를
% 설계할 때만 쓸 수 있고 정책 입력에는 넣을 수 없습니다.
%
% 이 함수가 쓰는 정보는 landing2d.rl.observation이 쓰는 것과 정확히 같은 집합입니다.
%
%   obs.visible, obs.xError, obs.vError, obs.halfWidth   카메라 관측 (비가시 구간에는 NaN)
%   memory.lastError, memory.lastPadSpeed, memory.timeSinceSeen
%                                                        지난 관측에서 만든 추측 항법 기억
%   s.h, s.vx, s.vz, s.mode                              드론 자기 상태 (기체 내부 값)
%   c.vzMax, c.rl.distanceScale, c.touchdownSpeedX, c.touchdownSpeedZ   고정 설정값
%
% 참값 xUgv / vxUgv는 어떤 경로로도 들어오지 않습니다. 비가시 구간에서는
% obs.*가 NaN이므로 기억값만 사용합니다. tests/test_graph_state_adapter.m이
% 이 경계를 검사합니다.
%
% sources는 각 채널이 어떤 원 자료에서 나왔는지 적은 표이며, 정보경계 점검과
% 디버깅 출력에 사용합니다(요구사항 20번 Test 4).
gs = c.graphState;

% 수평 오차 추정값. 보이면 관측값, 안 보이면 추측 항법 기억값.
% landing2d.rl.observation이 쓰는 두 값과 같은 출처입니다.
if obs.visible
    errorEstimate = obs.xError;
    rateEstimate = obs.vError;
else
    errorEstimate = memory.lastError;
    rateEstimate = memory.lastPadSpeed-s.vx;
end
h = max(s.h,0);
halfWidth = max(obs.halfWidth,1e-6);
landed = s.mode == 3;
visible = obs.visible || landed;
relTol = max(c.touchdownSpeedX,1e-6);

% 정규화는 잘라내기(min(1,x/scale))가 아니라 부드러운 포화 x/(x+scale)를 씁니다.
% 이유는 이 문제의 값들이 두 자리 수 이상 범위를 갖기 때문입니다. 수평 오차는
% 탐색 중 10 m에서 접지 직전 0.02 m까지, 고도는 18 m에서 0.05 m까지 변합니다.
% 잘라내기는 한 지점에만 해상도를 몰아줍니다. 기준을 좁게 잡으면 먼 거리가 전부
% 1로 뭉개지고, 넓게 잡으면 패드 근처가 전부 0으로 뭉개집니다. 실제로 그랬습니다.
% 부드러운 포화는 0 근처에서 x/scale에 가깝고 멀리서는 1에 수렴하므로 두 끝 모두
% 구분됩니다. 값은 [0,1)에 머물고 "클수록 나쁨"이라는 노드 의미도 그대로입니다.
% scale은 이제 잘라내는 지점이 아니라 값이 0.5가 되는 지점입니다.
positionError = softSaturate(errorEstimate,gs.positionScale);
descentSpeed = min(1,abs(s.vz)/c.vzMax);   % vzMax가 물리 한계라 포화가 실제 상한
% 패드 이동: 마지막으로 관측한 패드 속도와, 아직 맞추지 못한 상대 속도.
% 참값 속도가 아니라 마지막 관측값이라는 점이 semanticState와 다릅니다.
padMotion = 0.5*softSaturate(memory.lastPadSpeed,gs.padSpeedScale) ...
    +0.5*softSaturate(rateEstimate,relTol);
if landed
    fovMargin = 0;
else
    % 시야 반폭 대비 오차. 반폭에서 0.5이고 그보다 밖이면 계속 커집니다.
    % 예전처럼 1로 잘라내면 시야를 벗어난 뒤 "얼마나 벗어났는지"가 사라져,
    % 재포착을 위해 얼마나 움직여야 하는지 알 수 없게 됩니다.
    fovMargin = softSaturate(errorEstimate,halfWidth);
end
searchDuration = softSaturate(memory.timeSinceSeen,gs.searchScale);
padVisibility = double(visible);
% 상태 표현 전용 기준으로 정규화합니다. 보상 쪽 rl.distanceScale을 쓰면
% 상태 표현이 보상 설정에 묶이고, 그 값(6 m)은 비행 영역을 덮지 못합니다.
relativeDistance = softSaturate(hypot(errorEstimate,h),gs.distanceScale);
alignment = exp(-abs(errorEstimate)/gs.alignScale);
trackingStability = exp(-abs(errorEstimate)/gs.alignScale ...
    -abs(rateEstimate)/gs.speedScale);
% 착륙 안전도: 정렬, 추종 안정, 포착, 접지 속도가 모두 좋아야 커지는 곱.
% semanticState와 같은 형태이며 참값 자리에 추정값이 들어갑니다.
touchdownSafety = alignment*trackingStability*padVisibility ...
    *exp(-abs(s.vz)/max(c.touchdownSpeedZ,1e-6)) ...
    *exp(-abs(rateEstimate)/relTol);

sem = struct('PositionError',positionError,'DescentSpeed',descentSpeed, ...
    'PadMotion',padMotion,'FovMargin',fovMargin,'SearchDuration',searchDuration, ...
    'PadVisibility',padVisibility,'RelativeDistance',relativeDistance, ...
    'TouchdownSafety',touchdownSafety,'SafeLanding',0, ...
    'Alignment',alignment,'TrackingStability',trackingStability);

% 방향 부호 채널. 온톨로지 노드 값은 모두 "위험의 크기"라서 절댓값이고,
% 그 결과 좌/우와 상승/하강이 구분되지 않습니다. 보상 가중치를 설계할 때는
% 크기만 있으면 되지만, 정책의 상태로 쓰려면 방향이 반드시 필요합니다.
% (측정: 노드 값만으로 교사를 모방하면 손실 0.352, 부호를 되살리면 0.038,
%  기준 관측 벡터는 0.007. docs/ONTOLOGY_GRAPH_STATE_KO.md 참고)
%
% 노드 집합과 관계는 전혀 바꾸지 않고, 노드 특징 행렬 X_t에 [-1,1] 채널을
% 하나 더 얹는 방식입니다. 방향이 없는 노드는 0입니다.
% 기준 모델이 이미 보는 부호와 같은 출처를 씁니다
% (landing2d.rl.observation의 normalizedError, fovMargin, vz 등).
if nargout > 2
    signed = struct( ...
        'PositionError',signedSoft(errorEstimate,gs.positionScale), ...
        'DescentSpeed',landing2d.util.saturate(s.vz/c.vzMax,1), ...
        'PadMotion',signedSoft(rateEstimate,relTol), ...
        'FovMargin',fovSign(landed,errorEstimate,halfWidth), ...
        'SearchDuration',0, ...
        'PadVisibility',trackingSign(s.mode), ...
        'RelativeDistance',0, ...
        'TouchdownSafety',0, ...
        'SafeLanding',0);
end

if nargout > 3
    % Five explicit context channels preserve dynamics that a magnitude-only
    % node value cannot express.  Each is derived from observations, memory,
    % or the drone's own state; hidden UGV truth is never used.
    acceleration = memory.padAcceleration/(abs(memory.padAcceleration) ...
        +max(c.ugvAccelMax,1e-9));
    marginRate = memory.fovMarginRate/(abs(memory.fovMarginRate) ...
        +max(c.vxMax,1e-9));
    if memory.lastFovMargin <= 0
        boundaryUrgency = 1;
    elseif memory.fovMarginRate < 0
        timeToBoundary = memory.lastFovMargin/max(-memory.fovMarginRate,1e-9);
        boundaryUrgency = 1/(1+timeToBoundary/max(gs.searchScale,1e-9));
    else
        boundaryUrgency = 0;
    end
    uncertainty = 1-exp(-memory.timeSinceSeen/max(gs.searchScale,1e-9));
    altitude = min(max(h/c.maxHeight,0),1);
    context = blankContext();
    context.AccelerationTrend.PadMotion = acceleration;
    context.MarginRate.FovMargin = marginRate;
    context.BoundaryUrgency.FovMargin = boundaryUrgency;
    context.MemoryUncertainty.SearchDuration = uncertainty;
    context.AltitudeContext.RelativeDistance = altitude;
end

if nargout > 1
    sources = struct( ...
        'PositionError','obs.xError (visible) / memory.lastError (occluded)', ...
        'DescentSpeed','s.vz (own state)', ...
        'PadMotion','memory.lastPadSpeed, obs.vError (visible) / memory.lastPadSpeed-s.vx', ...
        'FovMargin','obs.xError, obs.halfWidth, obs.visible', ...
        'SearchDuration','memory.timeSinceSeen', ...
        'PadVisibility','obs.visible, s.mode (tracking vs search, = baseline o2/o3)', ...
        'RelativeDistance','obs.xError / memory.lastError, s.h (own state)', ...
        'TouchdownSafety','same estimates as above, s.vz', ...
        'SafeLanding','constant 0 (goal node, never observed)');
end

function context = blankContext()
names = {'AccelerationTrend','MarginRate','BoundaryUrgency', ...
    'MemoryUncertainty','AltitudeContext'};
context = struct();
for i = 1:numel(names)
    context.(names{i}) = struct();
end
end
end

function value = fovSign(landed,errorEstimate,halfWidth)
% 시야 안에서는 중심 기준 좌/우 위치, 시야를 벗어났으면 어느 쪽으로 얼마나
% 나갔는지. 착륙 완료 상태에는 방향이 없습니다.
if landed
    value = 0;
else
    value = signedSoft(errorEstimate,halfWidth);
end
end

function value = trackingSign(mode)
% 추종 상태기계의 현재 구간. PadVisibility 노드의 부호 채널에 싣습니다.
%
%   +1  mode 1  추종/착륙 구간 (패드를 잡고 하강)
%   -1  mode 2  상승 탐색 구간 (패드를 놓쳐 시야를 넓히는 중)
%    0  mode >= 3  착륙 완료 또는 접촉 실패
%
% 기준 관측 벡터의 o(2)=(mode==2), o(3)=(mode==3)과 같은 정보이며, 특권 정보가
% 아닙니다. landing2d.control.trackingMode가 관측만으로 갱신하는 값입니다.
%
% 이 채널이 없으면 종말단계에서 정책이 학습 자체를 할 수 없습니다. 교사의 수직
% 명령이 구간에 따라 정반대이기 때문입니다. h<1.5 m에서 교사 az 평균은
% mode 1에서 0.024, mode 2에서 2.005(거의 상승 한계)입니다. 같은 (고도, 오차,
% 하강속도)에서 명령이 갈리므로, 구간을 모르면 어느 쪽도 재현할 수 없습니다.
% 실제로 이 채널을 빼면 종말단계 az 회귀 손실이 0.0014에서 0.0445로 30배가 됩니다.
% 그 결과가 하강 -> 패드 상실 -> 상승 -> 재포착 -> 재하강의 무한 반복이었습니다.
%
% 새 노드나 새 관계를 만들지 않았습니다. PadVisibility는 원래 포착 상태를
% 나타내는 노드이고, 출처에도 s.mode가 이미 들어 있습니다.
if mode >= 3
    value = 0;
elseif mode == 2
    value = -1;
else
    value = 1;
end
end

function value = softSaturate(x,scale)
% |x|/(|x|+scale). 0에서 0, scale에서 0.5, 멀리서 1에 수렴합니다.
% 잘라내기와 달리 어느 구간에서도 기울기가 0이 되지 않습니다.
value = abs(x)/(abs(x)+max(scale,1e-9));
end

function value = signedSoft(x,scale)
% softSaturate의 부호 있는 형태. (-1,1)에 머뭅니다.
value = x/(abs(x)+max(scale,1e-9));
end
