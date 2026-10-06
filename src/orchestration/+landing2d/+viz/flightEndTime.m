function tEnd = flightEndTime(r)
% FLIGHTENDTIME  비행이 끝난 시각. 착륙/실패가 없으면 모사 종료 시각.
tEnd = r.time(end);
if isfinite(r.landingTime)
    tEnd = r.landingTime;
end
if isfinite(r.failureTime)
    tEnd = min(tEnd,r.failureTime);
end
end
