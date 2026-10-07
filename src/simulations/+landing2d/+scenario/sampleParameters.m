function p = sampleParameters(scenario,seed)
% SAMPLEPARAMETERS  Reproducible continuous CV-CA-CV pad scenario.
% Only independent quantities are sampled. v3 and spatial lengths are derived.
if isa(seed,'RandStream')
    rs = seed;
else
    rs = RandStream('threefry','Seed',double(seed));
end
for attempt = 1:scenario.maxRejections
    if strcmp(scenario.parameterization,'duration')
        p.v1 = pick(scenario.v1Range,rs);
        p.a2 = pick(scenario.a2Range,rs);
        p.T1 = pick(scenario.T1Range,rs);
        p.T2 = pick(scenario.T2Range,rs);
        p.T3 = pick(scenario.T3Range,rs);
        p.v3 = p.v1+p.a2*p.T2;
        p.L1 = p.v1*p.T1;
        p.L2 = p.v1*p.T2+0.5*p.a2*p.T2^2;
        p.L3 = p.v3*p.T3;
    elseif strcmp(scenario.parameterization,'distance')
        required = {'L1Range','L2Range','L3Range'};
        assert(all(isfield(scenario,required)), ...
            'landing2d:DistanceScenarioConfig','Distance ranges are required.');
        p.v1 = pick(scenario.v1Range,rs);
        p.a2 = pick(scenario.a2Range,rs);
        p.L1 = pick(scenario.L1Range,rs);
        p.L2 = pick(scenario.L2Range,rs);
        p.L3 = pick(scenario.L3Range,rs);
        p.T1 = p.L1/p.v1;
        p.v3 = sqrt(p.v1^2+2*p.a2*p.L2);
        p.T2 = 2*p.L2/(p.v1+p.v3);
        p.T3 = p.L3/p.v3;
    else
        error('landing2d:ScenarioParameterization', ...
            'Unknown parameterization %s.',scenario.parameterization);
    end
    p.height = pick(scenario.heightRange,rs);
    p.x0 = scenario.x0;
    p.padHeight = scenario.padHeight;
    p.deadline = p.T1+p.T2+p.T3;
    p.parameterization = scenario.parameterization;
    p.seed = seedValue(seed);
    p.attempt = attempt;
    peakSpeed = p.v3;
    if isfield(scenario,'lateralV1Range')
        % 3D option: lateral CV-CA-CV sharing T1/T2. Drawn after every planar
        % quantity so the planar draws keep their order within an attempt.
        p.vy1 = pick(scenario.lateralV1Range,rs);
        p.ay2 = pick(scenario.lateralA2Range,rs);
        p.vy3 = p.vy1+p.ay2*p.T2;
        p.y0 = scenario.y0;
        peakSpeed = hypot(p.v3,p.vy3);
    end
    p.feasibleSpeed = peakSpeed <= scenario.sustainedDroneSpeed-scenario.speedMargin;
    if p.deadline <= 70 && p.feasibleSpeed
        p.rejectionReason = '';
        return;
    end
end
error('landing2d:ScenarioSamplingFailed', ...
    'No feasible scenario after %d attempts.',scenario.maxRejections);
end

function x = pick(range,rs)
x = range(1)+(range(2)-range(1))*rand(rs);
end

function value = seedValue(seed)
if isa(seed,'RandStream')
    value = NaN;
else
    value = double(seed);
end
end
