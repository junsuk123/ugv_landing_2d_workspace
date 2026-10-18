function metric = episodeMetrics(result,traj,c,identity,window)
% EPISODEMETRICS  Evaluation-only metrics of one rollout (relational_policy_v1).
%   metric = landing2d.evaluation.episodeMetrics(result,traj,c,identity,window)
% RESULT/TRAJ from landing2d.rl.rolloutEpisodeV2 (deterministic direct policy).
% IDENTITY is a scalar struct whose fields lead the row. WINDOW = [t0,t1] is
% the event interval of a fixed case (metrics over [t0, t1 + settling)), or []
% for sampled episodes (window metrics NaN). Truth is read only here, after
% the rollout; nothing is fed back to a policy, and no metric uses an ontology
% node, attention or reward term.
%
% Factors     MotionFactor (UGV accelerates), ObservationFactor (exogenous
%             dropout), DropoutKind, InitialSpeedOffset
% Mission     Success, Unsafe, Timeout, Return, LandingTime_s
% Tracking    aim error e_aim = e_x - h tan(camera pitch offset): horizontal
%             error from the camera-aim point the common reward tracks (0 at
%             touchdown); relative speed v_r = v_pad - v_drone
% Command     CommandRateRMS: time-weighted RMS of the requested-command rate
%             over consecutive decisions [m/s^3] (direct policy: requested = applied)
% Events      SpeedRematch_s (|v_r| <= touchdownSpeedX held 1 s after the CA
%             phase), ReacquisitionLatency_s, ExogenousDropout_s, and
%             ApproachViewLoss_s: pad outside the camera view above the
%             readiness height outside any exogenous dropout (policy-induced
%             view loss, recorded separately from the injected dropout)
% Landing     UnsuitableDescent_s: descending below the readiness height while
%             a touchdown limit is exceeded or the remaining height cannot
%             brake to touchdownSpeedZ within azMax; ContactMaxRatio
if nargin < 5, window = []; end
n = traj.count;
assert(n>0,'landing2d:EmptyRollout','Rollout produced no decisions.');
safety = c.experiment.safety;
sensor = c.experiment.sensor;
s = result.scenario;
events = result.resetInfo.evaluatorMetadata.sensorEvents;
t = result.time(1:n);
dt = traj.dt(:)';
endTime = result.time(n+1);
ex = result.xPad(1:n)-result.xDrone(1:n);
height = result.zDrone(1:n)-s.padHeight;
aimError = ex-max(height,0)*tan(sensor.cameraPitchOffset);
relativeVx = result.vxPad(1:n)-result.vxDrone(1:n);
vz = result.vzDrone(1:n);
theta = result.theta(1:n);
pitchRate = result.pitchRate(1:n);
visible = logical(result.visible(1:n));
command = traj.requestedAcceleration;

geometricVisible = false(1,n);
for k = 1:n
    state = struct('x',result.xDrone(k),'z',result.zDrone(k),'theta',theta(k));
    pad = struct('x',result.xPad(k),'z',s.padHeight);
    geometricVisible(k) = landing2d.sensing.projectPad(state,pad,sensor).visible;
end
inDropout = t>=events.dropoutStart & t<events.dropoutEnd;
readiness = c.experiment.reward.readinessHeight;
approach = height>readiness;

windowSeconds = 0; inWindow = false(1,n);
if ~isempty(window)
    span = [max(0,window(1)),min(endTime,window(2)+c.evaluation.settling)];
    inWindow = t>=span(1) & t<span(2);
    windowSeconds = weighted(inWindow,dt);
end

reacquisition = NaN;
if isfinite(events.dropoutEnd)
    index = find(result.time>=events.dropoutEnd & result.visible,1,'first');
    if ~isempty(index), reacquisition = max(0,result.time(index)-events.dropoutEnd); end
end
rematch = NaN;
if s.a2 > 0
    rematch = rematchTime(t,relativeVx,s.T1+s.T2,safety.touchdownSpeedX,1.0);
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
contact = contactRatios(result,c);

reason = string(result.terminalReason);
unsafeReasons = ["UNSAFE_CONTACT","UNAUTHORIZED_CONTACT","MISSED_PAD_CONTACT", ...
    "SAFETY_ENVELOPE_VIOLATION"];
initialSpeedOffset = 0;
if isfield(s,'initialSpeedOffset'), initialSpeedOffset = s.initialSpeedOffset; end
row = struct('MotionFactor',double(s.a2>0), ...
    'ObservationFactor',double(isfinite(events.dropoutStart)), ...
    'DropoutKind',string(events.dropoutKind),'UgvAcceleration',s.a2, ...
    'InitialSpeedOffset',initialSpeedOffset,'InitialHeight',s.height, ...
    'TerminalReason',reason,'Success',double(reason=="SUCCESS"), ...
    'Unsafe',double(ismember(reason,unsafeReasons)),'Timeout',double(reason=="TASK_TIMEOUT"), ...
    'Return',result.return,'LandingTime_s',result.landingTime, ...
    'Duration_s',sum(dt), ...
    'AimErrorRMS_m',rmsOf(aimError,dt),'RelativeSpeedRMS_mps',rmsOf(relativeVx,dt), ...
    'CommandRateRMS_mps3',commandRate(t,command,true(1,n)), ...
    'WindowSeconds',windowSeconds, ...
    'WindowAimErrorRMS_m',windowValue(@()rmsOf(aimError(inWindow),dt(inWindow)),windowSeconds), ...
    'WindowMaxAbsAimError_m',windowValue(@()max(abs(aimError(inWindow))),windowSeconds), ...
    'WindowRelativeSpeedRMS_mps',windowValue(@()rmsOf(relativeVx(inWindow),dt(inWindow)),windowSeconds), ...
    'WindowMaxAbsRelativeSpeed_mps',windowValue(@()max(abs(relativeVx(inWindow))),windowSeconds), ...
    'WindowCommandRateRMS_mps3',windowValue(@()commandRate(t,command,inWindow),windowSeconds), ...
    'SpeedRematch_s',rematch,'ReacquisitionLatency_s',reacquisition, ...
    'ExogenousDropout_s',weighted(inDropout,dt), ...
    'ApproachViewLoss_s',weighted(approach & ~inDropout & ~geometricVisible,dt), ...
    'MeasuredViewLoss_s',weighted(~visible,dt), ...
    'UnsuitableDescent_s',weighted(low & descending & unsuitable,dt), ...
    'ContactMaxRatio',max(contact));
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
