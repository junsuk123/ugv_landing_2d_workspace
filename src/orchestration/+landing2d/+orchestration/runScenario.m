function output = runScenario(caseId,options,cfg)
% RUNSCENARIO  Fly one controlled factorial case (S1-S4) with trained checkpoints.
%   output = landing2d.orchestration.runScenario('S4')
%   output = landing2d.orchestration.runScenario('S4',struct('trainSeeds',1:5,'replicates',5))
% options.trainSeeds  checkpoints to load (default 1, a quick look)
% options.replicates  noise replicates (default 1)
% options.methods     registry ids (default all)
% options.visible     show the figure (default true)
% options.trace       true: decision-trace dashboard of the trained TOSM R-GAT
%                     Actor instead (landing2d.orchestration.runTrace; its
%                     options trainSeed, replicate, live, speed, staged, png,
%                     video, mock, outputDir pass through)
% options.replay      a saved trace file: replay it (no simulation, no policy)
% A look at trajectories only; the study numbers come from run.
if nargin < 1 || isempty(caseId), caseId = 'S4'; end
if nargin < 2, options = struct(); end
if nargin>=3 && ismember(cfg.graphState.encoderVersion,{'rgat_minimal_v1','rgat_minimal_v2','rgat_minimal_v3'})
    assert(~isfield(options,'trace') && ~isfield(options,'replay'), ...
        'landing2d:MinimalTrace','The archived trace dashboard supports seven-node models only.');
end
if (isfield(options,'trace') && options.trace) || (isfield(options,'replay') && ~isempty(options.replay))
    output = landing2d.orchestration.runTrace(caseId,options);
    return;
end
if isfield(options,'trace'), options = rmfield(options,'trace'); end
registry = landing2d.config.methodRegistry();
defaults = struct('trainSeeds',1,'replicates',1,'methods',{{registry.methods.id}}, ...
    'visible',true);
names = fieldnames(defaults);
unknown = setdiff(fieldnames(options),names);
assert(isempty(unknown),'landing2d:UnknownOption','Unknown option: %s',strjoin(unknown,', '));
for i = 1:numel(names)
    if ~isfield(options,names{i}), options.(names{i}) = defaults.(names{i}); end
end
if nargin<3, cfg = landing2d.config.primaryConfig(landing2d.orchestration.projectRoot()); end
specs = landing2d.evaluation.factorialCases(cfg);
if ismember(cfg.graphState.encoderVersion,{'rgat_minimal_v1','rgat_minimal_v2','rgat_minimal_v3'}), specs = landing2d.minimal.cases(cfg); end
caseId = upper(char(caseId));
spec = specs(strcmp({specs.id},caseId));
assert(~isempty(spec),'landing2d:ScenarioId','caseId must be one of %s.',strjoin({specs.id},', '));
runs = landing2d.orchestration.loadRuns(cfg,struct('methods',{cellstr(options.methods)}, ...
    'trainSeeds',options.trainSeeds));
seeds = landing2d.evaluation.replicateSeeds(cfg,cfg.evaluation.factorial.seed,options.replicates);
case1 = struct('scenario',spec.scenario,'sensorEvents',spec.sensorEvents, ...
    'eventWindow',spec.eventWindow,'sensorNoiseScale',[]);
rows = {}; shown = struct('methodId',{},'case',{},'results',{});
for r = 1:numel(runs)
    identity = struct('Case',string(caseId),'Replicate',num2cell(1:numel(seeds)));
    keep = repmat(runs(r).trainSeed==options.trainSeeds(1),1,numel(seeds));
    [rows{end+1},kept] = landing2d.evaluation.rolloutSet(runs(r),runs(r).config,seeds, ...
        repmat(case1,1,numel(seeds)),identity,keep); %#ok<AGROW>
    if any(keep)
        shown(end+1) = struct('methodId',runs(r).id,'case',caseId,'results',{kept}); %#ok<AGROW>
    end
end
episodes = struct2table([rows{:}]);
disp(episodes(:,{'MethodId','TrainSeed','Replicate','FailureClass', ...
    'WindowAimErrorRMS_m','WindowCommandRateRMS_mps3','RecoveryTime_s', ...
    'TrackingReacquisition_s','TouchdownRelativeSpeed_mps'}));
view = struct('cases',spec,'display',shown,'displaySeed',options.trainSeeds(1));
fig = landing2d.viz.plotTrajectories(view,cfg,options.visible);
timeSeries = landing2d.viz.plotCaseTimeSeries(view,cfg,caseId,options.visible);
output = struct('case',spec,'episodes',episodes,'figure',fig,'timeSeries',timeSeries);
end
