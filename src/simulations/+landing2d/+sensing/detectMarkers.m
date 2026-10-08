function detections = detectMarkers(state,pad,t,sensor,co,rs,event)
% DETECTMARKERS  카메라 + ArUco 검출기 출력 모사 (센서 모델, 패드 참값 사용).
% 출력은 실제 검출 결과와 같은 형식이며, 공통 관측 생성기는 이 출력만 받습니다.
% 카메라 보정(co.camera)으로 투영합니다:
%   p_C = R_BC' * (R_WB' * (p_W - o_W) - t_BC)        카메라–드론 외부 파라미터 BT_C
%   [u;v] = K * [distort(p_C(1:2)/p_C(3)); 1]          내부 파라미터 K, 왜곡계수 d
% R_WB = R_y(theta)는 기체 자세(추력축 [sin,0,cos]), o_W = [x;0;z]는 기체 위치입니다.
% 출력 코너는 실제 검출기처럼 왜곡된 영상 좌표입니다.
% 평면 계약에서 기체·패드는 y = 0이고 패드 면은 수평입니다.
% 코너 순서는 ArUco 규약(마커 기준 좌상·우상·우하·좌하)이며 영상 위치로
% 재정렬하지 않습니다(landing2d.sensing.markerGeometry).
% 검출 조건(co.detector): 네 코너가 카메라 앞, 최대 거리 이내이고, 잡음이 더해진
% 관측 코너가 영상 경계 안·최소 변 길이 이상(실제 검출기처럼 관측된 코너로 판정).
% 코너 잡음 RS: 결정 시점의 시간 기준 표준정규 블록 2 x 4 x M(등록 슬롯 순서,
% landing2d.sensing.exogenousNoise, 검출 여부와 무관한 값) 또는 RandStream(카메라
% 앞의 후보 마커마다 추출). pixelNoiseStd = 0이면 비워 둘 수 있습니다.
%   event.dropout        검출기 실패: 영상은 유효, 검출 없음
%   event.frameCaptured  false이면 사용할 영상 결과 없음
%   detections.valid      영상 결과 유효 여부
%   detections.stamp      영상 촬영 시각 (영상 없음이면 NaN)
%   detections.ids        N x 1 검출 ID
%   detections.corners    N x 4 x 2 [u,v] 픽셀 (0 기준, 왜곡 포함)
%   detections.imageSize  [W,H]
assert(~isfield(state,'y'),'landing2d:SpatialDimension', ...
    'detectMarkers supports the planar contract only.');
cam = co.camera;
det = co.detector;
W = cam.imageSize(1); H = cam.imageSize(2);
ids = zeros(0,1); corners = zeros(0,4,2);
stamp = t;
if ~event.frameCaptured, stamp = NaN; end
if event.dropout || ~event.frameCaptured
    detections = struct('valid',logical(event.frameCaptured),'stamp',stamp, ...
        'ids',ids,'corners',corners,'imageSize',[W,H]);
    return;
end
c = cos(state.theta); s = sin(state.theta);
bodyToWorld = [c,0,s; 0,1,0; -s,0,c];
cameraToWorld = bodyToWorld*cam.bodyToCamera(1:3,1:3);
origin = [state.x;0;state.z]+bodyToWorld*cam.bodyToCamera(1:3,4);
geometry = landing2d.sensing.markerGeometry(co.pad);
b = det.borderPixels;
for i = 1:numel(co.pad.markerIds)
    world = [pad.x+geometry(i,:,1);geometry(i,:,2);pad.z+geometry(i,:,3)];
    p = cameraToWorld'*(world-origin);
    if any(p(3,:) <= eps) || norm(mean(world,2)-origin) > sensor.maxRange
        continue;
    end
    xy = landing2d.sensing.distortPoints(p(1:2,:)./p(3,:),cam.distortion);
    uv = cam.intrinsicMatrix(1:2,:)*[xy;ones(1,4)];
    if det.pixelNoiseStd > 0
        assert(~isempty(rs),'landing2d:SensorNoise', ...
            'pixelNoiseStd > 0 needs a time-indexed noise block or a RandStream.');
        if isnumeric(rs)
            uv = uv+det.pixelNoiseStd*rs(:,:,i);
        else
            uv = uv+det.pixelNoiseStd*randn(rs,2,4);
        end
    end
    % The border check keeps every reported corner inside the image.
    inside = all(uv(1,:) >= b & uv(1,:) <= W-1-b & uv(2,:) >= b & uv(2,:) <= H-1-b);
    if ~inside || min(vecnorm(uv-uv(:,[2,3,4,1]),2,1)) < det.minimumSidePixels
        continue;
    end
    ids(end+1,1) = co.pad.markerIds(i); %#ok<AGROW>
    corners(end+1,:,:) = reshape(uv',1,4,2); %#ok<AGROW>
end
detections = struct('valid',true,'stamp',stamp,'ids',ids,'corners',corners, ...
    'imageSize',[W,H]);
end
