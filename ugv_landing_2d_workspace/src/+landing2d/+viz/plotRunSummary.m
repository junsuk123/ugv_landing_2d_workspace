function [fig,tabs,layouts] = plotRunSummary(runs,c,tabBaseName,figBaseName,figureName)
% PLOTRUNSUMMARY  탭 요약 그림 생성과 저장을 한 곳에서 처리.
% tabBaseName은 시나리오 번호를 받는 sprintf 형식, figBaseName은 FIG 파일 이름입니다.
[fig,tabs,layouts] = landing2d.viz.createSummaryTabs(runs,c,figureName);
if c.saveResults
    names = cell(numel(tabs),1);
    for j = 1:numel(tabs)
        names{j} = sprintf(tabBaseName,j);
    end
    landing2d.io.saveTabbedFigure(fig,tabs,layouts,c,names,figBaseName);
end
end
