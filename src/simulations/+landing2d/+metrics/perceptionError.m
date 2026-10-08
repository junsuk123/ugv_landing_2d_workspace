function e = perceptionError(O,pad,G)
% PERCEPTIONERROR  평가 전용 UGV 상태추정 오차 (추정 - 참값). 정책 입력이 아닙니다.
% UGV 참값 기준점 = 패드 상면 중심 - r_{G->P}. 수평 직선 주행이므로 참 v_Gz = 0.
% 초기화 전이면 valid = false이고 오차는 NaN입니다. 에피소드 RMSE는 이 값을 모아
% 별도로 계산합니다(논문 보고 RMSE를 관측 잡음으로 더하지 않습니다).
truthPosition = [pad.x;pad.z]-G.ugv.padOffset(:);
truthVelocity = [pad.vx;0];
e = struct('valid',O.ugv.estimateInitialized,'visionUpdated',O.ugv.visionUpdated, ...
    'position',NaN(2,1),'velocity',NaN(2,1));
if e.valid
    e.position = O.ugv.positionXZ-truthPosition;
    e.velocity = O.ugv.velocityXZ-truthVelocity;
end
end
