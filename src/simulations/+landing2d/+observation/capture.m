function [O,memory,detail] = capture(memory,detections,navigation,t,G)
% CAPTURE  결정 시점 t의 공통 관측 o_t = [G_t; D_t; H_t]를 만들고 기억을 갱신합니다.
% 입력은 검출 결과(landing2d.sensing.detectMarkers 형식), 드론 융합 측위
% (landing2d.sensing.navigationEstimate 형식), 기억, 부가 정보 G = Gamma뿐입니다.
% 패드·UGV 참값, tracker 추정, 결정 문맥 플래그, 남은 임무 시간, 이전 행동, 보상은
% 받을 경로가 없으며, 등록되지 않은 입력 필드는 거부합니다.
%   G_t  ArUco 코너 -> 평면 PnP -> UGV 위치 관측 -> 등속 KF 위치·속도,
%        영상 보정 여부, 마지막 영상 보정 후 경과시간 (초기화 전이면 Inf)
%        마커가 안 보이면 위치·속도를 0으로 바꾸지 않고 예측값을 유지합니다.
%   D_t  융합 측위 + 측위 경과시간(결정 시각 - 측위 시각)
%   H_t  직전 결정 시점의 UGV·드론 위치·속도 (현재 값을 만든 뒤 기록)
% 가속 중·추종 부족·하강 가능 같은 판단은 만들지 않습니다(이후 단계 몫).
% detail은 진단용 PnP 결과와 UGV 위치 관측입니다(관측 벡터 아님).
assert(isequal(fieldnames(detections)',{'valid','stamp','ids','corners','imageSize'}) ...
    && isequal(fieldnames(navigation)',{'positionXZ','velocityXZ','pitchSinCos', ...
    'pitchRate','navigationValid','navigationAge','navigationStamp'}), ...
    'landing2d:InformationLeakage','Common observation inputs contain unregistered fields.');
pose = landing2d.observation.estimatePadPose(detections,G);
y = NaN(2,1); measurementCovariance = NaN(2);
if pose.valid
    [y,measurementCovariance] = landing2d.observation.ugvPositionMeasurement(pose,navigation,G);
end
filter = landing2d.observation.updateUgvEstimate(memory.filter,y, ...
    measurementCovariance,pose.valid,navigation,t,G);
ugv = struct('positionXZ',zeros(2,1),'velocityXZ',zeros(2,1), ...
    'visionUpdated',filter.updated,'visionAge',Inf, ...
    'estimateInitialized',filter.initialized,'visionStamp',filter.lastUpdateTime);
if filter.initialized
    ugv.positionXZ = filter.state(1:2);
    ugv.velocityXZ = filter.state(3:4);
    ugv.visionAge = max(t-filter.lastUpdateTime,0);
end
drone = navigation;
drone.navigationAge = 0;
if drone.navigationValid
    drone.navigationAge = max(t-drone.navigationStamp,0);
end
O = struct('schemaVersion',G.version,'decisionTime',t, ...
    'ugv',ugv,'drone',drone,'history',memory.previous);
memory.filter = filter;
memory.previous = struct('ugvPositionXZ',ugv.positionXZ,'ugvVelocityXZ',ugv.velocityXZ, ...
    'dronePositionXZ',drone.positionXZ,'droneVelocityXZ',drone.velocityXZ, ...
    'ugvInitialized',ugv.estimateInitialized,'valid',true);
detail = struct('pose',pose,'measurement',y,'measurementCovariance',measurementCovariance);
end
