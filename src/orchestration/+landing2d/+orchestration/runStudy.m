function [study,figures] = runStudy(options)
% RUNSTUDY  Validate final A/B/C policies and export the selected figures.
%
% Internal use by runPipeline and runScenario.
%
% Outputs under results/paper:
%   paper_trajectories.*  - three fixed scenario trajectory comparisons
%   paper_stability.*     - six stability/safety metrics
%   paper_feasibility.*   - physical margins and ontology inhibit causes
%   paper_ontology.*      - R-GAT graph/gate traces
%   paper_*.csv/.mat      - numerical data behind every figure
if nargin < 1, options=struct(); end
projectRoot=landing2d.orchestration.projectRoot();
baseCfg=landing2d.config.primaryConfig(projectRoot);
dimension=2;
if isstruct(options) && isfield(options,'spatialDimension')
    dimension=options.spatialDimension;
end
baseCfg=landing2d.config.applySpatialDimension(baseCfg,dimension);
defaults=struct('checkpointDir',baseCfg.outputDir,'spatialDimension',2, ...
    'outputDir',fullfile(baseCfg.outputDir,'paper'), ...
    'saveResults',true,'saveFigures',true,'figureVisible',true, ...
    'exportPdf',false,'resolution',300,'profileRepetitions',500, ...
    'scenarioIds',{{}}, ...
    'figureSet',{{'trajectories','stability','feasibility','ontology'}});
options=parseOptions(options,defaults);

validationOptions=struct('checkpointDir',options.checkpointDir, ...
    'outputDir',options.outputDir,'saveResults',options.saveResults, ...
    'profileRepetitions',options.profileRepetitions, ...
    'scenarioIds',{options.scenarioIds}, ...
    'spatialDimension',options.spatialDimension);
study=landing2d.orchestration.validateStudy(validationOptions);
plotOptions=struct('figureVisible',options.figureVisible, ...
    'outputDir',options.outputDir,'saveFigures',options.saveFigures, ...
    'exportPdf',options.exportPdf,'resolution',options.resolution, ...
    'figureSet',{options.figureSet});
figures=landing2d.paper.plotStudy(study,plotOptions);

fprintf('\nPaper evaluation complete.\n');
disp(study.scenarioTable(:,{'Scenario','PeakPadSpeed_mps', ...
    'SpeedMargin_mps','AccelerationMargin_mps2','PhysicalFeasible', ...
    'PhysicalCause'}));
disp(study.metricTable(:,{'Scenario','Method','TerminalReason', ...
    'StabilityIndex','LandingInhibit_pct','DominantInhibitCause'}));
if options.saveResults || options.saveFigures
    fprintf('Paper outputs: %s\n',char(options.outputDir));
end
end

function options=parseOptions(options,defaults)
assert(isstruct(options) && isscalar(options), ...
    'landing2d:InvalidOptions','options must be a scalar struct.');
allowed=fieldnames(defaults); supplied=fieldnames(options);
unknown=setdiff(supplied,allowed);
assert(isempty(unknown),'landing2d:UnknownOption', ...
    'Unknown study option: %s',strjoin(unknown,', '));
for i=1:numel(allowed)
    key=allowed{i}; if ~isfield(options,key), options.(key)=defaults.(key); end
end
validateattributes(options.resolution,{'numeric'},{'scalar','positive'});
validateattributes(options.profileRepetitions,{'numeric'}, ...
    {'scalar','integer','positive'});
logicalKeys={'saveResults','saveFigures','figureVisible','exportPdf'};
for i=1:numel(logicalKeys), options.(logicalKeys{i})=logical(options.(logicalKeys{i})); end
end
