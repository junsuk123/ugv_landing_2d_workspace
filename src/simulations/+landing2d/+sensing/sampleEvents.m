function events = sampleEvents(sensor,scenario,rs)
% SAMPLEEVENTS  Exogenous marker-detection schedule, sampled before policy use.
% Observation factor of the training family: clean, or one dropout of class
% 'mild' or 'severe' starting uniformly in perturbation.dropoutStartRange,
% drawn independently of the UGV motion (no coupling to T1). No pitch event.
p = sensor.perturbation;
events = struct('dropoutStart',Inf,'dropoutEnd',-Inf,'dropoutKind','clean', ...
    'pitchStart',Inf,'pitchEnd',-Inf,'pitchRate',0);
u = rand(rs);
if u >= p.cleanProbability
    window = [p.dropoutStartRange(1),min(p.dropoutStartRange(2),scenario.deadline)];
    start = pick(window,rs);
    if u < p.cleanProbability+p.mildDropoutProbability
        duration = pick(p.mildDropoutDuration,rs); events.dropoutKind = 'mild';
    else
        duration = pick(p.severeDropoutDuration,rs); events.dropoutKind = 'severe';
    end
    events.dropoutStart = start;
    events.dropoutEnd = min(start+duration,scenario.deadline);
end
end

function x = pick(range,rs)
x = range(1)+(range(2)-range(1))*rand(rs);
end
