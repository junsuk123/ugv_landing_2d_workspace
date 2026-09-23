function saveData(results,summaryTable,cfg)
% SAVEDATA  MAT와 CSV 저장. 그림 생성 성공 여부와 독립적으로 먼저 저장.
if ~exist(cfg.outputDir,'dir')
    [ok,msg] = mkdir(cfg.outputDir);
    if ~ok, error('landing2d:OutputDirectory','%s',msg); end
end
save(fullfile(cfg.outputDir,'simulation_results.mat'),'results','summaryTable','cfg');
writetable(summaryTable,fullfile(cfg.outputDir,'summary.csv'));
for j = 1:numel(results)
    logTable = landing2d.io.resultToTable(results(j),cfg);
    writetable(logTable,fullfile(cfg.outputDir,sprintf('scenario_%d_log.csv',j)));
end
end
