function [s,ax,az,descending,event] = pnGuidance(s,obs,c)
% PNGUIDANCE  비례 항법(Proportional Navigation) 기반 착륙 유도.
% 출력은 수평/수직 가속도 명령 [m/s^2]이며, 속도나 자세 명령이 아닙니다.
%
% 추종 구간(mode 1)에서는 드론에서 패드로 향하는 시선(LOS) 기준으로 두 성분을 만듭니다.
%
%   시선 직교 성분 : a_perp = N * Vc * lambda_dot      (시선각 속도를 0으로)
%   시선 방향 성분 : a_par  = k * (Vc_ref - Vc)        (접근 속도를 거리에 맞게)
%
% 순수 비례 항법만 쓰면 접근 속도가 남아 충돌이 되므로, 접근 속도 기준을
% Vc_ref = min(pnApproachSpeed, pnApproachGain*R)로 두어 거리와 함께 0으로 보냅니다.
% 시선각 속도를 0으로 유지하면 시선각이 일정하게 유지되므로, 재포착 이후에는
% 패드가 시야 안의 같은 상대 위치에 머문 채로 접근합니다.
%
% 재포착 구간(mode 2)은 종말 유도가 아니라 중간 유도에 해당하므로 다른 법칙을 씁니다.
% 상승해 시야를 넓히면서, 패드가 시야 가장자리에 들어오면 시선을 수직으로 되돌립니다.
% 이때 비례 항법을 그대로 쓰면 시선각이 보존되어 상승과 함께 수평 오차가 오히려
% 커지므로, 이 구간에서는 시선 오차를 직접 줄이는 정렬 항을 사용합니다.
% 패드가 보이지 않는 동안에는 마지막으로 관측한 패드 속도만 사용합니다.
ax = 0; az = 0; descending = false; event = 0;
if s.mode >= 3
    return;
end
[s,event] = landing2d.control.trackingMode(s,obs,c);
if s.mode == 2
    if obs.visible
        velocityError = obs.vError;
        positionError = obs.xError;
    else
        velocityError = s.lastPadSpeed-s.vx;
        positionError = 0;
    end
    ax = c.pnSpeedMatchGain*(velocityError+c.pnRecoveryGain*positionError);
    climbReference = min(c.climbSpeed,c.pnHeightGain*max(c.maxHeight-s.h,0));
    az = c.pnVerticalGain*(climbReference-s.vz);
else
    % 상대 위치와 상대 속도. 패드가 아래에 있으므로 z 성분은 -h.
    rangeX = obs.xError;
    rangeZ = -s.h;
    rateX = obs.vError;
    rateZ = -s.vz;
    range = max(hypot(rangeX,rangeZ),c.pnMinRange);
    losRate = (rangeX*rateZ-rangeZ*rateX)/range^2;
    closingSpeed = -(rangeX*rateX+rangeZ*rateZ)/range;
    losUnit = [rangeX;rangeZ]/range;
    perpendicular = [-losUnit(2);losUnit(1)];
    closingReference = min(c.pnApproachSpeed,c.pnApproachGain*range);
    % 직교 성분의 유도 이득으로 접근 속도 Vc 대신 상대 속도 크기를 사용합니다.
    % 충돌 경로 위에서는 |v| = Vc 이므로 진 비례 항법과 같고,
    % 재포착 직후처럼 시선각 속도가 큰 구간에서는 더 큰 권한을 줍니다.
    % 접근 속도를 그대로 쓰면 Vc<0일 때 부호가 뒤집히는 문제도 함께 사라집니다.
    relativeSpeed = max(hypot(rateX,rateZ),c.pnMinClosing);
    acceleration = c.pnGain*relativeSpeed*losRate*perpendicular ...
        +c.pnClosingGain*(closingReference-closingSpeed)*losUnit;
    ax = acceleration(1);
    az = acceleration(2);
end
% 비례 항법은 기준 궤적을 적분하지 않습니다. 로그 일관성을 위해 실제 고도를 남깁니다.
s.heightReference = s.h;
ax = landing2d.util.saturate(ax,c.axMax);
az = landing2d.util.saturate(az,c.azMax);
descending = s.mode == 1 && s.vz < 0;
end
