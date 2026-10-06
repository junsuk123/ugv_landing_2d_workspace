function study = validateStudy(options)
% VALIDATESTUDY  Reproduce fixed scenarios with final policies.
%
% This function performs evaluation only.  It never trains or selects a
% checkpoint, and every method receives the same scenario, sensor schedule,
% and sensor-noise seed.  runStudy calls it before creating figures.
if nargin < 1, options = struct(); end
projectRoot = landing2d.orchestration.projectRoot();
cfg = landing2d.config.primaryConfig(projectRoot);
defaults = struct('checkpointDir',cfg.outputDir, ...
    'outputDir',fullfile(cfg.outputDir,'paper'),'saveResults',true, ...
    'profileRepetitions',500,'scenarioIds',{{}});
options = parseOptions(options,defaults);
cfg.outputDir = char(options.checkpointDir);

modes = {'baseline','context_flat','context_rgat'};
labels = {'Low-level MLP PPO','Semantic-flat MLP PPO','Ontology R-GAT PPO'};
agents = cell(1,numel(modes));
armConfigs = cell(1,numel(modes));
checkpointFiles = strings(numel(modes),1);
profiles = cell(1,numel(modes));
fingerprints = strings(numel(modes),1);
architectureRows = cell(numel(modes),1);
for m = 1:numel(modes)
    arm = landing2d.graphstate.applyStateRepresentation(cfg,modes{m});
    arm.graphState.stateRepresentation = modes{m};
    arm.rl.policyFile = sprintf('ppo_%s_planar_visibility_v2.mat',modes{m});
    [agents{m},~,file] = landing2d.rl.loadCheckpoint(arm);
    armConfigs{m} = arm;
    checkpointFiles(m) = string(file);
    profiles{m} = landing2d.rl.profileAgent(agents{m},arm,1, ...
        options.profileRepetitions);
    fingerprints(m) = string(landing2d.environment.taskFingerprint(arm));
    architectureRows{m} = architectureAudit(agents{m},labels{m},modes{m});
end
assert(all(fingerprints==fingerprints(1)), ...
    'landing2d:PaperTaskMismatch','Paper comparison arms do not share one task.');

specs = landing2d.paper.representativeScenarios(cfg);
if ~isempty(options.scenarioIds)
    requested=string(options.scenarioIds);
    keep=ismember(string({specs.id}),requested);
    assert(any(keep),'landing2d:ScenarioId', ...
        'scenarioIds must contain S1, S2, or S3.');
    specs=specs(keep);
end
nScenario = numel(specs); nMethod = numel(modes);
results = cell(nScenario,nMethod); trajectories = cell(nScenario,nMethod);
metricRows = cell(nScenario*nMethod,1);
scenarioRows = cell(nScenario,1);
row = 0;
fprintf('\nFixed paper validation: %d scenarios x %d final policies\n', ...
    nScenario,nMethod);
for s = 1:nScenario
    scenarioRows{s} = landing2d.paper.scenarioFeasibility(specs(s),cfg);
    fprintf('  %s: %s\n',specs(s).id,specs(s).challenge);
    for m = 1:nMethod
        rolloutOptions = struct('deterministic',true, ...
            'scenario',specs(s).scenario, ...
            'sensorEvents',specs(s).sensorEvents);
        [results{s,m},trajectories{s,m}] = landing2d.rl.rolloutEpisodeV2( ...
            agents{m},armConfigs{m},specs(s).seed,rolloutOptions);
        row = row+1;
        metricRows{row} = landing2d.paper.trajectoryMetrics( ...
            results{s,m},trajectories{s,m},specs(s),cfg,labels{m},modes{m});
        fprintf('    %-23s %-26s  SI %5.1f  inhibit %5.1f%%\n', ...
            labels{m},results{s,m}.terminalReason, ...
            metricRows{row}.StabilityIndex,metricRows{row}.LandingInhibit_pct);
    end
end

metricTable = struct2table(vertcat(metricRows{:}));
scenarioTable = struct2table(vertcat(scenarioRows{:}));
profileTable = table(string(labels(:)),string(modes(:)), ...
    cellfun(@(x)x.parameterCount,profiles(:)), ...
    cellfun(@(x)x.policyInferenceMs,profiles(:)), ...
    cellfun(@(x)x.totalInferenceMs,profiles(:)), ...
    'VariableNames',{'Method','StateRepresentation','ParameterCount', ...
    'PolicyInference_ms','ActorCriticTotal_ms'});
architectureTable = struct2table(vertcat(architectureRows{:}));
rgatAudit = architectureTable(architectureTable.StateRepresentation=="context_rgat",:);
if ~isempty(rgatAudit) && ~rgatAudit.RelationalPathActive
    warning('landing2d:InactiveRelationalCheckpoint', ...
        ['The selected context_rgat checkpoint has a zero relational readout. ' ...
         'It is a valid selected policy, but its actions are currently produced ' ...
         'by the raw semantic path; do not claim an active R-GAT contribution.']);
end
study = struct('schemaVersion','paper_validation_v1', ...
    'generatedAt',datetime('now'),'config',cfg,'modes',{modes}, ...
    'labels',{labels},'agents',{agents},'armConfigs',{armConfigs}, ...
    'checkpointFiles',checkpointFiles,'profiles',profileTable, ...
    'architectureAudit',architectureTable, ...
    'taskFingerprint',fingerprints(1),'scenarios',specs, ...
    'results',{results},'trajectories',{trajectories}, ...
    'scenarioTable',scenarioTable,'metricTable',metricTable);

if options.saveResults
    outputDir = char(options.outputDir);
    if ~exist(outputDir,'dir'), mkdir(outputDir); end
    writetable(scenarioTable,fullfile(outputDir,'paper_scenario_feasibility.csv'));
    writetable(metricTable,fullfile(outputDir,'paper_stability_metrics.csv'));
    writetable(profileTable,fullfile(outputDir,'paper_runtime_profile.csv'));
    writetable(architectureTable,fullfile(outputDir,'paper_architecture_audit.csv'));
    savedStudy = rmfield(study,{'agents','armConfigs'}); %#ok<NASGU>
    save(fullfile(outputDir,'paper_validation.mat'),'savedStudy');
end

function audit=architectureAudit(agent,label,mode)
policyReadout=parameterNorm(agent.policy.encoder,'Wg');
valueReadout=parameterNorm(agent.value.encoder,'Wg');
policyRelation=0; valueRelation=0;
if isfield(agent.policy,'relation'), policyRelation=norm(agent.policy.relation.W,'fro'); end
if isfield(agent.value,'relation'), valueRelation=norm(agent.value.relation.W,'fro'); end
requiresRelation=strcmp(mode,'context_rgat');
active=~requiresRelation || (policyReadout>1e-10 && valueReadout>1e-10 && ...
    policyRelation>1e-10 && valueRelation>1e-10);
audit=struct('Method',string(label),'StateRepresentation',string(mode), ...
    'RequiresRelationalPath',requiresRelation, ...
    'PolicyGraphReadoutNorm',policyReadout, ...
    'ValueGraphReadoutNorm',valueReadout, ...
    'PolicyRelationHeadNorm',policyRelation, ...
    'ValueRelationHeadNorm',valueRelation, ...
    'RelationalPathActive',active);
end

function value=parameterNorm(parameters,name)
if isfield(parameters,name), value=norm(parameters.(name),'fro'); else, value=NaN; end
end
end

function options = parseOptions(options,defaults)
assert(isstruct(options) && isscalar(options), ...
    'landing2d:InvalidOptions','options must be a scalar struct.');
allowed = fieldnames(defaults); supplied = fieldnames(options);
unknown = setdiff(supplied,allowed);
assert(isempty(unknown),'landing2d:UnknownOption', ...
    'Unknown paper validation option: %s',strjoin(unknown,', '));
for i = 1:numel(allowed)
    key = allowed{i};
    if ~isfield(options,key), options.(key)=defaults.(key); end
end
validateattributes(options.profileRepetitions,{'numeric'}, ...
    {'scalar','integer','positive'});
assert(iscell(options.scenarioIds) || isstring(options.scenarioIds) ...
    || ischar(options.scenarioIds),'landing2d:ScenarioIds', ...
    'scenarioIds must be text or a cell array of text.');
if ischar(options.scenarioIds), options.scenarioIds={options.scenarioIds}; end
options.saveResults = logical(options.saveResults);
end
