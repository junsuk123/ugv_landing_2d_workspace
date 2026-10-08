function [y,covariance] = ugvPositionMeasurement(pose,navigation,G)
% UGVPOSITIONMEASUREMENT  패드 자세 + 드론 측위 + 장착 관계 -> 로컬 UGV 위치 관측 [x_G; z_G].
%   WT_G = WT_B * BT_C * CT_P * PT_G
%   p_P^W = p_B^W + R_WB(theta^) (t_BC + R_BC t_CP)
%   p_G^W = p_P^W - R_WG r_{G->P},  R_WG = I (수평 직선 주행 가정)
% WT_B는 촬영 시각의 드론 융합 측위(위치, 추정 pitch)이므로, UGV 관측 오차는 드론
% 측위 오차를 공유합니다. 한 프레임에서 얻는 것은 위치이며 속도는 추정기가 시계열로 구합니다.
% 공분산 = PnP 이동 공분산의 로컬 회전 + 추정 자세 잡음(estimator.attitudeNoiseStd) 성분.
theta = atan2(navigation.pitchSinCos(1),navigation.pitchSinCos(2));
c = cos(theta); s = sin(theta);
bodyToLocal = [c,0,s; 0,1,0; -s,0,c];
bodyToLocalRate = [-s,0,c; 0,0,0; -c,0,-s];
mount = G.camera.bodyToCamera;
padInBody = mount(1:3,4)+mount(1:3,1:3)*pose.translation;
padInLocal = [navigation.positionXZ(1);0;navigation.positionXZ(2)]+bodyToLocal*padInBody;
y = padInLocal([1,3])-G.ugv.padOffset(:);
cameraToLocal = bodyToLocal*mount(1:3,1:3);
attitudeJacobian = bodyToLocalRate*padInBody;
full = cameraToLocal*pose.translationCovariance*cameraToLocal' ...
    +G.estimator.attitudeNoiseStd^2*(attitudeJacobian*attitudeJacobian');
covariance = full([1,3],[1,3]);
end
