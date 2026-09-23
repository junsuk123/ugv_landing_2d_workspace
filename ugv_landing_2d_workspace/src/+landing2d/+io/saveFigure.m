function saveFigure(fig,layout,c,baseName)
% SAVEFIGURE  PNG와 선택적 FIG 저장. 원본 data 파일은 건드리지 않음.
if ~exist(c.outputDir,'dir')
    [ok,msg] = mkdir(c.outputDir);
    if ~ok, error('landing2d:OutputDirectory','%s',msg); end
end
drawnow;
exportgraphics(layout,fullfile(c.outputDir,[baseName,'.png']), ...
    'Resolution',c.figureResolution,'BackgroundColor','white');
if c.saveFig
    savefig(fig,fullfile(c.outputDir,[baseName,'.fig']));
end
end
