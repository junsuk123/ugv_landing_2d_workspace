function saveTabbedFigure(fig,tabs,layouts,c,tabNames,figName)
% SAVETABBEDFIGURE  탭마다 PNG 하나, 창 전체에 FIG 하나를 저장.
% 선택되지 않은 탭은 비어 있게 그려질 수 있으므로 탭을 차례로 선택한 뒤 내보냅니다.
if ~exist(c.outputDir,'dir')
    [ok,msg] = mkdir(c.outputDir);
    if ~ok, error('landing2d:OutputDirectory','%s',msg); end
end
group = tabs(1).Parent;
previous = group.SelectedTab;
for j = 1:numel(tabs)
    group.SelectedTab = tabs(j);
    drawnow;
    exportgraphics(layouts(j),fullfile(c.outputDir,[tabNames{j},'.png']), ...
        'Resolution',c.figureResolution,'BackgroundColor','white');
end
group.SelectedTab = previous;
drawnow;
if c.saveFig
    savefig(fig,fullfile(c.outputDir,[figName,'.fig']));
end
end
