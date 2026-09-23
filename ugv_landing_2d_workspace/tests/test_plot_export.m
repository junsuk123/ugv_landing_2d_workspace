function test_plot_export()
% TEST_PLOT_EXPORT  짧은 계산으로 탭 요약 그림과 상세 그림 저장까지 검증.
folder = tempname; mkdir(folder);
cleanup = onCleanup(@()removeTemp(folder)); %#ok<NASGU>
c = landing2d.config.defaultConfig();
c = landing2d.config.applyOptions(c,struct('tEnd',2,'segmentTimes',[0.5,1], ...
    'scenarioSpeeds',[1,4,1.5],'animate',false,'figureVisible',false, ...
    'saveResults',true,'saveFig',true,'makeDetailPlots',true,'outputDir',folder));
r = landing2d.simulation.run(c);
figs = landing2d.viz.plotFinalResults(r,c);
closer = onCleanup(@()close(figs)); %#ok<NASGU>
% 기본 출력: 시나리오마다 탭 하나(그래프 두 개) + 창 전체 FIG 하나.
assert(isfile(fullfile(folder,'scenario_1_summary.png')));
assert(isfile(fullfile(folder,'summary_tabs.fig')));
assert(isfile(fullfile(folder,'scenario_1_position_velocity.png')));
assert(isfile(fullfile(folder,'scenario_1_position_velocity.fig')));
assert(isfile(fullfile(folder,'scenario_1_trajectory_xz.png')));
assert(isfile(fullfile(folder,'scenario_1_trajectory_xz.fig')));

% 두 제어기 비교 그림도 같은 탭 구조로 그려져야 함.
runs = struct('results',{r,r},'label',{'PD','PPO RL'});
compareFolder = fullfile(folder,'compare');
cCompare = landing2d.config.applyOptions(c,struct('outputDir',compareFolder));
compareFig = landing2d.viz.plotRunSummary(runs,cCompare, ...
    'scenario_%d_pd_vs_rl','pd_vs_rl_tabs','compare');
closer2 = onCleanup(@()close(compareFig)); %#ok<NASGU>
assert(isfile(fullfile(compareFolder,'scenario_1_pd_vs_rl.png')));
assert(isfile(fullfile(compareFolder,'pd_vs_rl_tabs.fig')));

% 이전 단일 파일 MAT 형식: 새 옵션/segmentId가 없어도 재시각화 가능해야 함.
results = rmfield(r,'segmentId');
cfg = rmfield(c,{'makeDetailPlots','makeTrajectoryPlots','trajectoryFlightOnly', ...
    'segmentColors','segmentAlpha','showSegmentLabels','showEventLines', ...
    'figureVisible','figureResolution','saveFig','rl'});
matFile = fullfile(folder,'legacy_results.mat');
save(matFile,'results','cfg');
replotFolder = fullfile(folder,'replot');
newFigs = replot_results(matFile,struct('figureVisible',false, ...
    'saveResults',true,'saveFig',false,'outputDir',replotFolder));
closer3 = onCleanup(@()close(newFigs)); %#ok<NASGU>
assert(isfile(fullfile(replotFolder,'scenario_1_summary.png')));
end

function removeTemp(folder)
if exist(folder,'dir'), rmdir(folder,'s'); end
end
