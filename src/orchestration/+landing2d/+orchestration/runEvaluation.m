function results = runEvaluation(runs,cfg,options)
% RUNEVALUATION  Every evaluation of relational_policy_v1 on trained runs.
%   results = landing2d.orchestration.runEvaluation(runs,cfg,options)
% options.sections  any of 'learning','training','heldout','factorial',
%                   'generalization','probes' (default all)
% options.outputDir CSV/MAT destination ('' = do not save)
% Sections (docs/EXPERIMENT_DESIGN_KO.md):
%   learning        sample efficiency from the training histories (validation)
%   training        R-GAT gradient flow and parameter change, relation graphs used
%   heldout         test split of the training distribution, per 2 x 2 cell
%   factorial       controlled S1-S4 cases: paired effects and interaction
%   generalization  outside the training ranges (stress split)
%   probes          open-loop same-state responses (velocity / update contrast)
% Every summary is over training seeds (one run = one sample); every contrast
% is seed-paired. Nothing here selects or changes a checkpoint.
available = {'learning','training','heldout','factorial','generalization','probes'};
defaults = struct('sections',{available},'outputDir','');
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(options,names{i}), options.(names{i}) = defaults.(names{i}); end
end
sections = cellstr(options.sections);
assert(all(ismember(sections,available)),'landing2d:EvaluationSection','Unknown evaluation section.');
seeds = unique([runs.trainSeed]);
results = struct('schemaVersion','relational_policy_results_v1', ...
    'generatedAt',datetime('now'),'trainSeeds',seeds, ...
    'methods',{unique({runs.id},'stable')},'runs',runTable(runs), ...
    'taskFingerprint',fingerprint(runs));
if ismember('learning',sections)
    fprintf('\n[evaluate] learning efficiency\n');
    results.learning = landing2d.evaluation.learningEfficiency(runs,cfg);
end
if ismember('training',sections)
    fprintf('\n[evaluate] training diagnostics (gradient flow, parameter change, graphs)\n');
    results.training = landing2d.evaluation.trainingDiagnostics(runs,cfg);
end
if ismember('heldout',sections)
    fprintf('\n[evaluate] held-out test (training distribution)\n');
    results.heldout = landing2d.evaluation.heldOut(runs,cfg);
end
if ismember('factorial',sections)
    fprintf('\n[evaluate] factorial S1-S4\n');
    results.factorial = landing2d.evaluation.factorialStudy(runs,cfg,seeds(1));
end
if ismember('generalization',sections)
    fprintf('\n[evaluate] generalization outside the training ranges\n');
    results.generalization = landing2d.evaluation.generalization(runs,cfg);
end
if ismember('probes',sections)
    fprintf('\n[evaluate] open-loop same-state probes\n');
    results.probes = landing2d.evaluation.openLoopProbes(runs,cfg);
end
if ~isempty(options.outputDir)
    saveResults(results,char(options.outputDir));
end
end

function T = runTable(runs)
rows = arrayfun(@(r)r.identity,runs);
T = struct2table(rows,'AsArray',true);
T.Parameters = arrayfun(@(r)landing2d.rl.profileAgent(r.agent,r.config,1,1).parameterCount,runs)';
end

function f = fingerprint(runs)
prints = arrayfun(@(r)string(landing2d.environment.taskFingerprint(r.config)),runs);
assert(all(prints==prints(1)),'landing2d:TaskFingerprint', ...
    'The compared runs do not share one task contract.');
f = prints(1);
end

function saveResults(results,folder)
if ~exist(folder,'dir'), mkdir(folder); end
writetable(results.runs,fullfile(folder,'runs.csv'));
sections = {'learning','training','heldout','factorial','generalization','probes'};
for i = 1:numel(sections)
    if ~isfield(results,sections{i}), continue; end
    s = results.(sections{i});
    names = fieldnames(s);
    for k = 1:numel(names)
        value = s.(names{k});
        if istable(value) && ~isempty(value)
            writetable(value,fullfile(folder,sprintf('%s_%s.csv',sections{i},names{k})));
        end
    end
end
save(fullfile(folder,'results.mat'),'results','-v7.3');
fprintf('Evaluation tables: %s\n',folder);
end
