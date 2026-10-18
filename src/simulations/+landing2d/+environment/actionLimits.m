function limits = actionLimits(c)
% ACTIONLIMITS  정규화 행동 한 단위의 가속도 [m/s^2] 열벡터.
%   [a_x,max; a_z,max]
limits = [c.axMax;c.azMax];
end
