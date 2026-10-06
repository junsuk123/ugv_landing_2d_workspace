function output = runScenario(scenarioId,options)
% RUNSCENARIO  Minimal final-checkpoint comparison for one fixed scenario.
if nargin < 2, options=struct(); end
defaults=struct('figureVisible',true,'saveResults',false, ...
    'profileRepetitions',100);
options=parseOptions(options,defaults);
scenarioId=upper(string(scenarioId));
assert(isscalar(scenarioId) && ismember(scenarioId,["S1","S2","S3"]), ...
    'landing2d:ScenarioId','scenarioId must be S1, S2, or S3.');
root=landing2d.orchestration.projectRoot();
outputDir=fullfile(root,'results','scenario');
studyOptions=struct('checkpointDir',fullfile(root,'results'), ...
    'outputDir',outputDir,'saveResults',options.saveResults, ...
    'saveFigures',options.saveResults,'figureVisible',options.figureVisible, ...
    'exportPdf',false,'profileRepetitions',options.profileRepetitions, ...
    'scenarioIds',{{char(scenarioId)}},'figureSet',{{'trajectories'}});
[study,figures]=landing2d.orchestration.runStudy(studyOptions);
output=struct('scenario',scenarioId,'study',study,'figures',figures);
end

function options=parseOptions(options,defaults)
assert(isstruct(options) && isscalar(options), ...
    'landing2d:InvalidOptions','options must be a scalar struct.');
unknown=setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption', ...
    'Unknown scenario option: %s',strjoin(unknown,', '));
keys=fieldnames(defaults);
for i=1:numel(keys)
    if ~isfield(options,keys{i}), options.(keys{i})=defaults.(keys{i}); end
end
options.figureVisible=logical(options.figureVisible);
options.saveResults=logical(options.saveResults);
end
