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
put(1,max(abs(crossTrack),abs(h)),crossTrack,h,visionUpdated,visionAge);
put(2,abs(closureError),closureError,rvx,visionUpdated,visionAge);
put(3,abs(ugvVx),ugvVx,0,visionUpdated,visionAge);
put(4,abs(vz),vz,h,navValid,navAge);
put(5,max(abs(st),abs(rate)),st,rate,navValid,navAge);
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
