function figures = plotFinalResults(results,c)
% PLOTFINALRESULTS  최종 시각화 진입점. 시뮬레이션과 독립적으로 실행 가능.
% 기본 출력은 시나리오별 탭 하나에 상대거리 그래프와 x-z 궤적 그래프 두 개입니다.
% makeDetailPlots=true이면 위치/속도 4패널과 단독 궤적 그림을 추가로 만듭니다.
figures = gobjects(0,1);
runs = struct('results',{results},'label','Guidance');
figures(end+1,1) = landing2d.viz.plotRunSummary(runs,c, ...
    'scenario_%d_summary','summary_tabs','Landing summary');
if ~isfield(c,'makeDetailPlots') || ~c.makeDetailPlots
    return;
end
for j = 1:numel(results)
    [fig,layout] = landing2d.viz.createPositionVelocityFigure(results(j),c);
    figures(end+1,1) = fig; %#ok<AGROW>
    if c.saveResults
        landing2d.io.saveFigure(fig,layout,c,sprintf('scenario_%d_position_velocity',j));
    end
    if c.makeTrajectoryPlots
        [fig,layout] = landing2d.viz.createTrajectoryFigure(results(j),c);
        figures(end+1,1) = fig; %#ok<AGROW>
        if c.saveResults
            landing2d.io.saveFigure(fig,layout,c,sprintf('scenario_%d_trajectory_xz',j));
        end
    end
end
end
