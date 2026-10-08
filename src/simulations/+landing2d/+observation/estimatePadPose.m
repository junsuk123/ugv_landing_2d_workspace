function pose = estimatePadPose(detections,G)
% ESTIMATEPADPOSE  ArUco 코너 -> 카메라 기준 패드 자세 CT_P (마커 보드 평면 PnP).
% G = 부가 정보 Gamma. 검출된 등록 마커의 네 코너(검출기 순서 = ArUco 규약)를
% Gamma의 패드 기준 실제 코너와 ID로 대응시킵니다. 미등록·중복 ID는 쓰지 않습니다.
% 일부 마커만 보여도 남은 코너로 같은 패드 원점(패드 상면 중심)을 추정하며,
% 영상 코너 평균을 패드 중심으로 쓰지 않습니다.
%   1) 코너를 K, d로 왜곡 보정
%   2) 정규화 DLT 호모그래피를 [r1 r2 t]로 분해해 초기값
%   3) 재투영 오차(픽셀) Gauss-Newton 정련, R은 좌측 미소 회전으로 갱신
% 채택 조건: 모든 코너가 카메라 앞, 카메라가 패드 앞면 쪽, 재투영 RMS <=
% estimator.maxReprojectionError, 야코비안 열 랭크 6(퇴화한 코너 배치가 아님).
% 재투영 오차는 기하 일치 정도이지 위치 오차가 아닙니다.
% translationCovariance = cornerNoiseStd^2 (J'J)^-1의 이동 성분 (1차 근사).
%   pose.rotation     R_CP (패드 -> 카메라)
%   pose.translation  t_CP (카메라 기준 패드 원점) [m]
pose = struct('valid',false,'rotation',eye(3),'translation',zeros(3,1), ...
    'translationCovariance',zeros(3),'reprojectionRms',NaN,'markerCount',0);
if ~detections.valid || isempty(detections.ids)
    return;
end
ids = G.pad.markerIds(:);
[registered,slot] = ismember(detections.ids(:),ids);
counts = accumarray(slot(registered),1,[numel(ids),1]);
use = find(registered & counts(max(slot,1)) == 1);
if isempty(use)
    return;
end
cam = G.camera;
K = cam.intrinsicMatrix;
n = 4*numel(use);
object = zeros(3,n);
pixels = zeros(2,n);
for j = 1:numel(use)
    k = use(j);
    columns = 4*(j-1)+(1:4);
    object(:,columns) = reshape(G.pad.markerCorners(slot(k),:,:),4,3)';
    pixels(:,columns) = landing2d.sensing.undistortPoints( ...
        reshape(detections.corners(k,:,:),4,2)',K,cam.distortion);
end
normalized = K\[pixels;ones(1,n)];
[R,t] = homographyPose(object(1:2,:),normalized(1:2,:));
% A degenerate corner configuration (collapsed or non-finite corners) leaves
% the pose unobservable; it is rejected instead of solved.
degenerate = false;
for iteration = 1:G.estimator.pnpIterations
    [r,J] = reprojection(R,t,object,pixels,K);
    if ~all(isfinite(J(:))) || ~all(isfinite(r)) || rank(J) < 6
        degenerate = true;
        break;
    end
    step = -(J\r);
    R = rodrigues(step(1:3))*R;
    t = t+step(4:6);
    if norm(step) < 1e-12, break; end
end
[r,J,depth] = reprojection(R,t,object,pixels,K);
rms = sqrt(mean(sum(reshape(r,2,[]).^2,1)));
covariance = NaN(6);
information = J'*J;
if ~degenerate && all(isfinite(information(:))) && rcond(information) > eps
    covariance = G.estimator.cornerNoiseStd^2*(information\eye(6));
end
valid = ~degenerate && all(depth > 0) && dot(R(:,3),-t) > 0 ...
    && rms <= G.estimator.maxReprojectionError && all(isfinite(covariance(:)));
pose = struct('valid',valid,'rotation',R,'translation',t, ...
    'translationCovariance',covariance(4:6,4:6),'reprojectionRms',rms, ...
    'markerCount',numel(use));
end

function [R,t] = homographyPose(planar,image)
% 평면 점 [X;Y] -> 정규화 영상 좌표 [x;y] 호모그래피 H ~ [r1 r2 t].
[planarN,Tp] = normalizePoints(planar);
[imageN,Ti] = normalizePoints(image);
n = size(planar,2);
A = zeros(2*n,9);
for i = 1:n
    X = [planarN(:,i);1]';
    A(2*i-1,:) = [X,zeros(1,3),-imageN(1,i)*X];
    A(2*i,:) = [zeros(1,3),X,-imageN(2,i)*X];
end
[~,~,V] = svd(A);
H = Ti\reshape(V(:,end),3,3)'*Tp;
scale = 2/(norm(H(:,1))+norm(H(:,2)));
if H(3,3) < 0, scale = -scale; end
r1 = scale*H(:,1); r2 = scale*H(:,2); t = scale*H(:,3);
[U,~,W] = svd([r1,r2,cross(r1,r2)]);
R = U*diag([1,1,det(U*W')])*W';
end

function [normalized,T] = normalizePoints(points)
% Hartley 정규화: 중심 0, 평균 거리 sqrt(2).
center = mean(points,2);
distance = mean(vecnorm(points-center,2,1));
s = sqrt(2)/max(distance,eps);
T = [s,0,-s*center(1); 0,s,-s*center(2); 0,0,1];
normalized = s*(points-center);
end

function [r,J,depth] = reprojection(R,t,object,pixels,K)
% 픽셀 잔차 [u1 v1 u2 v2 ...]'와 [delta_omega; delta_t]에 대한 야코비안.
n = size(object,2);
p = R*object+t;
depth = p(3,:);
r = zeros(2*n,1);
J = zeros(2*n,6);
A = K(1:2,1:2);
for i = 1:n
    rows = 2*i-1:2*i;
    q = p(:,i);
    r(rows) = A*(q(1:2)/q(3))+K(1:2,3)-pixels(:,i);
    projection = [1/q(3),0,-q(1)/q(3)^2; 0,1/q(3),-q(2)/q(3)^2];
    rotated = q-t;
    J(rows,:) = A*projection*[-skew(rotated),eye(3)];
end
end

function R = rodrigues(w)
angle = norm(w);
if angle < 1e-12
    R = eye(3)+skew(w);
    return;
end
k = skew(w/angle);
R = eye(3)+sin(angle)*k+(1-cos(angle))*k*k;
end

function S = skew(v)
S = [0,-v(3),v(2); v(3),0,-v(1); -v(2),v(1),0];
end
