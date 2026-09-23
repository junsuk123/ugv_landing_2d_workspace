function prepareAxes(ax)
% PREPAREAXES  최종 그래프 공통 표시. 전역 그래픽 기본값은 변경하지 않음.
set(ax,'FontName','Arial','FontSize',10,'LineWidth',0.8, ...
    'Color','w','XColor',[0.15,0.15,0.15],'YColor',[0.15,0.15,0.15], ...
    'GridAlpha',0.16,'Layer','top','Box','on');
ax.Title.Color = [0.12,0.12,0.12];
ax.XLabel.Color = [0.15,0.15,0.15];
ax.YLabel.Color = [0.15,0.15,0.15];
grid(ax,'on');
hold(ax,'on');
end
