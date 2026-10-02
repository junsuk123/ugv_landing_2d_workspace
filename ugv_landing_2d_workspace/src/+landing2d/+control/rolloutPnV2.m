function result = rolloutPnV2(c,seed,options)
% ROLLOUTPNV2  Causal PN/reference-guidance rollout through the V2 environment.
% The controller sees only the same packet available to the learned agents.
if nargin<3, options=struct(); end
if ~isfield(options,'maxDecisions'), options.maxDecisions=Inf; end
[env,~,resetInfo]=landing2d.environment.reset(c,seed);
capacity=min(ceil(env.scenario.deadline/c.experiment.policyDt)+1, ...
    options.maxDecisions);
if ~isfinite(capacity), capacity=ceil(env.scenario.deadline/c.experiment.policyDt)+1; end
log=initializeLog(capacity+1,env); count=0; detections=0;
while ~env.episodeStatus.terminated && count<capacity
    aNorm=pnAction(env,c);
    [env,~,~,~,~,stepInfo]=landing2d.environment.step(env,aNorm);
    count=count+1; detections=detections+double(env.packet.detected);
    log=appendLog(log,count+1,env,stepInfo);
end
if ~env.episodeStatus.terminated && count>=capacity
    env.episodeStatus.truncated=true;
end
n=count+1;
fields=fieldnames(log);
for i=1:numel(fields), log.(fields{i})=log.(fields{i})(1:n); end
result=struct('schemaVersion','pn_rollout_result_v2','seed',seed, ...
    'scenario',env.scenario,'status',env.episodeStatus.terminalReason, ...
    'terminated',env.episodeStatus.terminated,'truncated',env.episodeStatus.truncated, ...
    'return',env.rewardSum,'captureRate',detections/max(count,1), ...
    'time',log.time,'xDrone',log.xDrone,'zDrone',log.zDrone, ...
    'vxDrone',log.vxDrone,'vzDrone',log.vzDrone,'theta',log.theta, ...
    'pitchRate',log.pitchRate,'xPad',log.xPad,'vxPad',log.vxPad, ...
    'visible',logical(log.visible),'supervisor',logical(log.supervisor), ...
    'terminalReason',env.episodeStatus.terminalReason, ...
    'landingTime',terminalTime(env,'SUCCESS'),'failureTime',failureTime(env), ...
    'resetInfo',resetInfo);
end

function aNorm=pnAction(env,c)
p=env.packet; s=env.physicalState;
if ~p.trackInitialized
    requested=[0;landing2d.util.saturate(-1.5*s.vz,c.azMax)];
elseif p.landingInhibited
    ax=p.padAxEstimate+1.35*p.exEstimate+2.1*p.relativeVxEstimate;
    if p.abortRequested
        climbReference=0;
    elseif p.predictedFovMargin<0
        climbReference=c.climbSpeed;
    else
        climbReference=0;
    end
    az=c.pnVerticalGain*(climbReference-s.vz);
    requested=[ax;az];
else
    rangeX=p.exEstimate; rangeZ=-p.h;
    rateX=p.relativeVxEstimate; rateZ=-p.vz;
    range=max(hypot(rangeX,rangeZ),c.pnMinRange);
    losRate=(rangeX*rateZ-rangeZ*rateX)/range^2;
    closingSpeed=-(rangeX*rateX+rangeZ*rateZ)/range;
    losUnit=[rangeX;rangeZ]/range;
    perpendicular=[-losUnit(2);losUnit(1)];
    closingReference=min(c.pnApproachSpeed,c.pnApproachGain*range);
    relativeSpeed=max(hypot(rateX,rateZ),c.pnMinClosing);
    pnRequested=c.pnGain*relativeSpeed*losRate*perpendicular + ...
        c.pnClosingGain*(closingReference-closingSpeed)*losUnit;
    % Speed/position matching supplies the moving-target feed-forward that
    % pure terminal PN lacks at the start of a planar landing engagement.
    ax=p.padAxEstimate+1.35*p.exEstimate+2.1*p.relativeVxEstimate;
    aligned=abs(p.exEstimate)<=0.35 && abs(p.relativeVxEstimate)<=0.40;
    if aligned
        desiredVz=-min(c.pnApproachSpeed,max(0.08,0.55*p.h));
    else
        desiredVz=0;
    end
    az=0.35*pnRequested(2)+2.4*(desiredVz-p.vz);
    requested=[ax;az];
end
aNorm=[requested(1)/c.axMax;requested(2)/c.azMax];
aNorm=min(max(aNorm,-1),1);
end

function log=initializeLog(n,env)
names={'time','xDrone','zDrone','vxDrone','vzDrone','theta','pitchRate', ...
    'xPad','vxPad','visible','supervisor'};
for i=1:numel(names), log.(names{i})=zeros(1,n); end
log=appendLog(log,1,env,struct('supervisorIntervened',false));
end

function log=appendLog(log,k,env,info)
log.time(k)=env.time; log.xDrone(k)=env.physicalState.x;
log.zDrone(k)=env.physicalState.z; log.vxDrone(k)=env.physicalState.vx;
log.vzDrone(k)=env.physicalState.vz; log.theta(k)=env.physicalState.theta;
log.pitchRate(k)=env.physicalState.pitchRate; log.xPad(k)=env.pad.x;
log.vxPad(k)=env.pad.vx; log.visible(k)=env.measurement.detected;
log.supervisor(k)=info.supervisorIntervened;
end

function t=terminalTime(env,reason)
if strcmp(env.episodeStatus.terminalReason,reason), t=env.time; else, t=NaN; end
end

function t=failureTime(env)
if env.episodeStatus.terminated && ~strcmp(env.episodeStatus.terminalReason,'SUCCESS')
    t=env.time;
else
    t=NaN;
end
end
