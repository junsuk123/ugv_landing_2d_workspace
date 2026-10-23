function [policyInput,detail] = observationVectorGraph(observationVector,G,c)
% OBSERVATIONVECTORGRAPH Build the planar graph from an existing 10-D vector.
% This is the runtime path: environment.step already returns the vector, so
% graph policies need not vectorize the same common-observation structure twice.
% graphState.observationFeatures = 'tosm7_v4' (reduced 7-node TOSM ontology).
% tosm7_v2 (relational-policy-v2.3) = tosm7_v1 without the features whose
% defect was confirmed by construction: the constant navigation validity/age
% (DroneMotion f4-f5; no longer in o_t) and the normalized cross-track
% c = x~ - m h~ with its quadratic 0.5(c^2 + h~^2) (RelativePosition f3-f4).
% c mixes two differently scaled axes, so it is not the metric aim error
% e_x - m h and is not zero on the aim line. Freed channels stay zero
% padding; nodes, edges and the 6 channels are unchanged.
% tosm7_v3 (relational-policy-v2.13) = tosm7_v2 with a latent readout sink:
% LandingCondition f1-f5 are zero (typeId kept). Its touchdown ratios
% |e_x|, |v_r|, |v_z|, |theta|, |theta_dot| / limit duplicated the evidence of
% RelativePosition, RelativeVelocity and DroneMotion without sign and with
% 5-29 times the o_t gain, and the landing_sink_v1 readout read them without
% any typed edge (docs/RGAT_V2_DESIGN_KO.md section 21). The ratios are still
% returned in semanticEvidence (descriptive, decision trace).
% tosm7_v4 (relational-policy-v2.14) = tosm7_v2 with LandingCondition f1-f5
% the signed o_t entries of the same five touchdown quantities: relative_x,
% relative_vx, drone_vz, drone_sinTheta, drone_pitchRate (gain and sign of
% o_t). The latent sink of tosm7_v3 removed the unsigned high-gain copy but
% also the learnable direct path: neither graph arm learned (section 21.5).
% policyInput is the flattened node-feature matrix X(:) of the R-GAT arms.
version = c.graphState.observationFeatures;
assert(ismember(version,{'tosm7_v2','tosm7_v3','tosm7_v4'}),'landing2d:GraphObservationFeatures', ...
    'Unknown planar graph feature version.');
observationSchema = landing2d.observation.vectorSchema(G);
observationVector = observationVector(:);
assert(numel(observationVector)==observationSchema.dimension && all(isfinite(observationVector)), ...
    'landing2d:GraphObservation','The graph needs the registered observation vector.');
schema = cachedSchema();
observationComponent = @(name)observationVector(strcmp(observationSchema.names,name));
[X,semanticEvidence] = tosmFeatures(observationComponent,schema,G,c);
if strcmp(version,'tosm7_v3')
    X(1:end-1,schema.landingConditionNodes) = 0;
elseif strcmp(version,'tosm7_v4')
    X(1:end-1,schema.landingConditionNodes) = [observationComponent('relative_x'); ...
        observationComponent('relative_vx');observationComponent('drone_vz'); ...
        observationComponent('drone_sinTheta');observationComponent('drone_pitchRate')];
end
X=min(max(X,-1),1);
policyInput=X(:);
if nargout>1
    detail=struct('X',X,'schema',schema,'observationVector',observationVector, ...
        'featureVersion',version,'semanticEvidence',semanticEvidence);
end
end

function [X,semanticEvidence] = tosmFeatures(observationComponent,schema,G,c)
% Reduced TOSM node features. Every value is a deterministic function of the
% registered o_t plus public calibration constants (camera geometry,
% normalization scales, mechanical touchdown limits). Vision quality is
% carried only by VisionQuality and reaches the estimates through the typed
% qualifiesEstimate edges; the estimate nodes are not confidence-weighted,
% so the quality path runs through those typed edges (permuted in the
% shuffled control).
% The o_t entries are normalized (bounded scaling x/(|x|+s), Gamma
% normalization); the *Meters values are their unscaled physical values.
normalizedRelativeX = observationComponent('relative_x');
normalizedHeight = observationComponent('relative_height');
normalizedRelativeVx = observationComponent('relative_vx');
normalizedUgvVx = observationComponent('ugv_vx');
normalizedDroneVz = observationComponent('drone_vz');
sinTheta = observationComponent('drone_sinTheta');
cosTheta = observationComponent('drone_cosTheta');
normalizedPitchRate = observationComponent('drone_pitchRate');
visionUpdated = observationComponent('ugv_visionUpdated'); visionAge = observationComponent('ugv_visionAge');
N=schema.nNodes; X=zeros(schema.inDim,N);
put(1,visionUpdated,visionAge,0,0,0);
put(2,normalizedUgvVx,normalizedUgvVx^2,0,0,0);
put(3,normalizedRelativeX,normalizedHeight,0,0,0);
put(4,normalizedRelativeVx,normalizedRelativeVx^2,0,0,0);
put(5,normalizedDroneVz,sinTheta,normalizedPitchRate,0,0);
% ViewMargin: predicted FOV/2-|beta| of the estimated pad in the body-fixed
% camera (same projection as landing2d.sensing.projectPad). It is a
% prediction from the estimate, not a detection result; it is read together
% with VisionQuality through the conditionsLanding relation.
normalizationScales = G.normalization;
relativeXMeters = unscale(normalizedRelativeX,normalizationScales.relativePosition);
heightMeters = unscale(normalizedHeight,normalizationScales.height);
theta = atan2(sinTheta,cosTheta);
thetaCamera = theta+c.experiment.sensor.cameraPitchOffset;
depth = -relativeXMeters*sin(thetaCamera)+heightMeters*cos(thetaCamera);
lateral = relativeXMeters*cos(thetaCamera)+heightMeters*sin(thetaCamera);
halfFov = c.experiment.sensor.fov/2;
if hypot(relativeXMeters,heightMeters) > eps
    bearing = atan2(lateral,depth);
    fovMargin = (halfFov-abs(bearing))/halfFov;
    normalizedBearing = bearing/halfFov;
else
    bearing = 0; fovMargin = 0; normalizedBearing = 0;
end
put(6,fovMargin,normalizedBearing,0,0,0);
% LandingCondition: current-state touchdown suitability, one ratio per
% mechanical touchdown limit, softly bounded r/(1+r) (0.5 = at the limit).
% It summarizes evidence only; it never approves, blocks or clips an action.
% Node features in tosm7_v2 only (tosm7_v3/v4 keep them as semanticEvidence).
safety = c.experiment.safety;
touchdownLimitRatio = [abs(relativeXMeters)/safety.touchdownPositionTolerance; ...
    abs(unscale(normalizedRelativeVx,normalizationScales.vx))/safety.touchdownSpeedX; ...
    abs(unscale(normalizedDroneVz,normalizationScales.vz))/safety.touchdownSpeedZ; ...
    abs(theta)/safety.touchdownPitchTolerance; ...
    abs(unscale(normalizedPitchRate,normalizationScales.pitchRate))/safety.touchdownPitchRateTolerance];
landingCondition = touchdownLimitRatio./(1+touchdownLimitRatio);
put(7,landingCondition(1),landingCondition(2),landingCondition(3), ...
    landingCondition(4),landingCondition(5));
semanticEvidence = struct('bearing',bearing, ...
    'fovMargin',fovMargin,'touchdownLimitRatio',touchdownLimitRatio', ...
    'landingCondition',landingCondition');

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
