function [fov,pitchOffset] = planarCameraGeometry(camera)
% PLANARCAMERAGEOMETRY  카메라 보정(K, BT_C) -> x-z 평면 카메라 기하 (sensor.fov, cameraPitchOffset).
% 평면 실험의 카메라는 하나입니다. tracker 측정(projectPad)·보상 시야 항·시각화가
% 마커 카메라와 같은 광축과 시야를 쓰도록 보정값에서 직접 계산합니다.
%   fov          영상 세로축(x-z 평면에 놓인 축)의 전체 시야각
%   pitchOffset  기체 pitch 0에서 광축의 수직 하향 대비 회전 (projectPad: theta+offset,
%                광축 [-sin, -cos]); 전방 아래 60도 장착이면 -30도
% 영상 세로축이 x-z 평면에 있어야 합니다(영상 오른쪽 = 기체 측방).
K = camera.intrinsicMatrix;
R = camera.bodyToCamera(1:3,1:3);
assert(abs(R(2,2)) < 1e-12 && abs(R(2,3)) < 1e-12, 'landing2d:CameraGeometry', ...
    'The image vertical axis and optical axis must lie in the body x-z plane.');
H = camera.imageSize(2);
fov = atan(K(2,3)/K(2,2))+atan((H-1-K(2,3))/K(2,2));
pitchOffset = atan2(-R(1,3),-R(3,3));
end
