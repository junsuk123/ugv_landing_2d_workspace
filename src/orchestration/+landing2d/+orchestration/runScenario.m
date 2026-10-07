function output = runScenario(scenarioId,options)
% RUNSCENARIO  Minimal final-checkpoint comparison for one fixed scenario.
% backend='simulink'은 같은 시나리오를 Simulink 모델(RL Agent 블록)에서 돌리고,
% figureVisible이 참이면 모델과 Scope를 엽니다. checkpointDir로 Simulink 학습
% 체크포인트(results/simulink)를 지정할 수 있습니다.
if nargin < 2, options=struct(); end
supplied=options;
root=landing2d.orchestration.projectRoot();
defaults=struct('figureVisible',true,'saveResults',false, ...
    'profileRepetitions',100,'backend','matlab', ...
    'checkpointDir',fullfile(root,'results'),'spatialDimension',2);
options=parseOptions(options,defaults);
assert(isscalar(options.spatialDimension) && ismember(options.spatialDimension,[2,3]), ...
    'landing2d:SpatialDimension','spatialDimension must be 2 or 3.');
resultsRoot=fullfile(root,'results');
if options.spatialDimension==3
    % 3차원 체크포인트·그림은 results/spatial3d 아래에서 읽고 씁니다.
    assert(strcmp(options.backend,'matlab'),'landing2d:SpatialBackend', ...
        'spatialDimension=3 supports backend=''matlab'' only.');
    resultsRoot=fullfile(resultsRoot, ...
        landing2d.config.defaultSpatialConfig().outputSubdir);
    if ~isfield(supplied,'checkpointDir'), options.checkpointDir=resultsRoot; end
end
scenarioId=upper(string(scenarioId));
assert(isscalar(scenarioId) && ismember(scenarioId,["S1","S2","S3"]), ...
    'landing2d:ScenarioId','scenarioId must be S1, S2, or S3.');
if strcmp(options.backend,'simulink')
    % checkpointDir를 주지 않으면 Simulink 학습 결과(results/simulink)를 우선합니다.
    simulinkOptions=struct('open',options.figureVisible);
    if isfield(supplied,'checkpointDir')
        simulinkOptions.checkpointDir=options.checkpointDir;
    end
    output=landing2d.simulink.runScenario(char(scenarioId),simulinkOptions);
    return;
end
outputDir=fullfile(resultsRoot,'scenario');
studyOptions=struct('checkpointDir',options.checkpointDir, ...
    'spatialDimension',options.spatialDimension, ...
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
options.backend=char(options.backend);
assert(ismember(options.backend,{'matlab','simulink'}), ...
    'landing2d:ScenarioBackend','backend must be matlab or simulink.');
options.checkpointDir=char(options.checkpointDir);
end
