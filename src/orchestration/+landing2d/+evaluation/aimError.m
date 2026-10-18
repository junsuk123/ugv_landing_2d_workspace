function e = aimError(xPad,xDrone,height,c)
% AIMERROR  Horizontal error from the camera-aim point the common reward tracks.
%   e = landing2d.evaluation.aimError(xPad,xDrone,height,c)
% e_aim = e_x - m h with e_x = x_pad - x_drone, h = max(height above pad, 0)
% and m = tan(-cameraPitchOffset), the slope of landing2d.rl.computeReward
% (docs/REWARD_KO.md, e_x^* = m h) and of the TOSM crossTrack feature. The
% camera is mounted pitched back (cameraPitchOffset < 0), so the designed
% approach keeps the drone m h behind the pad and e_aim = 0 there; at
% touchdown (h = 0) e_aim = e_x. Evaluation and figures only.
m = tan(-c.experiment.sensor.cameraPitchOffset);
e = (xPad-xDrone)-m*max(height,0);
end
