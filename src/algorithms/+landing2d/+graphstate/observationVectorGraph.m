function [S,detail] = observationVectorGraph(v,G,c)
% OBSERVATIONVECTORGRAPH Build the planar graph from an existing 12-D vector.
% This is the runtime path: environment.step already returns v, so graph
% policies need not vectorize the same common-observation structure twice.
% graphState.observationFeatures = 'tosm7_v1' (reduced 7-node TOSM ontology).
version = c.graphState.observationFeatures;
assert(strcmp(version,'tosm7_v1'),'landing2d:GraphObservationFeatures', ...
    'Unknown planar graph feature version.');
vs = landing2d.observation.vectorSchema(G);
v = v(:);
assert(numel(v)==vs.dimension && all(isfinite(v)), ...
    'landing2d:GraphObservation','The graph needs the registered observation vector.');
schema = cachedSchema();
get = @(name)v(strcmp(vs.names,name));
[X,evidence] = tosmFeatures(get,schema,G,c);
X=min(max(X,-1),1);
S=X(:);
if nargout>1
    detail=struct('X',X,'schema',schema,'observationVector',v, ...
        'featureVersion',version,'semanticEvidence',evidence);
end
end

function [X,evidence] = tosmFeatures(get,schema,G,c)
% Reduced TOSM node features. Every value is a deterministic function of the
% registered o_t plus public calibration constants (camera geometry,
% normalization scales, mechanical touchdown limits). Vision quality is
% carried only by VisionQuality and reaches the estimates through the typed
% qualifiesEstimate edges; the estimate nodes are not confidence-weighted,
% so the quality path runs through those typed edges (permuted in the
% shuffled control).
ex = get('relative_x'); h = get('relative_height');
rvx = get('relative_vx'); ugvVx = get('ugv_vx');
vz = get('drone_vz'); st = get('drone_sinTheta');
ct = get('drone_cosTheta'); rate = get('drone_pitchRate');
visionUpdated = get('ugv_visionUpdated'); visionAge = get('ugv_visionAge');
navValid = get('drone_navigationValid'); navAge = get('drone_navigationAge');
aimSlope = tan(-c.experiment.sensor.cameraPitchOffset);
crossTrack = ex-aimSlope*h;
N=schema.nNodes; X=zeros(schema.inDim,N);
put(1,visionUpdated,visionAge,0,0,0);
put(2,ugvVx,ugvVx^2,0,0,0);
put(3,ex,h,crossTrack,0.5*(crossTrack^2+h^2),0);
put(4,rvx,rvx^2,0,0,0);
put(5,vz,st,rate,navValid,navAge);
% ViewMargin: predicted FOV/2-|beta| of the estimated pad in the body-fixed
% camera (same projection as landing2d.sensing.projectPad). It is a
% prediction from the estimate, not a detection result; it is read together
% with VisionQuality through the conditionsLanding relation.
norm = G.normalization;
exM = unscale(ex,norm.relativePosition); hM = unscale(h,norm.height);
theta = atan2(st,ct);
thetaCamera = theta+c.experiment.sensor.cameraPitchOffset;
depth = -exM*sin(thetaCamera)+hM*cos(thetaCamera);
lateral = exM*cos(thetaCamera)+hM*sin(thetaCamera);
halfFov = c.experiment.sensor.fov/2;
if hypot(exM,hM) > eps
    bearing = atan2(lateral,depth);
    fovMargin = (halfFov-abs(bearing))/halfFov;
    bearingNorm = bearing/halfFov;
else
    bearing = 0; fovMargin = 0; bearingNorm = 0;
end
put(6,fovMargin,bearingNorm,0,0,0);
% LandingCondition: current-state touchdown suitability, one ratio per
% mechanical touchdown limit, softly bounded r/(1+r) (0.5 = at the limit).
% It summarizes evidence only; it never approves, blocks or clips an action.
safety = c.experiment.safety;
ratio = [abs(exM)/safety.touchdownPositionTolerance; ...
    abs(unscale(rvx,norm.vx))/safety.touchdownSpeedX; ...
    abs(unscale(vz,norm.vz))/safety.touchdownSpeedZ; ...
    abs(theta)/safety.touchdownPitchTolerance; ...
    abs(unscale(rate,norm.pitchRate))/safety.touchdownPitchRateTolerance];
condition = ratio./(1+ratio);
put(7,condition(1),condition(2),condition(3),condition(4),condition(5));
evidence = struct('crossTrack',crossTrack,'bearing',bearing, ...
    'fovMargin',fovMargin,'landingRatio',ratio', ...
    'landingCondition',condition');

    function put(node,f1,f2,f3,f4,f5)
        X(:,node)=[f1;f2;f3;f4;f5;node/N];
    end
end

function y = unscale(x,scale)
% Inverse of the bounded observation scaling x/(|x|+scale).
x = min(max(x,-(1-1e-6)),1-1e-6);
y = scale*x/(1-abs(x));
end

function schema = cachedSchema()
% The schema is constant; build it once per MATLAB session (and worker).
persistent cached
if isempty(cached), cached = landing2d.graphstate.contextSchema('context_rgat'); end
schema = cached;
end
