function uv = undistortPoints(uvd,K,d)
% UNDISTORTPOINTS  왜곡된 픽셀 좌표 (2 x N) -> 왜곡 보정된 픽셀 좌표 (2 x N).
% OpenCV undistortPoints(P = K)에 해당합니다. K^-1로 정규화 좌표를 구하고
% landing2d.sensing.distortPoints의 역을 고정점 반복으로 푼 뒤 같은 K로 되돌립니다.
% 왜곡 모델은 distortPoints 한 곳에만 정의합니다. 왜곡이 없으면 입력 그대로입니다.
if ~any(d)
    uv = uvd;
    return;
end
n = size(uvd,2);
xyd = K\[uvd;ones(1,n)];
xyd = xyd(1:2,:);
xy = xyd;
for iteration = 1:50
    residual = xyd-landing2d.sensing.distortPoints(xy,d);
    xy = xy+residual;
    if max(abs(residual(:))) < 1e-12, break; end
end
uv = K(1:2,:)*[xy;ones(1,n)];
end
