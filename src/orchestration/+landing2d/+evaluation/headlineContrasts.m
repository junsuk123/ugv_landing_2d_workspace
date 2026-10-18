function T = headlineContrasts(results)
% HEADLINECONTRASTS  Seed-paired key contrasts of the study as one table.
%   T = landing2d.evaluation.headlineContrasts(results)
% Quantity, Contrast (A - B), Delta (mean over training seeds), CI (95% t half
% width), Seeds and Positive (seeds with A > B). With one seed CI is NaN.
% The pairs to read together (docs/EXPERIMENT_DESIGN_KO.md, interpretation
% rules): noise sensitivity and trajectory variance only with tracking error,
% recovery time and velocity sensitivity - a policy that ignores its inputs
% is insensitive to noise too.
rows = {};
if isfield(results,'learning')
    rows = [rows,pick(results.learning.contrasts,[],'AUC','learning AUC (higher = faster)')];
end
if isfield(results,'heldout')
    C = results.heldout.contrasts; key = C.Cell=="all";
    rows = [rows,pick(C,key,'Success','held-out success (all cells)'), ...
        pick(C,key,'AimErrorRMS_m','held-out aim-error RMS [m] (lower = better)'), ...
        pick(C,key,'RecoveryTime_s','held-out recovery after UGV acceleration [s] (CA episodes)'), ...
        pick(C,key,'TrackingReacquisition_s','held-out tracking reacquisition after dropout [s]'), ...
        pick(C,key,'TouchdownRelativeSpeed_mps','held-out touchdown |v_r| [m/s] (contacts)'), ...
        pick(C,key,'CommandRateRMS_mps3','held-out command-rate RMS [m/s^3]')];
end
if isfield(results,'factorial')
    F = results.factorial;
    if isfield(F,'caseContrasts')
        rows = [rows,pick(F.caseContrasts,F.caseContrasts.Case=="S4",'WindowAimErrorRMS_m', ...
            'S4 window aim-error RMS [m] (motion + dropout)')];
    end
    if isfield(F,'dispersionContrasts')
        rows = [rows,pick(F.dispersionContrasts,F.dispersionContrasts.Case=="S2", ...
            'TrajectoryVariance_m2','S2 noise-induced trajectory variance [m^2] (secondary)')];
    end
    C = F.effectContrasts; key = C.Effect=="Interaction";
    rows = [rows,pick(C,key,'WindowAimErrorRMS_m','factorial interaction, window aim error [m]'), ...
        pick(C,key,'WindowCommandRateRMS_mps3','factorial interaction, window command rate')];
    key = C.Effect=="Dropout|CA";
    rows = [rows,pick(C,key,'WindowCommandRateRMS_mps3','dropout effect under CA, command rate')];
end
if isfield(results,'generalization')
    C = results.generalization.contrasts; key = C.Condition=="combined";
    rows = [rows,pick(C,key,'Success','generalization success (combined OOD)')];
end
if isfield(results,'probes')
    if isfield(results.probes,'noiseContrasts')
        rows = [rows,pick(results.probes.noiseContrasts,[],'NoiseActionVar', ...
            'open-loop noise sensitivity tr Cov[a] [(m/s^2)^2]')];
    end
    rows = [rows,pick(results.probes.velocityContrasts,[],'SensitivityX', ...
        'open-loop velocity sensitivity da_x/dv_r [1/s]'), ...
        pick(results.probes.updateContrasts,[],'AbsDeltaAx', ...
        'open-loop |response to stale update| a_x [m/s^2]')];
end
T = vertcat(rows{:});
end

function rows = pick(C,key,metric,label)
rows = {};
if isempty(C) || ~ismember(['Delta_',metric],C.Properties.VariableNames), return; end
if ~isempty(key), C = C(key,:); end
for i = 1:height(C)
    rows{end+1} = table(string(label),C.Contrast(i),C.(['Delta_',metric])(i), ...
        C.(['Delta_',metric,'_ci'])(i),C.(['Delta_',metric,'_n'])(i), ...
        C.(['Delta_',metric,'_positive'])(i),'VariableNames', ...
        {'Quantity','Contrast','Delta','CI','Seeds','Positive'}); %#ok<AGROW>
end
end
