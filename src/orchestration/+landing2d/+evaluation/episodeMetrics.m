function metric = episodeMetrics(result,traj,c,identity,eventWindow)
% EPISODEMETRICS  Evaluation-only metrics of one rollout (relational_policy_v1).
%   metric = landing2d.evaluation.episodeMetrics(result,traj,c,identity,eventWindow)
% RESULT/TRAJ from landing2d.rl.rolloutEpisodeV2 (deterministic direct policy).
% IDENTITY is a scalar struct whose fields lead the row. EVENTWINDOW = [t0,t1] is
% the event interval of a fixed case (metrics over [t0, t1 + settling)), or []
% for sampled episodes (window metrics NaN). Truth is read only here, after
% the rollout; nothing is fed back to a policy, and no metric uses an ontology
% node, attention or reward term.
%
% Factors     MotionFactor (UGV accelerates), ObservationFactor (exogenous
%             dropout), DropoutKind, InitialSpeedOffset
% Mission     Success, Unsafe, Timeout, Return, LandingTime_s, FailureClass
%             (landing2d.evaluation.failureClasses)
% Tracking    aim error e_aim = e_x - m h, m = tan(-camera pitch offset)
%             (landing2d.evaluation.aimError): horizontal error from the
%             camera-aim point the common reward tracks (0 at touchdown);
%             relative speed v_r = v_pad - v_drone
% Command     CommandRateRMS: time-weighted RMS of the requested-command rate
%             over consecutive decisions [m/s^3] (direct policy: requested = applied)
% Events      SpeedRematch_s (|v_r| <= touchdownSpeedX held 1 s after the CA
%             phase), RecoveryTime_s (CA episodes: t_r - T1, t_r = first time
%             at or after the end of the CA phase from which |e_aim| <=
%             tracking tolerance holds for evaluation.tracking.hold s or until
%             the episode ends), ReacquisitionLatency_s (dropout end -> first
%             marker measurement), TrackingReacquisition_s (that measurement ->
%             |e_aim| back inside the tolerance, same hold rule),
%             ExogenousDropout_s, and ApproachViewLoss_s: pad outside the
%             camera view above the readiness height outside any exogenous
%             dropout (policy-induced view loss, recorded separately from the
%             injected dropout)
% Landing     UnsuitableDescent_s: descending below the readiness height while
%             a touchdown limit is exceeded or the remaining height cannot
%             brake to touchdownSpeedZ within azMax; ContactMaxRatio;
%             Touchdown{PositionError_m, RelativeSpeed_mps, VerticalSpeed_mps}:
%             |e_x|, |v_r|, |v_z| at contact (NaN without contact)
% The tracking tolerance is safety.touchdownPositionTolerance.
if nargin < 5, eventWindow = []; end
n = traj.count;
assert(n>0,'landing2d:EmptyRollout','Rollout produced no decisions.');
safety = c.experiment.safety;
sensor = c.experiment.sensor;
scenario = result.scenario;
events = result.resetInfo.evaluatorMetadata.sensorEvents;
t = result.time(1:n);
dt = traj.dt(:)';
endTime = result.time(n+1);
ex = result.xPad(1:n)-result.xDrone(1:n);
height = result.zDrone(1:n)-scenario.padHeight;
aimError = landing2d.evaluation.aimError(result.xPad(1:n),result.xDrone(1:n),height,c);
relativeVx = result.vxPad(1:n)-result.vxDrone(1:n);
tolerance = safety.touchdownPositionTolerance;
holdSeconds = c.evaluation.tracking.hold;
vz = result.vzDrone(1:n);
theta = result.theta(1:n);
pitchRate = result.pitchRate(1:n);
% result.visible: per-decision marker measurement update (visionUpdated);
% padInGeometricView: pad centre inside the camera FOV and range (truth).
visionUpdated = logical(result.visible(1:n));
requestedAcceleration = traj.requestedAcceleration;   % [m/s^2], 2 x n

padInGeometricView = false(1,n);
for k = 1:n
    state = struct('x',result.xDrone(k),'z',result.zDrone(k),'theta',theta(k));
    pad = struct('x',result.xPad(k),'z',scenario.padHeight);
    padInGeometricView(k) = landing2d.sensing.projectPad(state,pad,sensor).visible;
end
inDropout = t>=events.dropoutStart & t<events.dropoutEnd;
readiness = c.experiment.reward.readinessHeight;
approach = height>readiness;

windowSeconds = 0; inWindow = false(1,n);
if ~isempty(eventWindow)
    span = [max(0,eventWindow(1)),min(endTime,eventWindow(2)+c.evaluation.settling)];
    inWindow = t>=span(1) & t<span(2);
    windowSeconds = weighted(inWindow,dt);
end

reacquisitionLatency = NaN; trackingReacquisition = NaN;
if isfinite(events.dropoutEnd)
    index = find(result.time>=events.dropoutEnd & result.visible,1,'first');
    if ~isempty(index)
        reacquisitionLatency = max(0,result.time(index)-events.dropoutEnd);
        restored = events.dropoutEnd+reacquisitionLatency;
        trackingReacquisition = settleTime(t,aimError,restored,restored,tolerance,holdSeconds);
    end
end
speedRematch = NaN; recoveryTime = NaN;
if scenario.a2 > 0
    speedRematch = rematchTime(t,relativeVx,scenario.T1+scenario.T2,safety.touchdownSpeedX,1.0);
    recoveryTime = settleTime(t,aimError,scenario.T1,scenario.T1+scenario.T2,tolerance,holdSeconds);
end

low = height<=readiness;
descending = vz < -0.05;
limitExceeded = abs(ex)>safety.touchdownPositionTolerance ...
    | abs(relativeVx)>safety.touchdownSpeedX ...
    | abs(theta)>safety.touchdownPitchTolerance ...
    | abs(pitchRate)>safety.touchdownPitchRateTolerance;
brakingHeight = max(height-safety.touchdownHeight,0.01);
brakeDemand = max(vz.^2-safety.touchdownSpeedZ^2,0)./(2*brakingHeight);
unsuitable = limitExceeded | brakeDemand>c.azMax;
contactLimitRatio = contactRatios(result,c);

reason = string(result.terminalReason);
unsafeReasons = ["UNSAFE_CONTACT","UNAUTHORIZED_CONTACT","MISSED_PAD_CONTACT", ...
    "SAFETY_ENVELOPE_VIOLATION"];
initialSpeedOffset = 0;
if isfield(scenario,'initialSpeedOffset'), initialSpeedOffset = scenario.initialSpeedOffset; end
touchdown = NaN(1,3);
if isfinite(contactLimitRatio(1))
    touchdown = abs([result.contact.xError,result.contact.relativeVx,result.contact.relativeVz]);
end
final = t>=endTime-c.evaluation.failure.finalWindow-1e-9;
finalAim = rmsOf(aimError(final),dt(final));
finalViewLoss = weighted(final & ~padInGeometricView,dt)/max(weighted(final,dt),eps);
lostMarker = isfinite(events.dropoutEnd) && isnan(reacquisitionLatency);
failure = failureClass(reason,contactLimitRatio,finalAim,finalViewLoss,lostMarker,tolerance, ...
    c.evaluation.failure.viewLossFraction);
row = struct('MotionFactor',double(scenario.a2>0), ...
    'ObservationFactor',double(isfinite(events.dropoutStart)), ...
    'DropoutKind',string(events.dropoutKind),'UgvAcceleration',scenario.a2, ...
    'InitialSpeedOffset',initialSpeedOffset,'InitialHeight',scenario.height, ...
    'TerminalReason',reason,'FailureClass',failure,'Success',double(reason=="SUCCESS"), ...
    'Unsafe',double(ismember(reason,unsafeReasons)),'Timeout',double(reason=="TASK_TIMEOUT"), ...
    'Return',result.return,'LandingTime_s',result.landingTime, ...
    'Duration_s',sum(dt), ...
    'AimErrorRMS_m',rmsOf(aimError,dt),'RelativeSpeedRMS_mps',rmsOf(relativeVx,dt), ...
    'CommandRateRMS_mps3',commandRate(t,requestedAcceleration,true(1,n)), ...
    'WindowSeconds',windowSeconds, ...
    'WindowAimErrorRMS_m',windowValue(@()rmsOf(aimError(inWindow),dt(inWindow)),windowSeconds), ...
    'WindowMaxAbsAimError_m',windowValue(@()max(abs(aimError(inWindow))),windowSeconds), ...
    'WindowRelativeSpeedRMS_mps',windowValue(@()rmsOf(relativeVx(inWindow),dt(inWindow)),windowSeconds), ...
    'WindowMaxAbsRelativeSpeed_mps',windowValue(@()max(abs(relativeVx(inWindow))),windowSeconds), ...
    'WindowCommandRateRMS_mps3',windowValue(@()commandRate(t,requestedAcceleration,inWindow),windowSeconds), ...
    'SpeedRematch_s',speedRematch,'RecoveryTime_s',recoveryTime, ...
    'ReacquisitionLatency_s',reacquisitionLatency,'TrackingReacquisition_s',trackingReacquisition, ...
    'ExogenousDropout_s',weighted(inDropout,dt), ...
    'ApproachViewLoss_s',weighted(approach & ~inDropout & ~padInGeometricView,dt), ...
    'MeasuredViewLoss_s',weighted(~visionUpdated,dt), ...
    'UnsuitableDescent_s',weighted(low & descending & unsuitable,dt), ...
    'ContactMaxRatio',max(contactLimitRatio), ...
    'TouchdownPositionError_m',touchdown(1),'TouchdownRelativeSpeed_mps',touchdown(2), ...
    'TouchdownVerticalSpeed_mps',touchdown(3), ...
    'FinalAimErrorRMS_m',finalAim,'FinalViewLossFraction',finalViewLoss);
names = [fieldnames(identity);fieldnames(row)];
values = [struct2cell(identity);struct2cell(row)];
metric = cell2struct(values,names,1);
end

function value = weighted(mask,dt)
value = sum(dt.*double(mask));
end

function value = rmsOf(x,dt)
value = sqrt(sum(dt.*x.^2)/max(sum(dt),eps));
end

function value = windowValue(f,seconds)
if seconds<=0, value = NaN; else, value = f(); end
end

function value = commandRate(t,a,mask)
% Command a(:,k) holds from t(k); only consecutive decisions inside MASK count.
sumSquares = 0; weight = 0;
for k = 1:numel(t)-1
    if ~(mask(k) && mask(k+1)), continue; end
    h = t(k+1)-t(k);
    if h<=0, continue; end
    sumSquares = sumSquares+sum(((a(:,k+1)-a(:,k))/h).^2)*h;
    weight = weight+h;
end
value = NaN;
if weight>0, value = sqrt(sumSquares/weight); end
end

function latency = rematchTime(t,relativeVx,startTime,tolerance,hold)
% First time after STARTTIME from which |v_r| <= TOLERANCE holds for HOLD s.
latency = NaN;
matched = abs(relativeVx)<=tolerance;
for k = find(t>=startTime-1e-9)
    if ~matched(k), continue; end
    stop = find(t>=t(k)+hold-1e-9,1,'first');
    if isempty(stop), return; end
    if all(matched(k:stop))
        latency = max(0,t(k)-startTime);
        return;
    end
end
end

function latency = settleTime(t,err,origin,searchStart,tolerance,hold)
% First time t_r >= SEARCHSTART from which |err| <= TOLERANCE holds for HOLD s
% (or until the episode ends); returns t_r - ORIGIN, NaN if it never settles.
latency = NaN;
inside = abs(err)<=tolerance;
for k = find(t>=searchStart-1e-9)
    if ~inside(k), continue; end
    stop = find(t>=t(k)+hold-1e-9,1,'first');
    if isempty(stop), stop = numel(t); end
    if all(inside(k:stop))
        latency = t(k)-origin;
        return;
    end
end
end

function label = failureClass(reason,contactLimitRatio,finalAim,finalViewLoss,lostMarker, ...
    tolerance,viewLossFraction)
% Rules and order of landing2d.evaluation.failureClasses. CONTACTLIMITRATIO =
% contact ratios [x, v_r, v_z, pitch, pitch rate] against the touchdown limits.
switch reason
    case "SUCCESS"
        label = "SUCCESS";
    case {"MISSED_PAD_CONTACT","UNSAFE_CONTACT","UNAUTHORIZED_CONTACT"}
        if contactLimitRatio(1)>1
            label = "LARGE_TOUCHDOWN_POSITION_ERROR";
        elseif contactLimitRatio(2)>1
            label = "HIGH_TOUCHDOWN_RELATIVE_SPEED";
        elseif contactLimitRatio(3)>1
            label = "HIGH_TOUCHDOWN_VERTICAL_SPEED";
        elseif any(contactLimitRatio(4:5)>1)
            label = "UNSAFE_TOUCHDOWN_ATTITUDE";
        else
            label = "OTHER_FAILURE";
        end
    case "TASK_TIMEOUT"
        if lostMarker
            label = "REACQUISITION_FAILURE";
        elseif finalViewLoss>=viewLossFraction
            label = "FOV_LOSS";
        elseif finalAim>tolerance
            label = "TIMEOUT_TRACKING";
        else
            label = "TIMEOUT_HOVERING";
        end
    otherwise
        label = "OTHER_FAILURE";
end
end

function r = contactRatios(result,c)
% Pre-impact contact state against the mechanical touchdown limits (>1 = exceeded).
r = NaN(1,5);
if ~isfield(result,'contact') || ~isstruct(result.contact) ...
        || ~isfield(result.contact,'xError')
    return;
end
s = c.experiment.safety; p = result.contact;
r = [abs(p.xError)/c.padHalfLength,abs(p.relativeVx)/s.touchdownSpeedX, ...
    abs(p.relativeVz)/s.touchdownSpeedZ,abs(p.pitch)/s.touchdownPitchTolerance, ...
    abs(p.pitchRate)/s.touchdownPitchRateTolerance];
end
