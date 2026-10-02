function events = sampleEvents(sensor,scenario,rs)
% SAMPLEEVENTS  Exogenous detector/pitch schedule, sampled before policy use.
p=sensor.perturbation;
events=struct('dropoutStart',Inf,'dropoutEnd',-Inf,'dropoutKind','clean', ...
    'pitchStart',Inf,'pitchEnd',-Inf,'pitchRate',0);
u=rand(rs);
if u >= p.cleanProbability
    latest=max(0.5,scenario.deadline-5);
    start=0.5+(latest-0.5)*rand(rs);
    if u < p.cleanProbability+p.shortDropoutProbability
        duration=pick(p.shortDropoutDuration,rs);
        events.dropoutKind='short';
    else
        duration=pick(p.sustainedDropoutDuration,rs);
        events.dropoutKind='sustained';
    end
    events.dropoutStart=start;
    events.dropoutEnd=min(start+duration,scenario.deadline);
end
if rand(rs)<p.pitchEventProbability
    latest=max(0.5,scenario.deadline-1);
    events.pitchStart=0.5+(latest-0.5)*rand(rs);
    events.pitchEnd=min(events.pitchStart+pick(p.pitchDuration,rs),scenario.deadline);
    events.pitchRate=(2*rand(rs)-1)*p.pitchRateAmplitude;
end
end

function x=pick(range,rs)
x=range(1)+(range(2)-range(1))*rand(rs);
end
