function [fig,tabs,layouts] = plotRunSummary(runs,c,tabBaseName,figBaseName,figureName)
% PLOTRUNSUMMARY  탭 요약 그림 생성과 저장을 한 곳에서 처리.
% tabBaseName은 시나리오 번호를 받는 sprintf 형식, figBaseName은 FIG 파일 이름입니다.
%
% 저장이 끝난 뒤 c.showOntologyTab이 참이면 같은 탭 그룹에 온톨로지 탭 하나를
% 덧붙입니다. 저장 뒤에 붙이므로 시나리오별 PNG와 FIG 내용은 달라지지 않습니다.
[fig,tabs,layouts] = landing2d.viz.createSummaryTabs(runs,c,figureName);
if c.saveResults
    names = cell(numel(tabs),1);
    for j = 1:numel(tabs)
        names{j} = sprintf(tabBaseName,j);
    end
    landing2d.io.saveTabbedFigure(fig,tabs,layouts,c,names,figBaseName);
end
if isfield(c,'showOntologyTab') && c.showOntologyTab
    attachOntologyTab(tabs(1).Parent,c);
end
end

function attachOntologyTab(group,c)
% 시각화 오류가 시뮬레이션이나 학습을 멈추지 않도록 여기에서 격리합니다.
% 실패한 경우에도 결과 그림은 그대로 남습니다.
try
    landing2d.viz.attachOntologyView(group,ontologySource(c));
catch err
    warning('landing2d:OntologyViewFailed', ...
        '온톨로지 탭을 만들지 못했습니다: %s',err.message);
end
end

function source = ontologySource(c)
% 기본 표시 대상은 온톨로지 의미 그래프입니다.
% 학습 입력 그래프는 탭 안의 표시 대상 선택창에서 바꿀 수 있습니다.
source = 'ontology';
if isfield(c,'ontologyViewSource') && ~isempty(c.ontologyViewSource)
    source = c.ontologyViewSource;
end
end
