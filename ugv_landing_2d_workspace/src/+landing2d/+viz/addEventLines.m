function addEventLines(ax, r, c)
% ADDEVENTLINES  고도-시간 그래프에만 사건 시각 표시.
if ~c.showEventLines
    return;
end
for tt = r.lossTimes
    xline(ax,tt,'--','Loss','Color',[0.62,0.20,0.20], ...
        'HandleVisibility','off','LabelVerticalAlignment','middle');
end
for tt = r.reacquireTimes
    xline(ax,tt,'-.','Reacq','Color',[0.15,0.40,0.28], ...
        'HandleVisibility','off','LabelVerticalAlignment','bottom');
end
if isfinite(r.landingTime)
    xline(ax,r.landingTime,'-','Landed','Color',[0.20,0.20,0.20], ...
        'HandleVisibility','off','LabelVerticalAlignment','bottom');
end
end
