function [figures, cfg] = replot_results(matFile, options)
% REPLOT_RESULTS  저장된 결과를 다시 계산하지 않고 새 배경 스타일로 그리기.
%
%   replot_results;
%   replot_results('results/simulation_results.mat',struct('segmentAlpha',0.22));
%   replot_results('이전결과/simulation_results.mat',struct('outputDir','새그림'));
%
% 원래 단일 파일 버전의 MAT도 읽음. 물리/제어/속도 옵션은 변경할 수 없음.
projectRoot = setup_project();
if nargin < 1 || isempty(matFile)
    matFile = fullfile(projectRoot,'results','simulation_results.mat');
end
if nargin < 2, options = struct(); end
if ~isfile(matFile)
    error('landing2d:MissingResults','Result MAT file not found: %s',char(matFile));
end
if ~(isstruct(options) && isscalar(options))
    error('landing2d:InvalidOptions','options must be a scalar struct.');
end
allowed = {'segmentColors','segmentAlpha','showSegmentLabels','showEventLines', ...
    'makeDetailPlots','makeTrajectoryPlots','trajectoryFlightOnly','figureVisible', ...
    'figureResolution','saveResults','saveFig','outputDir', ...
    'showOntologyTab','ontologyViewSource'};
keys = fieldnames(options);
for i = 1:numel(keys)
    if ~ismember(keys{i},allowed)
        error('landing2d:ReplotOption','Only plotting options can be changed: %s',keys{i});
    end
end
saved = load(matFile,'results','cfg');
if ~isfield(saved,'results') || ~isfield(saved,'cfg')
    error('landing2d:InvalidResults','MAT file must contain results and cfg.');
end
cfg = landing2d.config.defaultConfig(projectRoot);
% 이전 버전에는 새 표시 옵션이 없으므로 기본값 위에 저장 설정을 적용.
cfg = landing2d.config.applyOptions(cfg,saved.cfg);
[folder,~,~] = fileparts(char(matFile));
if isempty(folder), folder = pwd; end
cfg.outputDir = folder;
cfg.animate = false;
cfg.makeFinalPlots = true;
cfg = landing2d.config.applyOptions(cfg,options);
landing2d.config.validateConfig(cfg);
figures = landing2d.viz.plotFinalResults(saved.results,cfg);
end
