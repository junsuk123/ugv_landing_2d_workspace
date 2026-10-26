function S = referenceStates(d)
% REFERENCESTATES Policy-independent states and their observation contrasts.
% The causal reference driver (landing2d.probe.recordReference) flies each
% family; landing2d.probe.replaySensing rebuilds the environment's own sensing
% chain (asserted bit-identical). At every stride-th decision with an
% initialized UGV estimate the same physical state yields:
%   o                  the observation the environment produced
%   ugvPlus/Minus      UGV velocity estimate +/- dv  (o3 and o4 change together)
%   dronePlus/Minus    drone horizontal velocity +/- dv (o3 only, o4 fixed)
%   posPlus/Minus      UGV position estimate +/- dx (o1)
%   noise              other sensor-noise tables through the same chain
%   stale              marker frames of the last staleAge s dropped (fresh states)
% These are physically realizable contrasts; arbitrary single-entry o_t
% perturbations are made later (landing2d.bias_diagnostics.probeResponses).
% The reference driver's requested acceleration for every contrast is kept as
% a scale/sign reference only, not as the optimal action.
q = d.reference; p = d.perturbation; sensor = d.c.experiment.sensor;
limits = landing2d.environment.actionLimits(d.c);
rows = {}; blocks = {};
for f = 1:numel(q.families)
    family = q.families{f};
    switch family
        case 'training', cf = d.c;
        case 'motion_v2', cf = landing2d.bias_diagnostics.condition(d,d.c,'motion','OOD');
        otherwise, error('landing2d:BiasDiagnosticsFamily','Unknown family %s.',family);
    end
    for seed = q.seeds
        record = landing2d.probe.recordReference(cf,seed);
        rep = landing2d.probe.replaySensing(record,cf,1);
        assert(isequal(rep.observation,record.observation),'landing2d:ProbeReplay', ...
            'Nominal sensing replay differs from the environment (%s seed %d).',family,seed);
        G = rep.context;
        noisy = cell(1,q.noiseReplicates);
        for j = 1:q.noiseReplicates
            other = record; other.base = record.base+j*q.noiseSeedStride;
            noisy{j} = landing2d.probe.replaySensing(other,cf,1);
        end
        for k = 1:q.stride:record.decisions
            if ~rep.flags.estimateInitialized(k), continue; end
            O = rep.O{k}; x = record.state(:,k); pad = record.pad(:,k);
            heightAbovePad = x(2)-pad(2);
            projection = landing2d.sensing.projectPad(struct('x',x(1),'z',x(2),'theta',x(5)), ...
                struct('x',pad(1),'z',pad(2)),sensor);
            fovRatio = abs(projection.bearing)/(sensor.fov/2);
            updated = logical(rep.flags.visionUpdated(k));
            block = struct('o',vec(O,G),'ugvPlus',vec(shift(O,'ugvV',p.ugvVelocity),G), ...
                'ugvMinus',vec(shift(O,'ugvV',-p.ugvVelocity),G), ...
                'dronePlus',vec(shift(O,'droneV',p.droneVelocity),G), ...
                'droneMinus',vec(shift(O,'droneV',-p.droneVelocity),G), ...
                'posPlus',vec(shift(O,'ugvX',p.ugvPosition),G), ...
                'posMinus',vec(shift(O,'ugvX',-p.ugvPosition),G), ...
                'noise',zeros(10,q.noiseReplicates),'stale',NaN(10,1));
            for j = 1:q.noiseReplicates
                block.noise(:,j) = landing2d.observation.toVector(noisy{j}.O{k},G);
            end
            hasStale = false;
            if updated && record.time(k)>=q.staleAge+1
                stale = staleReplay(record,cf,k,q.staleAge);
                if stale.flags.estimateInitialized(k) && ~stale.flags.visionUpdated(k)
                    block.stale = landing2d.observation.toVector(stale.O{k},G); hasStale = true;
                end
            end
            reference = @(V)limits(:).*referenceAction(V,O,G,cf);
            rows{end+1} = struct('Family',string(family),'EnvironmentSeed',seed, ...
                'Decision',k-1,'Time',record.time(k),'Height',heightAbovePad, ...
                'Visible',logical(projection.visible),'FovRatio',fovRatio, ...
                'MarkerUpdated',updated,'HasStale',hasStale, ...
                'PadAcceleration',pad(4),'ScenarioA2',record.scenario.a2, ...
                'Class',stateClass(heightAbovePad,projection.visible,fovRatio,updated,d.classes)); %#ok<AGROW>
            block.reference = struct('base',reference(O), ...
                'ugv',(reference(shift(O,'ugvV',p.ugvVelocity))-reference(shift(O,'ugvV',-p.ugvVelocity)))/(2*p.ugvVelocity), ...
                'drone',(reference(shift(O,'droneV',p.droneVelocity))-reference(shift(O,'droneV',-p.droneVelocity)))/(2*p.droneVelocity), ...
                'pos',(reference(shift(O,'ugvX',p.ugvPosition))-reference(shift(O,'ugvX',-p.ugvPosition)))/(2*p.ugvPosition));
            if hasStale
                block.reference.stale = reference(stale.O{k})-reference(O);
            else
                block.reference.stale = NaN(2,1);
            end
            blocks{end+1} = block; %#ok<AGROW>
        end
    end
end
states = struct2table([rows{:}]);
B = [blocks{:}];
n = height(states);
S = struct('states',states,'o',[B.o],'ugvPlus',[B.ugvPlus],'ugvMinus',[B.ugvMinus], ...
    'dronePlus',[B.dronePlus],'droneMinus',[B.droneMinus],'posPlus',[B.posPlus], ...
    'posMinus',[B.posMinus],'noise',reshape([B.noise],10,q.noiseReplicates,n), ...
    'stale',[B.stale],'reference',[B.reference]);
training = states.Family=="training";
S.inputScale = std(S.o(:,training),0,2);   % typical o_t variation (training family)
S.meta = struct('seeds',q.seeds,'stride',q.stride,'families',{q.families}, ...
    'noiseReplicates',q.noiseReplicates,'noiseSeedStride',q.noiseSeedStride, ...
    'staleAge',q.staleAge,'perturbation',p,'classes',d.classes, ...
    'driver',d.c.evaluation.probe.driver);
end

function o = vec(O,G)
o = landing2d.observation.toVector(O,G);
end

function O = shift(O,what,delta)
switch what
    case 'ugvV', O.ugv.velocityXZ(1) = O.ugv.velocityXZ(1)+delta;
    case 'droneV', O.drone.velocityXZ(1) = O.drone.velocityXZ(1)+delta;
    case 'ugvX', O.ugv.positionXZ(1) = O.ugv.positionXZ(1)+delta;
end
end

function a = referenceAction(V,~,G,c)
a = landing2d.probe.referenceDriver(V,G,c,[],0);
a = a(:);
end

function label = stateClass(heightAbovePad,visible,fovRatio,updated,classes)
if heightAbovePad<classes.nearContactHeight
    label = "nearContact";
elseif ~visible
    label = "outOfView";
elseif fovRatio>=classes.fovBoundaryFraction
    label = "fovBoundary";
elseif updated
    label = "freshUpdate";
else
    label = "staleEstimate";
end
end

function rep = staleReplay(record,c,k,age)
% Same as landing2d.evaluation.buildProbeSet: replay 1..k with the frames of
% [t_k - age, t_k] dropped (the estimator predicts instead of updating).
keep = 1:k; r = record;
for name = {'time','frameDropout','frameCaptured','observation','landingInhibited', ...
        'abortRequested','finalDescentActive'}
    r.(name{1}) = record.(name{1})(:,keep);
end
r.state = record.state(:,keep); r.pad = record.pad(:,keep);
t = r.time;
r.frameDropout = r.frameDropout | (t>=t(k)-age-1e-9 & t<=t(k)+1e-9);
rep = landing2d.probe.replaySensing(r,c,1);
end
