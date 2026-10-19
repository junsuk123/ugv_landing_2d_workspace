function P = provenanceMap(c,G,O)
% PROVENANCEMAP  Data provenance from the sensing processors to the TOSM node features.
%   P = landing2d.trace.provenanceMap(c,G,O)
% C is the run configuration, G = Gamma (observationContext) and O a real
% common observation of the episode (the perturbation base). Three layers:
%   fieldToChannel  common-observation field -> 12-D o_t entry, found by
%                   perturbing each field of O through landing2d.observation.toVector
%   channelToNode   o_t entry -> node feature, found by perturbing each entry
%                   through landing2d.graphstate.observationVectorGraph
%   staticToNode    public calibration / touchdown / normalization constant ->
%                   node feature, found the same way
% so the connectors drawn between o_t and the nodes are the dependencies of
% the code itself, not a hand-drawn diagram. These are deterministic feature
% derivations, NOT typed R-GAT message-passing edges. The field -> processor
% assignment follows landing2d.observation.capture: every ugv.* field is the
% output of the UGV Kalman filter (fed by PnP on ArUco corners and by the
% navigation pose used to place the camera), every drone.* field is the
% navigation estimate.
vs = landing2d.observation.vectorSchema(G);
observationFields = { ...
    'ugv','positionXZ',1,'UGV 위치 x 추정','kf'; ...
    'ugv','positionXZ',2,'UGV 위치 z 추정','kf'; ...
    'ugv','velocityXZ',1,'UGV 속도 vx 추정','kf'; ...
    'ugv','velocityXZ',2,'UGV 속도 vz 추정','kf'; ...
    'ugv','visionUpdated',1,'KF 측정 갱신 여부','kf'; ...
    'ugv','visionAge',1,'마지막 측정 갱신 후 경과시간','kf'; ...
    'drone','positionXZ',1,'UAV 위치 x','navigation'; ...
    'drone','positionXZ',2,'UAV 위치 z','navigation'; ...
    'drone','velocityXZ',1,'UAV 속도 vx','navigation'; ...
    'drone','velocityXZ',2,'UAV 속도 vz','navigation'; ...
    'drone','pitchSinCos',1,'UAV sinθ','navigation'; ...
    'drone','pitchSinCos',2,'UAV cosθ','navigation'; ...
    'drone','pitchRate',1,'UAV 피치 각속도','navigation'; ...
    'drone','navigationValid',1,'항법 유효','navigation'; ...
    'drone','navigationAge',1,'항법 경과시간','navigation'};
bases = perturbationBases(O,G);
nF = size(observationFields,1); nC = vs.dimension;
fieldToChannel = false(nF,nC);
for b = 1:numel(bases)
    reference = landing2d.observation.toVector(bases{b},G);
    for f = 1:nF
        for direction = [-1,1]
            changed = perturbField(bases{b},observationFields(f,:),direction);
            fieldToChannel(f,:) = fieldToChannel(f,:) | ...
                (abs(landing2d.observation.toVector(changed,G)-reference) > 1e-12)';
        end
    end
end
schema = landing2d.graphstate.contextSchema('context_rgat');
N = schema.nNodes; featureRows = 1:schema.inDim-1;   % typeId is constant
channelToNode = false(nC,N);
staticNames = {'sensor.cameraPitchOffset','sensor.fov', ...
    'safety.touchdownPositionTolerance','safety.touchdownSpeedX', ...
    'safety.touchdownSpeedZ','safety.touchdownPitchTolerance', ...
    'safety.touchdownPitchRateTolerance','normalization.relativePosition', ...
    'normalization.height','normalization.vx','normalization.vz','normalization.pitchRate'};
staticToNode = false(numel(staticNames),N);
for b = 1:numel(bases)
    v = landing2d.observation.toVector(bases{b},G);
    [~,detail] = landing2d.graphstate.observationVectorGraph(v,G,c);
    X0 = detail.X(featureRows,:);
    for k = 1:nC
        for direction = [-1,1]
            w = v; w(k) = w(k)+direction*1e-4*max(1,abs(w(k)));
            [~,d] = landing2d.graphstate.observationVectorGraph(w,G,c);
            channelToNode(k,:) = channelToNode(k,:) | any(abs(d.X(featureRows,:)-X0) > 1e-12,1);
        end
    end
    for s = 1:numel(staticNames)
        [cs,Gs] = perturbStatic(c,G,staticNames{s});
        [~,d] = landing2d.graphstate.observationVectorGraph(v,Gs,cs);
        staticToNode(s,:) = staticToNode(s,:) | any(abs(d.X(featureRows,:)-X0) > 1e-12,1);
    end
end
fieldSource = observationFields(:,5);
processors = {'camera','marker','pnp','kf','navigation'};
channelSource = false(nC,numel(processors));
for k = 1:nC
    channelSource(k,:) = ismember(processors,fieldSource(fieldToChannel(:,k)));
end
% Processor dataflow of landing2d.observation.capture (and the environment's
% decision-time sensing): camera frame -> ArUco detection -> PnP -> KF; the
% navigation pose places the camera for the UGV position measurement
% (ugvPositionMeasurement) and its velocity initializes the KF velocity.
sourceEdges = {'camera','marker','frame'; 'marker','pnp','detections'; ...
    'navigation','pnp','camera pose (W T_B)'; 'pnp','kf','measurement y'; ...
    'navigation','kf','initial velocity'};
P = struct('version','trace_provenance_v1','channelNames',{vs.names}, ...
    'observationFields',{observationFields},'fieldToChannel',fieldToChannel,'channelToNode',channelToNode, ...
    'staticNames',{staticNames},'staticToNode',staticToNode, ...
    'processors',{processors},'channelSource',channelSource, ...
    'sourceEdges',{sourceEdges},'nodeNames',{schema.nodeNames}, ...
    'method',['finite perturbation of landing2d.observation.toVector and ' ...
        'landing2d.graphstate.observationVectorGraph at the episode''s first ' ...
        'observation and three moderate variants']);
end

function bases = perturbationBases(O,G)
% The episode observation plus moderate variants away from saturation, zero
% crossings and the uninitialized-estimate branch of toVector.
base = O;
base.ugv.estimateInitialized = true;
if ~isfinite(base.ugv.visionAge), base.ugv.visionAge = 0.3; end
base.drone.navigationAge = max(base.drone.navigationAge,0.05);
variants = {[-2.0,5.0,1.2,0.6,-0.3,0.12,0.20],[1.5,3.0,0.4,1.1,0.4,-0.08,-0.35], ...
    [-0.8,6.5,0.9,0.2,-0.6,0.05,0.10]};
bases = {base};
for i = 1:numel(variants)
    p = variants{i}; o = base;
    o.ugv.positionXZ = [o.drone.positionXZ(1)+p(1);o.drone.positionXZ(2)-p(2)-G.ugv.padOffset(2)];
    o.ugv.velocityXZ = [p(3);0.01];
    o.drone.velocityXZ = [p(4);p(5)];
    o.drone.pitchSinCos = [sin(p(6));cos(p(6))];
    o.drone.pitchRate = p(7);
    o.ugv.visionAge = 0.2*i; o.drone.navigationAge = 0.05*i;
    bases{end+1} = o; %#ok<AGROW>
end
end

function o = perturbField(o,field,direction)
group = field{1}; name = field{2}; index = field{3};
value = o.(group).(name);
if islogical(value)
    value(index) = ~value(index);
else
    value(index) = value(index)+direction*1e-4*max(1,abs(value(index)));
end
o.(group).(name) = value;
end

function [c,G] = perturbStatic(c,G,name)
parts = strsplit(name,'.');
switch parts{1}
    case 'sensor'
        c.experiment.sensor.(parts{2}) = c.experiment.sensor.(parts{2})*(1+1e-4);
    case 'safety'
        c.experiment.safety.(parts{2}) = c.experiment.safety.(parts{2})*(1+1e-4);
    case 'normalization'
        G.normalization.(parts{2}) = G.normalization.(parts{2})*(1+1e-4);
end
end
