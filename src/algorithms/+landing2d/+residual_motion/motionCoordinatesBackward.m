function dx = motionCoordinatesBackward(dCoordinates,jacobian)
% Pull back the correction branch only; the base policy retains raw o_t.
dx = dCoordinates;
dx(3,:) = dCoordinates(3,:).*jacobian.relative;
dx(4,:) = dCoordinates(4,:)+dCoordinates(3,:).*jacobian.target;
end
