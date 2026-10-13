function [S,detail] = observationVectorGraph(v,G,c)
% OBSERVATIONVECTORGRAPH Build the planar graph from an existing 12-D vector.
% This is the runtime path: environment.step already returns v, so graph
% policies need not vectorize the same common-observation structure twice.
version = c.graphState.observationFeatures;
assert(strcmp(version,'minimal_sensor_v1'), ...
    'landing2d:GraphObservationFeatures','Unknown planar graph feature version.');
vs = landing2d.observation.vectorSchema(G);
v = v(:);
assert(numel(v)==vs.dimension && all(isfinite(v)), ...
    'landing2d:GraphObservation','The graph needs the registered observation vector.');
[schema,~] = landing2d.graphstate.contextSchema( ...
    c.graphState.stateRepresentation,2,'commonObservation');
get = @(name)v(strcmp(vs.names,name));

ex = get('relative_x'); h = get('relative_height');
rvx = get('relative_vx'); ugvVx = get('ugv_vx');
vz = get('drone_vz'); st = get('drone_sinTheta');
ct = get('drone_cosTheta'); rate = get('drone_pitchRate');
visionUpdated = get('ugv_visionUpdated'); visionAge = get('ugv_visionAge');
navValid = get('drone_navigationValid'); navAge = get('drone_navigationAge');
aimSlope = tan(-c.experiment.sensor.cameraPitchOffset);
crossTrack = ex-aimSlope*h;
closureError = rvx-aimSlope*vz;
N=schema.nNodes; X=zeros(schema.inDim,N);
% Physical nodes contain physical evidence only. Reliability appears once in
% the dedicated quality nodes and reaches the state nodes through the typed
% `conditions` edges; repeating validity/age in every physical node made the
% readout unnecessarily sensitive to the same quality scalar several times.
% Smooth squared energy replaces abs/max magnitude channels. The physical
% evidence is continuously reliability-weighted by the registered normalized
% measurement age. This is estimator-style confidence weighting, not a
% control guard: it changes no action, reward, termination, or policy branch.
ageWeight=c.graphState.reliabilityAgeWeight;
visionConfidence=max(0,1-ageWeight*visionAge);
navigationConfidence=max(0,1-ageWeight*navAge);
put(1,visionConfidence*0.5*(crossTrack^2+h^2), ...
    visionConfidence*crossTrack,visionConfidence*h,0,0);
put(2,visionConfidence*0.5*(closureError^2+rvx^2), ...
    visionConfidence*closureError,visionConfidence*rvx,0,0);
put(3,visionConfidence*ugvVx^2,visionConfidence*ugvVx,0,0,0);
put(4,navigationConfidence*vz^2,navigationConfidence*vz,0,0,0);
put(5,navigationConfidence*0.5*(st^2+rate^2), ...
    navigationConfidence*st,navigationConfidence*rate,0,0);
put(6,visionUpdated,1-visionAge,ct,1,visionAge);
put(7,navValid,1-navAge,0,1,navAge);
X=min(max(X,-1),1);
S=X(:);
if nargout>1
    detail=struct('X',X,'schema',schema,'observationVector',v, ...
        'featureVersion',version);
end

    function put(node,primary,signedValue,secondary,validity,age)
        X(:,node)=[primary;signedValue;secondary;validity;age;node/N];
    end
end
