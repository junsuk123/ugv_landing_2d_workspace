function m = commandMargins(trace,steps,c)
% COMMANDMARGINS  Constraint margins and task quantities of a held command.
% TRACE comes from landing2d.metrics.predictFixedCommand; quantities are taken
% at the horizon (STEPS) or at the first event. Margins >= 0 hold.
%   contact   +1 no event or an authorized safe touchdown (SUCCESS); -1 for an
%             unsafe, unauthorized or off-pad contact or an envelope violation
%   braking   height left above the touchdown plane at the horizon minus the
%             distance needed to slow to the touchdown speed with the vertical
%             thrust margin after the supervisor response delay [m]
%             (+1 after a safe touchdown, -1 after a violating event)
%   fov       smallest camera FOV margin of the pad center over the horizon [rad]
%   reason    violated contact rule ('' if none)
% Task quantities (lower is better; compared only against other commands from
% the same state by landing2d.metrics.admissibleActions):
%   relativeSpeed  |pad vx - drone vx| at the horizon [m/s]
%   stopError      |e_x + v_rel |v_rel| / (2 axMax)|: horizontal error to the pad
%                  center where the relative motion can be nulled [m]
%   height         height above the pad plane at the horizon (0 after touchdown) [m]
s = c.experiment.safety;
d = c.experiment.dynamics;
m = struct('contact',1,'braking',1,'fov',NaN,'reason','', ...
    'relativeSpeed',NaN,'stopError',NaN,'height',NaN);
if trace.eventStep <= steps
    last = trace.eventStep;
    switch trace.eventReason
        case 'SUCCESS'
        case 'UNSAFE_CONTACT'
            m.contact = -1; m.braking = -1; m.reason = 'unsafe_contact';
        case 'UNAUTHORIZED_CONTACT'
            m.contact = -1; m.braking = -1; m.reason = 'unauthorized_contact';
        case 'MISSED_PAD_CONTACT'
            m.contact = -1; m.braking = -1; m.reason = 'missed_pad_contact';
        case 'SAFETY_ENVELOPE_VIOLATION'
            m.contact = -1; m.braking = -1; m.reason = 'envelope_violation';
    end
else
    last = steps;
    speed = max(0,-trace.vz(steps));
    brake = max(1e-6,d.maxThrustWeightRatio*d.gravity-d.gravity);
    need = 0;
    if speed > s.touchdownSpeedZ
        need = speed*s.responseDelay+(speed^2-s.touchdownSpeedZ^2)/(2*brake);
    end
    m.braking = trace.h(steps)-s.touchdownHeight-need;
end
m.fov = min(trace.fovMargin(1:last));
v = trace.relVx(last);
m.relativeSpeed = abs(v);
m.stopError = abs(trace.ex(last)+v*abs(v)/(2*c.axMax));
m.height = max(trace.h(last),0);
if strcmp(trace.eventReason,'SUCCESS') && trace.eventStep <= steps, m.height = 0; end
end
