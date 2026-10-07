function limits = actionLimits(c)
% ACTIONLIMITS  정규화 행동 한 단위의 가속도 [m/s^2] 열벡터.
%   2D: [a_x,max; a_z,max]
%   3D: [a_x,max; a_y,max; a_z,max]   (수직 성분은 항상 마지막)
if landing2d.environment.isSpatial(c)
    limits = [c.axMax;c.experiment.spatial.lateralAccelerationLimit;c.azMax];
else
    limits = [c.axMax;c.azMax];
end
end
