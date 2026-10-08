function grid = validityGrid(bank,c,options)
% VALIDITYGRID  Admissible action sets of every probe of a bank (evaluation only).
% For each probe, each candidate horizon and each candidate tolerance kappa
% (c.consistency.validity) the grid of constant commands is predicted once
% (landing2d.metrics.admissibleActions); the result is shared by every method,
% seed and noise scale. Probes whose supervisor overrides the policy (backup
% recovery) are not predicted. OPTIONS.parallel uses parfor when a pool is open.
if nargin < 3, options = struct(); end
v = c.consistency.validity;
horizons = v.horizonCandidates; kappas = v.kappaCandidates;
if isfield(options,'horizons'), horizons = options.horizons; end
if isfield(options,'kappas'), kappas = options.kappas; end
parallel = isfield(options,'parallel') && options.parallel && ~isempty(gcp('nocreate'));
config = struct('c',c,'horizon',horizons(1),'kappa',kappas(1),'gridPoints',v.gridPoints);
P = bank.meta.probeCount; nH = numel(horizons); nK = numel(kappas);
probes = arrayfun(@(p)landing2d.consistency.probeRecord(bank,p),1:P);
results = cell(1,P);
if parallel
    parfor p = 1:P
        results{p} = oneProbe(probes(p),config,horizons,kappas);
    end
else
    for p = 1:P
        results{p} = oneProbe(probes(p),config,horizons,kappas);
    end
end
override = false(1,P); anySafe = false(nH,P); fovActive = false(nH,P);
fovEligible = false(1,P); horizontalActive = false(1,P); verticalActive = false(1,P);
horizontalMetric = repmat({''},1,P);
hBest = NaN(nH,P); hSpread = NaN(nH,P); vBest = NaN(nH,P); vSpread = NaN(nH,P);
admissibleFraction = NaN(nH,nK,P);
for p = 1:P
    r = results{p};
    override(p) = r.override;
    if r.override, continue; end
    a = r.adm;
    anySafe(:,p) = a.anySafe(:); fovActive(:,p) = a.fovActive(:);
    fovEligible(p) = a.fovEligible;
    horizontalActive(p) = a.rules.horizontalActive;
    verticalActive(p) = a.rules.verticalActive;
    horizontalMetric{p} = a.rules.horizontalMetric;
    hBest(:,p) = a.horizontalBest(:); hSpread(:,p) = a.horizontalSpread(:);
    vBest(:,p) = a.verticalBest(:); vSpread(:,p) = a.verticalSpread(:);
    admissibleFraction(:,:,p) = a.admissibleFraction;
end
grid = struct('schemaVersion','validity_grid_v2','split',bank.meta.split, ...
    'bankConfigHash',bank.meta.configHash,'horizons',horizons(:)', ...
    'kappas',kappas(:)','gridPoints',v.gridPoints,'override',override, ...
    'anySafe',anySafe,'fovActive',fovActive,'fovEligible',fovEligible, ...
    'horizontalActive',horizontalActive,'horizontalMetric',{horizontalMetric}, ...
    'verticalActive',verticalActive,'horizontalBest',hBest, ...
    'horizontalSpread',hSpread,'verticalBest',vBest,'verticalSpread',vSpread, ...
    'admissibleFraction',admissibleFraction);
end

function r = oneProbe(probe,config,horizons,kappas)
r = struct('override',logical(probe.context.abortRequested),'adm',[]);
if ~r.override
    r.adm = landing2d.metrics.admissibleActions(probe,config,horizons,kappas);
end
end
