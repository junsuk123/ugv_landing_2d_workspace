function output = runScenario(caseId,options)
% RUNSCENARIO  Fly one controlled factorial case (S1-S4) with trained checkpoints.
%   output = landing2d.orchestration.runScenario('S4')
%   output = landing2d.orchestration.runScenario('S4',struct('trainSeeds',1:5,'replicates',5))
% options.trainSeeds  checkpoints to load (default 1, a quick look)
% options.replicates  noise replicates (default 1)
% options.methods     registry ids (default all)
% options.visible     show the figure (default true)
% A look at trajectories only; the study numbers come from run.
if nargin < 1 || isempty(caseId), caseId = 'S4'; end
if nargin < 2, options = struct(); end
registry = landing2d.config.methodRegistry();
defaults = struct('trainSeeds',1,'replicates',1,'methods',{{registry.methods.id}}, ...
    'visible',true);
names = fieldnames(defaults);
unknown = setdiff(fieldnames(options),names);
assert(isempty(unknown),'landing2d:UnknownOption','Unknown option: %s',strjoin(unknown,', '));
for i = 1:numel(names)
    if ~isfield(options,names{i}), options.(names{i}) = defaults.(names{i}); end
end
cfg = landing2d.config.primaryConfig(landing2d.orchestration.projectRoot());
specs = landing2d.evaluation.factorialCases(cfg);
caseId = upper(char(caseId));
spec = specs(strcmp({specs.id},caseId));
assert(~isempty(spec),'landing2d:ScenarioId','caseId must be S1, S2, S3 or S4.');
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
