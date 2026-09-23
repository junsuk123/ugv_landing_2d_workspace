function memory = initialMemory(padSpeed)
% INITIALMEMORY  관측 기억 초기화. 시작 시점 패드 속도만 알고 있다고 가정.
memory = struct('lastError',0,'lastPadSpeed',padSpeed,'timeSinceSeen',0);
end
