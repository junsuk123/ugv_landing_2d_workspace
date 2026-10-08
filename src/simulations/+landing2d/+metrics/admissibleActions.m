function adm = admissibleActions(probe,config,horizons,kappas)
% ADMISSIBLEACTIONS  Physically admissible action set of one probe (evaluation only).
% A grid of constant commands over the full action box (config.gridPoints per
% axis) is held from the probe's true state for each horizon in HORIZONS [s]
% (landing2d.metrics.predictFixedCommand, landing2d.metrics.commandMargins).
%   safe        contact >= 0 and braking >= 0
%   FOV rule    keep the pad in the camera FOV when eligible (recent vision, pad
%               in view, above the final-descent exit height) and some safe
%               grid command keeps it
%   task rules  (landing2d.metrics.taskRules) a command may not regress the
%               horizontal tracking quantity or, when landing is authorized, the
%               height above the pad by more than KAPPA times the spread that the
%               safe grid commands achieve from the same state:
%               q(a) <= min_safe q + kappa*(max_safe q - min_safe q)
% The result is a set of commands, not one correct command, and no direction
% (climb, descend, accelerate) is imposed independently of the state.
if nargin < 3 || isempty(horizons), horizons = config.horizon; end
if nargin < 4 || isempty(kappas), kappas = config.kappa; end
c = config.c;
limits = landing2d.environment.actionLimits(c);
n = config.gridPoints;
[gx,gz] = meshgrid(linspace(-1,1,n),linspace(-1,1,n));
grid = [gx(:)';gz(:)'].*limits(:);
steps = max(1,round(horizons/c.experiment.physicsDt));
state = landing2d.metrics.probeState(probe);
pad = landing2d.metrics.probePad(probe);
status = landing2d.metrics.probeStatus(probe);
rules = landing2d.metrics.taskRules(probe,c);
nH = numel(horizons); nG = size(grid,2); nK = numel(kappas);
safe = false(nH,nG); fovOk = false(nH,nG);
qh = NaN(nH,nG); qv = NaN(nH,nG);
for g = 1:nG
    trace = landing2d.metrics.predictFixedCommand(state,pad,grid(:,g),max(steps),status,c);
    for k = 1:nH
        m = landing2d.metrics.commandMargins(trace,steps(k),c);
        safe(k,g) = m.contact >= 0 && m.braking >= 0;
        fovOk(k,g) = m.fov >= 0;
        qh(k,g) = m.(rules.horizontalMetric);
        qv(k,g) = m.height;
    end
end
eligible = landing2d.metrics.fovRuleEligible(probe,c);
fovActive = eligible & any(safe & fovOk,2)';
base = safe & (fovOk | ~fovActive(:));
hBest = NaN(1,nH); hSpread = NaN(1,nH); vBest = NaN(1,nH); vSpread = NaN(1,nH);
admissibleFraction = zeros(nH,nK);
for k = 1:nH
    if any(base(k,:))
        hBest(k) = min(qh(k,base(k,:))); hSpread(k) = max(qh(k,base(k,:)))-hBest(k);
        vBest(k) = min(qv(k,base(k,:))); vSpread(k) = max(qv(k,base(k,:)))-vBest(k);
    end
    for j = 1:nK
        ok = base(k,:);
        if rules.horizontalActive
            ok = ok & qh(k,:) <= hBest(k)+kappas(j)*hSpread(k)+1e-9;
        end
        if rules.verticalActive
            ok = ok & qv(k,:) <= vBest(k)+kappas(j)*vSpread(k)+1e-9;
        end
        admissibleFraction(k,j) = mean(ok);
    end
end
adm = struct('horizons',horizons(:)','kappas',kappas(:)','grid',grid,'safe',safe, ...
    'fovOk',fovOk,'fovEligible',eligible,'fovActive',fovActive, ...
    'anySafe',any(safe,2)','rules',rules,'horizontalBest',hBest, ...
    'horizontalSpread',hSpread,'verticalBest',vBest,'verticalSpread',vSpread, ...
    'admissibleFraction',admissibleFraction);
end
