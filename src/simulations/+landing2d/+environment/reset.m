function [env,observation,info] = reset(c,seed,options)
% RESET  Create independent scenario/sensor streams and a causal first packet.
% Planar contract: sensor noise comes from a time-indexed table drawn here
% (landing2d.sensing.exogenousNoise), so its value at a given time is the same
% for every policy. options.sensorNoiseScale (default 1, planar only) scales
% every sensor-noise standard deviation (evaluation of observation errors).
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
spatial = landing2d.environment.isSpatial(c);
if spatial, scenario = withLateralMotion(scenario,c.experiment.scenario); end
c.experiment.currentScenario = scenario;
sensorStream = RandStream('threefry','Seed',sensorSeed);
sensorEvents = landing2d.sensing.sampleEvents(c.experiment.sensor,scenario,sensorStream);
if isfield(options,'sensorEvents') && ~isempty(options.sensorEvents)
    sensorEvents = validateSensorEvents(options.sensorEvents,scenario.deadline);
end
pad = landing2d.scenario.padState(scenario,0);
% Start in the first constant-velocity engagement with matched horizontal
% speed. Starting the pad at up to 2.5 m/s while the drone was stationary
% made some low-altitude cases lose a body-fixed camera target before any
% causal controller could respond; the experiment is about the later CA
% maneuver, not an artificial initial velocity discontinuity.
% The drone starts where the pad center lies on the camera optical axis at
% level attitude: x = x_pad + h*tan(cameraPitchOffset). The planar marker
% camera looks 60 deg below forward, so the drone starts behind the pad; the
% downward camera of the 3D option (offset 0) starts directly above it.
startX = pad.x+scenario.height*tan(c.experiment.sensor.cameraPitchOffset);
state = struct('x',startX,'z',scenario.padHeight+scenario.height, ...
    'vx',pad.vx,'vz',0,'theta',0,'pitchRate',0, ...
    'collectiveThrust',c.experiment.dynamics.mass* ...
        c.experiment.dynamics.gravity);
if spatial
    % 3D option: also directly above the pad with matched lateral velocity.
    state.y = pad.y; state.vy = pad.vy; state.roll = 0; state.rollRate = 0;
end
if isfield(options,'physicalState'), state = options.physicalState; end
assert(spatial == isfield(state,'y'),'landing2d:SpatialState', ...
    'physicalState must match the configured spatial dimension.');
status = landing2d.environment.initialStatus( ...
    numel(landing2d.environment.actionLimits(c)));
perception = ~spatial && isfield(c.experiment,'commonObservation');
noiseScale = 1;
if isfield(options,'sensorNoiseScale') && ~isempty(options.sensorNoiseScale)
    noiseScale = options.sensorNoiseScale;
    validateattributes(noiseScale,{'numeric'},{'scalar','real','finite','nonnegative'}, ...
        mfilename,'sensorNoiseScale');
    assert(perception || noiseScale == 1,'landing2d:NoiseScale', ...
        'sensorNoiseScale requires the planar common observation (time-indexed noise).');
end
% Planar contract: tracker, marker and navigation noise all come from the
% time-indexed table (column k+1 = decision k, k = 0 here). The 3D option
% keeps its sequential sensor stream and its numbers.
noise = []; trackerNoise = sensorStream;
if perception
    noise = landing2d.sensing.exogenousNoise(c,base,scenario.deadline,noiseScale);
    trackerNoise = noise.tracker(:,1,1);
end
track = landing2d.sensing.initialPadTrack(c.experiment.sensor,spatial);
measurement = landing2d.sensing.generateMeasurement(state,pad,0, ...
    c.experiment.sensor,trackerNoise,struct('dropout',false));
[track,estimatorInfo] = landing2d.sensing.updatePadTrack(track,measurement, ...
    state,0,c.experiment.sensor);
% Common observation o_t = [G;D;H] and its static context Gamma (planar only).
% The simulated detector and navigation are the only consumers of truth;
% capture receives their outputs. The same marker-camera UGV estimate drives
% landing authorization and the safety supervisor; the 3D option and
% configurations saved without the common observation keep the tracker-based
% decision context.
observationContext = [];
commonMemory = []; commonObservation = []; perceptionError = [];
if perception
    co = c.experiment.commonObservation;
    observationContext = landing2d.observation.staticContext(c);
    detections = landing2d.sensing.detectMarkers(state,pad,0,c.experiment.sensor, ...
        co,noise.marker(:,:,:,1),struct('dropout',false,'frameCaptured',true));
    navigation = landing2d.sensing.navigationEstimate(state,0,co.navigation, ...
        noise.navigation(:,1));
    [commonObservation,commonMemory] = landing2d.observation.capture( ...
        landing2d.observation.initialMemory(),detections,navigation,0,observationContext);
    perceptionError = landing2d.metrics.perceptionError(commonObservation,pad,observationContext);
    [~,perceptionTrack] = landing2d.environment.perceptionView(commonObservation, ...
        state,status,0,scenario,c);
    status = landing2d.environment.updateDecisionContext(status,perceptionTrack,0,c,state);
else
    status = landing2d.environment.updateDecisionContext(status,track,0,c,state);
end
packet = landing2d.sensing.buildPacket(state,track,measurement,status,scenario,0,c);
% Policy observation: the normalized 24-D common observation in the planar
% contract; the normalized causal packet otherwise (3D option, old configs).
if isempty(commonObservation)
    observation = landing2d.sensing.normalizePacket(packet,c);
else
    observation = landing2d.observation.toVector(commonObservation,observationContext);
end
provenance = struct('scenarioSeed',scenarioSeed,'sensorSeed',sensorSeed, ...
    'policySeed',base+c.experiment.randomStreams.policyOffset,'seed',double(seed), ...
    'noiseIndexing','sequential','noiseScale',noiseScale, ...
    'trackerNoiseSeed',sensorSeed,'markerNoiseSeed',NaN,'navigationNoiseSeed',NaN);
if perception
    provenance.noiseIndexing = noise.indexing;
    provenance.trackerNoiseSeed = noise.seeds.tracker;
    provenance.markerNoiseSeed = noise.seeds.marker;
    provenance.navigationNoiseSeed = noise.seeds.navigation;
end
env = struct('schemaVersion','environment_v2','config',c,'scenario',scenario, ...
    'physicalState',state,'observationMemory',track, ...
    'decisionContext',status,'episodeStatus',status,'time',0, ...
    'pad',pad,'measurement',measurement,'packet',packet, ...
    'sensorStream',sensorStream,'sensorEvents',sensorEvents,'noise',noise, ...
    'observationContext',observationContext, ...
    'commonMemory',commonMemory,'commonObservation',commonObservation, ...
    'initialPhysicalState',state,'provenance',provenance, ...
    'stepCount',0,'rewardSum',0);
info = struct('packet',packet,'commonObservation',commonObservation, ...
    'observationContext',observationContext,'perceptionError',perceptionError, ...
    'measurement',measurement,'pad',pad, ...
    'scenario',scenario,'estimator',estimatorInfo, ...
    'evaluatorMetadata',struct('sensorEvents',sensorEvents), ...
    'provenance',provenance);
end

function scenario = withLateralMotion(scenario,scenarioConfig)
% A supplied planar scenario runs in 3D with zero lateral pad motion.
if ~isfield(scenario,'vy1'), scenario.vy1 = 0; end
if ~isfield(scenario,'ay2'), scenario.ay2 = 0; end
if ~isfield(scenario,'y0'), scenario.y0 = scenarioConfig.y0; end
scenario.vy3 = scenario.vy1+scenario.ay2*scenario.T2;
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
