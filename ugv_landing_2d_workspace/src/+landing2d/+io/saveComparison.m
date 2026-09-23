function saveComparison(runs,summaryTable,cfg,baseName)
% SAVECOMPARISON  비교 결과 MAT/CSV 저장. 제어기별 시간 로그를 따로 남깁니다.
if nargin < 4 || isempty(baseName)
    baseName = 'rl_comparison';
end
if ~exist(cfg.outputDir,'dir')
    [ok,message] = mkdir(cfg.outputDir);
    if ~ok, error('landing2d:OutputDirectory','%s',message); end
end
save(fullfile(cfg.outputDir,[baseName,'.mat']),'runs','summaryTable','cfg');
writetable(summaryTable,fullfile(cfg.outputDir,[baseName,'_summary.csv']));
for i = 1:numel(runs)
    tag = lower(regexprep(runs(i).label,'[^A-Za-z0-9]+','_'));
    for j = 1:numel(runs(i).results)
        logTable = landing2d.io.resultToTable(runs(i).results(j),cfg);
        writetable(logTable,fullfile(cfg.outputDir, ...
            sprintf('scenario_%d_%s_log.csv',j,tag)));
    end
end
end
