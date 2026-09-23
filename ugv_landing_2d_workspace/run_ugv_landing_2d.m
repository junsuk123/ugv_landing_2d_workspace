function [results, summaryTable, cfg] = run_ugv_landing_2d(options)
% RUN_UGV_LANDING_2D  설정 -> 시뮬레이션 -> 요약 -> 저장 -> 최종 시각화.
%
%   [results, summaryTable, cfg] = run_ugv_landing_2d;
%   run_ugv_landing_2d(struct('playbackSpeed',4));
%   run_ugv_landing_2d(struct('animate',false));
%
% 수정 위치: src/+landing2d/+config/defaultConfig.m
% 결과 위치: 프로젝트 루트/results (outputDir로 변경 가능).
if nargin < 1
    options = struct();
end
projectRoot = setup_project();
cfg = landing2d.config.defaultConfig(projectRoot);
cfg = landing2d.config.applyOptions(cfg, options);
landing2d.config.validateConfig(cfg);

results = landing2d.simulation.run(cfg);
summaryTable = landing2d.metrics.makeSummary(results, cfg);
disp(summaryTable);

if cfg.saveResults
    landing2d.io.saveData(results, summaryTable, cfg);
end
if cfg.makeFinalPlots
    landing2d.viz.plotFinalResults(results, cfg);
end
if cfg.saveResults
    fprintf('\n결과 저장 폴더: %s\n', cfg.outputDir);
end
end
