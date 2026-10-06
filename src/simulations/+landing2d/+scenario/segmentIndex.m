function id = segmentIndex(t, segmentTimes)
% SEGMENTINDEX  [0,t1), [t1,t2), [t2,tEnd]에 대응하는 구간 번호.
id = ones(size(t));
id(t >= segmentTimes(1)) = 2;
id(t >= segmentTimes(2)) = 3;
end
