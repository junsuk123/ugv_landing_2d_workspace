function [env,observation,info] = reset(c,seed,options)
% RESET  Create independent scenario/sensor streams and a causal first packet.
if nargin < 2 || isempty(seed), seed = 1; end
if nargin < 3, options = struct(); end
assert(isfield(c,'experiment') && c.experiment.enabled, ...
    'landing2d:ExperimentVersion','reset requires planar_visibility_v2.');
base = c.experiment.scenario.baseSeed+double(seed);
scenarioSeed = base+c.experiment.randomStreams.scenarioOffset;
sensorSeed = base+c.experiment.randomStreams.sensorOffset;
scenarioConfig = c.experiment.scenario;
if isfield(options,'scenarioHeightRange') && ~isempty(options.scenarioHeightRange)
    validateattributes(options.scenarioHeightRange,{'numeric'}, ...
        {'vector','numel',2,'positive','finite'});
    assert(options.scenarioHeightRange(1)<=options.scenarioHeightRange(2), ...
        'landing2d:ScenarioHeightRange','scenarioHeightRange must increase.');
    scenarioConfig.heightRange = double(options.scenarioHeightRange(:)');
end
scenario = landing2d.scenario.sampleParameters(scenarioConfig,scenarioSeed);
if isfield(options,'scenario'), scenario = options.scenario; end
c.experiment.currentScenario = scenario;
sensorStream = RandStream('threefry','Seed',sensorSeed);
sensorEvents = landing2d.sensing.sampleEvents(c.experiment.sensor,scenario,sensorStream);
if isfield(options,'sensorEvents') && ~isempty(options.sensorEvents)
    sensorEvents = validateSensorEvents(options.sensorEvents,scenario.deadline);
end
[padX,padVx,padAx,phase] = landing2d.scenario.evaluateTrajectory(scenario,0);
pad = struct('x',padX,'z',scenario.padHeight,'vx',padVx,'ax',padAx, ...
    'phase',phase);
% Start in the first constant-velocity engagement with matched horizontal
% speed. Starting the pad at up to 2.5 m/s while the drone was stationary
% made some low-altitude cases lose a body-fixed camera target before any
% causal controller could respond; the experiment is about the later CA
% maneuver, not an artificial initial velocity discontinuity.
state = struct('x',scenario.x0,'z',scenario.padHeight+scenario.height, ...
    'vx',padVx,'vz',0,'theta',0,'pitchRate',0, ...
    'collectiveThrust',c.experiment.dynamics.mass* ...
        c.experiment.dynamics.gravity);
if isfield(options,'physicalState'), state = options.physicalState; end
status = landing2d.environment.initialStatus();
track = landing2d.sensing.initialPadTrack(c.experiment.sensor);
measurement = landing2d.sensing.generateMeasurement(state,pad,0, ...
    c.experiment.sensor,sensorStream,struct('dropout',false));
[track,estimatorInfo] = landing2d.sensing.updatePadTrack(track,measurement, ...
    state,0,c.experiment.sensor);
status = landing2d.environment.updateDecisionContext(status,track,0,c);
packet = landing2d.sensing.buildPacket(state,track,measurement,status,scenario,0,c);
observation = landing2d.sensing.normalizePacket(packet,c);
env = struct('schemaVersion','environment_v2','config',c,'scenario',scenario, ...
    'physicalState',state,'observationMemory',track, ...
    'decisionContext',status,'episodeStatus',status,'time',0, ...
    'pad',pad,'measurement',measurement,'packet',packet, ...
    'sensorStream',sensorStream,'sensorEvents',sensorEvents, ...
    'stepCount',0,'rewardSum',0);
info = struct('packet',packet,'measurement',measurement,'pad',pad, ...
    'scenario',scenario,'estimator',estimatorInfo, ...
    'evaluatorMetadata',struct('sensorEvents',sensorEvents), ...
    'provenance',struct('scenarioSeed',scenarioSeed,'sensorSeed',sensorSeed, ...
    'policySeed',base+c.experiment.randomStreams.policyOffset));
end

function events = validateSensorEvents(events,deadline)
required = {'dropoutStart','dropoutEnd','dropoutKind', ...
    'pitchStart','pitchEnd','pitchRate'};
assert(isstruct(events) && isscalar(events) && all(isfield(events,required)), ...
    'landing2d:SensorEvents','A complete scalar sensorEvents struct is required.');
numericFields = {'dropoutStart','dropoutEnd','pitchStart','pitchEnd','pitchRate'};
for i = 1:numel(numericFields)
    value = events.(numericFields{i});
    assert(isnumeric(value) && isscalar(value) && isreal(value) && ~isnan(value), ...
        'landing2d:SensorEvents','sensorEvents.%s must be a real scalar.', ...
        numericFields{i});
end
events.dropoutKind = char(events.dropoutKind);
assert(ismember(events.dropoutKind,{'clean','short','sustained'}), ...
    'landing2d:SensorEvents','Unknown dropout kind %s.',events.dropoutKind);
assert(events.dropoutEnd>=events.dropoutStart || ...
    (isinf(events.dropoutStart) && isinf(events.dropoutEnd)), ...
    'landing2d:SensorEvents','dropoutEnd must not precede dropoutStart.');
assert(events.pitchEnd>=events.pitchStart || ...
    (isinf(events.pitchStart) && isinf(events.pitchEnd)), ...
    'landing2d:SensorEvents','pitchEnd must not precede pitchStart.');
if isfinite(events.dropoutStart)
    events.dropoutStart=max(0,min(double(events.dropoutStart),deadline));
    events.dropoutEnd=max(events.dropoutStart,min(double(events.dropoutEnd),deadline));
end
if isfinite(events.pitchStart)
    events.pitchStart=max(0,min(double(events.pitchStart),deadline));
    events.pitchEnd=max(events.pitchStart,min(double(events.pitchEnd),deadline));
end
end
