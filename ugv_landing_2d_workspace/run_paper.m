function [study,figures] = run_paper(options)
% RUN_PAPER  Validate final A/B/C policies and export manuscript figures.
%
%   run_paper
%   run_paper(struct('figureVisible',false))
%   run_paper(struct('saveFigures',false,'saveResults',false))
%
% Outputs under results/paper:
%   paper_trajectories.*  - three fixed scenario trajectory comparisons
%   paper_stability.*     - six stability/safety metrics
%   paper_feasibility.*   - physical margins and ontology inhibit causes
%   paper_ontology.*      - R-GAT graph/gate traces
%   paper_*.csv/.mat      - numerical data behind every figure
if nargin < 1, options=struct(); end
projectRoot=setup_project();
baseCfg=landing2d.config.primaryConfig(projectRoot);
defaults=struct('checkpointDir',baseCfg.outputDir, ...
    'outputDir',fullfile(baseCfg.outputDir,'paper'), ...
    'saveResults',true,'saveFigures',true,'figureVisible',true, ...
    'exportPdf',true,'resolution',300,'profileRepetitions',50);
options=parseOptions(options,defaults);

validationOptions=struct('checkpointDir',options.checkpointDir, ...
    'outputDir',options.outputDir,'saveResults',options.saveResults, ...
    'profileRepetitions',options.profileRepetitions);
study=run_paper_validation(validationOptions);
plotOptions=struct('figureVisible',options.figureVisible, ...
    'outputDir',options.outputDir,'saveFigures',options.saveFigures, ...
    'exportPdf',options.exportPdf,'resolution',options.resolution);
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
    'Unknown run_paper option: %s',strjoin(unknown,', '));
for i=1:numel(allowed)
    key=allowed{i}; if ~isfield(options,key), options.(key)=defaults.(key); end
end
validateattributes(options.resolution,{'numeric'},{'scalar','positive'});
validateattributes(options.profileRepetitions,{'numeric'}, ...
    {'scalar','integer','positive'});
logicalKeys={'saveResults','saveFigures','figureVisible','exportPdf'};
for i=1:numel(logicalKeys), options.(logicalKeys{i})=logical(options.(logicalKeys{i})); end
end
