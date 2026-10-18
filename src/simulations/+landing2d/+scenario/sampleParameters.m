function p = sampleParameters(scenario,seed)
% SAMPLEPARAMETERS  Reproducible CV / CV-CA-CV pad scenario and initial relative motion.
% Motion factor: with scenario.constantVelocityProbability the UGV keeps v1
% for the whole episode (a2 = 0); otherwise it accelerates by a2 during
% [T1, T1+T2). T1 and T2 are drawn in both cases so the random-number use does
% not depend on the factor. Initial relative motion: dv (drone speed minus
% UGV speed, 0 unless mismatched) and dx (offset of the start position from
% the camera-aim point, applied and FOV-checked in landing2d.environment.reset).
% v3 and segment lengths are derived; infeasible draws are rejected.
if isa(seed,'RandStream')
    rs = seed;
else
    rs = RandStream('threefry','Seed',double(seed));
end
for attempt = 1:scenario.maxRejections
    p.v1 = pick(scenario.v1Range,rs);
    constantVelocity = rand(rs) < scenario.constantVelocityProbability;
    a2 = pick(scenario.a2Range,rs);
    p.a2 = a2*~constantVelocity;
    p.T1 = pick(scenario.T1Range,rs);
    p.T2 = pick(scenario.T2Range,rs);
    p.T3 = pick(scenario.T3Range,rs);
    p.v3 = p.v1+p.a2*p.T2;
    p.L1 = p.v1*p.T1;
    p.L2 = p.v1*p.T2+0.5*p.a2*p.T2^2;
    p.L3 = p.v3*p.T3;
    p.height = pick(scenario.heightRange,rs);
    mismatch = rand(rs) < scenario.initialSpeedMismatchProbability;
    p.initialSpeedOffset = pick(scenario.initialSpeedOffsetRange,rs)*mismatch;
    p.initialPositionOffset = pick(scenario.initialPositionOffsetRange,rs);
    p.x0 = scenario.x0;
    p.padHeight = scenario.padHeight;
    p.deadline = p.T1+p.T2+p.T3;
    p.parameterization = 'duration';
    p.seed = seedValue(seed);
    p.attempt = attempt;
    p.feasibleSpeed = p.v3 <= scenario.sustainedDroneSpeed-scenario.speedMargin;
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
