function [s,event] = trackingMode(s,obs,c)
% TRACKINGMODE  추종/탐색 상태기계. 유도 법칙과 강화학습 정책이 함께 사용합니다.
% mode: 1=추종/착륙, 2=상승 탐색, 3=착륙 완료, 4=접촉 실패
% event: 0=없음, 1=시야 이탈, 2=재포착
%
% 착륙 판정이 mode==1을 요구하므로, 모든 비교군이 같은 조건에서 평가됩니다.
% 가속도 명령만 제어기가 결정하고 이 전환 규칙은 환경 쪽에 둡니다.
% 기존 pdController는 회귀 비교를 위해 같은 규칙을 자기 안에 그대로 유지합니다.
event = 0;
if s.mode >= 3
    return;
end
if obs.visible
    s.lastPadSpeed = obs.padSpeed;
end
if ~obs.visible && s.mode ~= 2
    s.mode = 2;
    s.seenTime = 0;
    event = 1;
elseif s.mode == 2
    if obs.visible && abs(obs.xError) <= c.reacquireInnerRatio*obs.halfWidth
        s.seenTime = s.seenTime+c.dt;
    else
        s.seenTime = 0;
    end
    if s.seenTime+1e-12 >= c.reacquireHoldTime
        s.mode = 1;
        s.seenTime = 0;
        event = 2;
    end
end
end
