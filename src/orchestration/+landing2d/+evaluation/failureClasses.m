function classes = failureClasses()
% FAILURECLASSES  Ordered outcome classes of landing2d.evaluation.episodeMetrics (FailureClass).
% Deterministic rules on evaluation-only truth, fixed before the results
% (thresholds in c.evaluation.tracking / c.evaluation.failure):
%   SUCCESS                         mechanically safe contact on the pad
%   LARGE_TOUCHDOWN_POSITION_ERROR  contact outside the pad footprint
%   HIGH_TOUCHDOWN_RELATIVE_SPEED   on the pad, |v_r| above touchdownSpeedX
%   HIGH_TOUCHDOWN_VERTICAL_SPEED   on the pad, |v_z| above touchdownSpeedZ
%   UNSAFE_TOUCHDOWN_ATTITUDE       on the pad, only pitch / pitch rate exceeded
%   REACQUISITION_FAILURE           timeout; the marker was never measured again
%                                   after an injected dropout
%   FOV_LOSS                        timeout; pad geometrically outside the camera
%                                   view for >= failure.viewLossFraction of the
%                                   final failure.finalWindow seconds
%   TIMEOUT_TRACKING                timeout; final-window aim-error RMS above the
%                                   tracking tolerance (did not stay on the pad)
%   TIMEOUT_HOVERING                timeout while tracking within the tolerance
%                                   (did not complete the descent)
%   OTHER_FAILURE                   every other termination (e.g. envelope)
% Contact classes are checked in this order; timeout classes in this order.
classes = ["SUCCESS","LARGE_TOUCHDOWN_POSITION_ERROR","HIGH_TOUCHDOWN_RELATIVE_SPEED", ...
    "HIGH_TOUCHDOWN_VERTICAL_SPEED","UNSAFE_TOUCHDOWN_ATTITUDE","REACQUISITION_FAILURE", ...
    "FOV_LOSS","TIMEOUT_TRACKING","TIMEOUT_HOVERING","OTHER_FAILURE"];
end
