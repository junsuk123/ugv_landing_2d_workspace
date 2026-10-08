function record = recordReference(c,seed,options)
% RECORDREFERENCE  고정 probe 기준 궤적 하나: 인과적 구동기로 실제 평면 환경을 비행해 기록.
% 비교군 정책은 이 궤적에 관여하지 않으며, 각 정책의 행동을 이후 관측에 넣지 않습니다.
% 궤적은 명목 잡음 배율 1로 비행하고, 측정 잡음은 기록하지 않고 시간 기준 잡음표를
% 시드에서 다시 만듭니다(landing2d.sensing.exogenousNoise).
% 기록 (결정 시점 k = 0..n, 열 k+1):
%   time                     결정 시각 [s]
%   state                    물리 참값 [x; z; vx; vz; theta; pitchRate; collectiveThrust]
%   pad                      패드 참값 [x; z; vx; ax]
%   frameDropout             결정 시점 영상의 검출기 dropout (환경 step과 같은 규칙)
%   frameCaptured            사용할 영상 결과 여부 (종료 사건 시점은 false)
%   observation              환경이 실제로 만든 정책 관측 벡터 (재생 일치 검사용)
%   landingInhibited, abortRequested, finalDescentActive   환경 결정 문맥 (재생 일치 검사용)
%   driverAction             구동기 정규화 행동 (열 k+1 = 결정 k의 행동, k = 0..n-1)
%   driverMeanAction         같은 관측에서 잡음 없는 구동기 행동 (판정기 기준용, 평가 전용)
% OPTIONS: driverNoise, randomOffset (구동기 잡음 난수열), maxDecisions.
if nargin < 3, options = struct(); end
probe = c.consistency.probe;
defaults = struct('driverNoise',probe.driverNoise,'randomOffset',probe.randomOffset, ...
    'maxDecisions',Inf);
names = fieldnames(options);
for i = 1:numel(names), defaults.(names{i}) = options.(names{i}); end
options = defaults;
[env,observation] = landing2d.environment.reset(c,seed);
assert(~isempty(env.commonObservation),'landing2d:ProbePlanarOnly', ...
    'Fixed probes require the planar common observation.');
manifest = landing2d.environment.exogenousManifest(env);
base = c.experiment.scenario.baseSeed+double(seed);
rs = RandStream('threefry','Seed',base+options.randomOffset);
capacity = min(ceil(env.scenario.deadline/c.experiment.policyDt)+1,options.maxDecisions);
D = numel(observation);
time = zeros(1,capacity+1); state = zeros(7,capacity+1); pad = zeros(4,capacity+1);
frameDropout = false(1,capacity+1); frameCaptured = true(1,capacity+1);
observations = zeros(D,capacity+1); driverAction = zeros(2,capacity);
driverMeanAction = zeros(2,capacity);
inhibited = false(1,capacity+1); abort = false(1,capacity+1); finalDescent = false(1,capacity+1);
[time(1),state(:,1),pad(:,1),inhibited(1),abort(1),finalDescent(1)] = snapshot(env);
observations(:,1) = observation;
k = 0; terminated = false;
while ~terminated && k < capacity
    a = landing2d.probe.referenceDriver(env.commonObservation,env.observationContext, ...
        c,rs,options.driverNoise);
    driverMeanAction(:,k+1) = landing2d.probe.referenceDriver(env.commonObservation, ...
        env.observationContext,c,[],0);
    [env,observation,~,terminated,~,info] = landing2d.environment.step(env,a);
    k = k+1;
    driverAction(:,k) = a;
    [time(k+1),state(:,k+1),pad(:,k+1),inhibited(k+1),abort(k+1),finalDescent(k+1)] = snapshot(env);
    frameDropout(k+1) = env.time >= env.sensorEvents.dropoutStart ...
        && env.time < env.sensorEvents.dropoutEnd;
    frameCaptured(k+1) = ~info.event.occurred;
    observations(:,k+1) = observation;
end
keep = 1:k+1;
record = struct('schemaVersion','probe_reference_v1','seed',seed,'base',base, ...
    'driver',probe.driver,'driverNoise',options.driverNoise, ...
    'driverSeed',base+options.randomOffset,'scenario',env.scenario, ...
    'sensorEvents',env.sensorEvents,'manifest',manifest, ...
    'decisions',k,'terminalReason',env.episodeStatus.terminalReason, ...
    'terminated',env.episodeStatus.terminated, ...
    'time',time(keep),'state',state(:,keep),'pad',pad(:,keep), ...
    'frameDropout',frameDropout(keep),'frameCaptured',frameCaptured(keep), ...
    'observation',observations(:,keep),'landingInhibited',inhibited(keep), ...
    'abortRequested',abort(keep),'finalDescentActive',finalDescent(keep), ...
    'driverAction',driverAction(:,1:k),'driverMeanAction',driverMeanAction(:,1:k));
end

function [t,state,pad,inhibited,abort,finalDescent] = snapshot(env)
s = env.physicalState; p = env.pad; status = env.episodeStatus;
t = env.time;
state = [s.x;s.z;s.vx;s.vz;s.theta;s.pitchRate;s.collectiveThrust];
pad = [p.x;p.z;p.vx;p.ax];
inhibited = status.landingInhibited;
abort = status.abortRequested;
finalDescent = isfield(status,'finalDescentActive') && status.finalDescentActive;
end
