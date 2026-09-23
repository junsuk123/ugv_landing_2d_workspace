function sem = semanticState(s,obs,memory,truth,c)
% SEMANTICSTATE  드론/패드 상태에서 온톨로지 의미 채널 값을 계산.
% 원 저장소 semantic.computeFeatures의 축소판입니다. 모든 채널은 [0,1]입니다.
%
%   truth.error : 실제 수평 오차 xUgv-xDrone [m]
%   truth.rate  : 실제 상대 수평 속도 vxUgv-vxDrone [m/s]
%   truth.speed : UGV 실제 속도 [m/s]
%
% 이 값은 보상 가중치를 설계할 때(PPO 학습 전)만 사용합니다.
% 정책 입력이 아니므로 환경 참값을 써도 관측 정보경계를 깨지 않습니다.
onto = c.ontology;
ex = truth.error;
ev = truth.rate;
h = max(s.h,0);
distance = hypot(ex,h);
halfWidth = max(obs.halfWidth,1e-6);
landed = s.mode == 3;
visible = obs.visible || landed;
relTol = max(c.touchdownSpeedX,1e-6);

positionError = min(1,abs(ex)/onto.positionScale);
descentSpeed = min(1,abs(s.vz)/c.vzMax);
% 패드 이동: 지금 얼마나 빠르게 달리고 있는지와, 아직 맞추지 못한 상대 속도.
% 시야를 벗어나게 만드는 원인이므로 FovMargin으로 가는 간선을 갖습니다.
padMotion = min(1,0.5*min(1,abs(truth.speed)/onto.padSpeedScale) ...
    +0.5*min(1,abs(ev)/relTol));
if landed
    fovMargin = 0;
else
    fovMargin = min(1,abs(ex)/halfWidth);
end
searchDuration = min(1,memory.timeSinceSeen/onto.searchScale);
padVisibility = double(visible);
relativeDistance = min(1,distance/c.rl.distanceScale);
alignment = exp(-abs(ex)/onto.alignScale);
trackingStability = exp(-abs(ex)/onto.alignScale-abs(ev)/onto.speedScale);
% 착륙 안전도: 정렬, 추종 안정, 포착, 접지 속도가 모두 좋아야 커지는 곱.
% 정렬/추종 안정은 노드가 아니지만 이 채널을 만드는 내부 항으로 남겨 둡니다.
touchdownSafety = alignment*trackingStability*padVisibility ...
    *exp(-abs(s.vz)/max(c.touchdownSpeedZ,1e-6)) ...
    *exp(-abs(ev)/relTol);

% 노드로 쓰는 8개 채널. alignment와 trackingStability는 노드가 아니라
% touchdownSafety를 만드는 내부 항이며, 확인용으로 함께 돌려줍니다.
sem = struct('PositionError',positionError,'DescentSpeed',descentSpeed, ...
    'PadMotion',padMotion,'FovMargin',fovMargin,'SearchDuration',searchDuration, ...
    'PadVisibility',padVisibility,'RelativeDistance',relativeDistance, ...
    'TouchdownSafety',touchdownSafety,'SafeLanding',0, ...
    'Alignment',alignment,'TrackingStability',trackingStability);
end
