function nav = navigationEstimate(state,t,noise,rs)
% NAVIGATIONESTIMATE  드론 융합 측위 출력 모사 -> D_t 형식 (센서 모델, 기체 참값 사용).
% 논문 설정을 1σ 평균 0 가우시안으로 해석합니다(co.navigation):
%   pitch      theta^ = theta + N(0, attitudeNoiseStd^2), sin/cos는 theta^에서 계산
%   속도       기체 좌표계 속도 v^B + N(0, velocityNoiseStd^2 I), 추정 자세 R_WB(theta^)로
%              로컬 좌표계에 되돌립니다
% 위치·pitch rate 잡음은 제시되지 않아 넣지 않습니다. z는 기준 좌표계상 높이이며
% 패드까지의 상대 높이가 아닙니다. navigationAge는 capture가 결정 시각 기준으로 채웁니다.
% RS: 결정 시점의 시간 기준 표준정규 [pitch; 기체 vx; 기체 vz]
% (landing2d.sensing.exogenousNoise) 또는 RandStream. 잡음이 모두 0이면 참값을 그대로 씁니다.
assert(~isfield(state,'y'),'landing2d:SpatialDimension', ...
    'navigationEstimate supports the planar contract only.');
theta = state.theta;
velocity = [state.vx;state.vz];
if (noise.attitudeNoiseStd > 0 || noise.velocityNoiseStd > 0) ...
        && ~(isnumeric(rs) && ~any(rs(:)))
    if isnumeric(rs)
        z = rs(:);
    else
        z = [randn(rs);randn(rs,2,1)];
    end
    theta = state.theta+noise.attitudeNoiseStd*z(1);
    bodyVelocity = bodyToLocal(state.theta)'*velocity+noise.velocityNoiseStd*z(2:3);
    velocity = bodyToLocal(theta)*bodyVelocity;
end
nav = struct('positionXZ',[state.x;state.z],'velocityXZ',velocity, ...
    'pitchSinCos',[sin(theta);cos(theta)],'pitchRate',state.pitchRate, ...
    'navigationValid',true,'navigationAge',0,'navigationStamp',t);
end

function R = bodyToLocal(theta)
% R_WB = R_y(theta)의 x-z 성분 (기체 x 전방·z 추력축 -> 로컬 x·z).
R = [cos(theta),sin(theta); -sin(theta),cos(theta)];
end
