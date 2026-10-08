function trace = predictFixedCommand(state,pad,acceleration,steps,status,c)
% PREDICTFIXEDCOMMAND  Hold one acceleration command on a copied state (evaluation only).
% The existing planar dynamics (landing2d.dynamics.stepPlanar) integrate the
% command for STEPS physics steps; the existing contact/envelope rules
% (landing2d.environment.evaluateTermination) classify the first event under
% the decision context STATUS held fixed. The pad moves at its current
% velocity (no future UGV acceleration is assumed known); the mission
% deadline is ignored. Nothing here feeds back into an episode, and the
% safety supervisor is not applied: this predicts the requested command.
%   trace.eventStep    step of the first event (Inf if none)
%   trace.eventReason  its reason ('' if none)
%   trace.h, vz        height above the pad plane and vertical speed per step
%   trace.ex, relVx    pad-minus-drone horizontal position and velocity per step
%   trace.fovMargin    camera FOV margin of the pad center per step [rad]
%                      (-1 when it is behind the camera or out of range)
d = c.experiment.dynamics;
sensor = c.experiment.sensor;
c.experiment.currentScenario.deadline = Inf;
blank = zeros(1,steps);
trace = struct('eventStep',Inf,'eventReason','','h',blank,'vz',blank, ...
    'ex',blank,'relVx',blank,'fovMargin',-ones(1,steps));
dt = c.experiment.physicsDt;
t = 0;
for k = 1:steps
    [next,info] = landing2d.dynamics.stepPlanar(state,acceleration,dt,d,0);
    padNext = pad;
    padNext.x = pad.x+pad.vx*dt;
    event = landing2d.environment.evaluateTermination(state,next,pad,padNext, ...
        status,t,dt,c,info);
    state = next; pad = padNext; t = t+dt;
    trace.h(k) = state.z-pad.z;
    trace.vz(k) = state.vz;
    trace.ex(k) = pad.x-state.x;
    trace.relVx(k) = pad.vx-state.vx;
    p = landing2d.sensing.projectPad(state,pad,sensor);
    if p.depth > 0 && p.range <= sensor.maxRange && isfinite(p.fovMargin)
        trace.fovMargin(k) = p.fovMargin;
    end
    if event.occurred
        trace.eventStep = k;
        trace.eventReason = event.reason;
        for name = {'h','vz','ex','relVx','fovMargin'}
            trace.(name{1}) = trace.(name{1})(1:k);
        end
        return;
    end
end
end
