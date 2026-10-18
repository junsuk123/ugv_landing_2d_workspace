function figures=plotComparison(study,visible)
% PLOTCOMPARISON Dynamic 4-by-2 pages covering every registered graph edge.
if nargin<2, visible=true; end
normal=study.normal; cases=study.cases; o=study.options;
blue=[.10 .36 .73]; orange=[.88 .32 .10]; purple=[.64 .12 .64];
allX=[normal.truth(1,:),normal.truth(6,end)]; allZ=normal.truth(2,:);
for e=1:numel(cases)
    allX=[allX,cases{e}.truth(1,:),cases{e}.truth(6,end)]; %#ok<AGROW>
    allZ=[allZ,cases{e}.truth(2,:)]; %#ok<AGROW>
end
xPadding=max(1.5,.035*(max(allX)-min(allX)));
xLimits=[min(allX)-xPadding,max(allX)+xPadding];
zLimits=[min(0,min(allZ)-.2),max(allZ)+.5];
nEdges=numel(cases); pageCount=ceil(nEdges/8); figures=gobjects(1,pageCount);
for page=1:pageCount
    first=8*page-7; last=min(8*page,nEdges);
    figures(page)=figure('Name',sprintf('run_unlink | edges %02d-%02d / %d',first,last,nEdges), ...
        'NumberTitle','off','Color','w','Position',[45+25*(page-1),30+15*(page-1),1400,1000], ...
        'Visible',visible,'Tag','landing2d_unlink');
    layout=tiledlayout(figures(page),4,2,'TileSpacing','compact','Padding','compact');
    title(layout,sprintf('Intact vs temporary single-edge cut | %s | edges %02d-%02d', ...
        study.scenario.id,first,last),'FontWeight','bold','FontSize',17);
    subtitle(layout,sprintf(['same ontology-PPO | Actor alpha=0 | [%.1f, %.1f) s | seed %d | noise x%.2g' ...
        ' | %d edges total | no renormalization | shared axes'], ...
        o.cutStart,o.cutStart+o.cutDuration,study.scenario.seed,o.sensorNoiseScale,nEdges),'FontSize',11);
    for slot=1:8
        edge=8*(page-1)+slot;
        if edge>nEdges
            ax=nexttile(layout); axis(ax,'off'); continue;
        end
        r=cases{edge}; row=study.summary(edge,:);
        ax=nexttile(layout); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
        ax.FontSize=9; ax.Tag=sprintf('unlink_edge_%02d',edge);
        h1=plot(ax,normal.truth(1,:),normal.truth(2,:),'-','Color',blue,'LineWidth',1.6);
        h2=plot(ax,r.truth(1,:),r.truth(2,:),'--','Color',orange,'LineWidth',1.5);
        h3=plot(ax,nan,nan,'-','Color',purple,'LineWidth',2.8);
        h4=plot(ax,nan,nan,'s','Color',purple,'MarkerFaceColor',purple,'MarkerSize',5);
        h5=plot(ax,nan,nan,'^','Color',purple,'MarkerFaceColor','w','MarkerSize',6);
        selected=find(r.decision.active);
        if ~isempty(selected)
            section=selected(1):selected(end)+1;
            h3.XData=r.truth(1,section); h3.YData=r.truth(2,section);
            h4.XData=r.truth(1,section(1)); h4.YData=r.truth(2,section(1));
            if r.cut.restoredInFlight
                h5.XData=r.truth(1,section(end)); h5.YData=r.truth(2,section(end));
            end
        end
        plot(ax,normal.truth(1,1),normal.truth(2,1),'kp','MarkerFaceColor','k','MarkerSize',7);
        plot(ax,normal.truth(1,end),normal.truth(2,end),'o','Color',blue,'MarkerSize',5);
        plot(ax,r.truth(1,end),r.truth(2,end),'x','Color',orange,'MarkerSize',7,'LineWidth',1.3);
        drawPad(ax,normal,study.padHalfLength,blue,'-');
        drawPad(ax,r,study.padHalfLength,orange,'--');
        xlim(ax,xLimits); ylim(ax,zLimits);
        xlabel(ax,'absolute x [m]'); ylabel(ax,'absolute z [m]');
        title(ax,sprintf('%02d %s -> %s [%s]',edge,row.Source,row.Target,row.Relation), ...
            'Interpreter','none','FontSize',10,'FontWeight','bold');
        if isempty(selected)
            detail=sprintf('intact %s / cut %s | not applied',normal.terminalReason,r.terminalReason);
        else
            detail=sprintf('intact %s / cut %s | max gap %.3f m | %.1f-%.1f s', ...
                normal.terminalReason,r.terminalReason,row.MaxPairedSeparation_m, ...
                r.cut.actualStart,r.cut.actualEnd);
        end
        subtitle(ax,detail,'FontSize',8,'Interpreter','none');
        if slot==1
            lg=legend(ax,[h1,h2,h3,h4,h5], ...
                {'intact','edge cut','actual cut segment','cut start','restored in flight'}, ...
                'Orientation','horizontal','FontSize',10);
            lg.Layout.Tile='south';
        end
    end
    drawnow;
end
end

function drawPad(ax,r,halfWidth,color,lineStyle)
x=r.truth(6,end); z=r.truth(7,end);
patch(ax,x+halfWidth*[-1,1,1,-1],[z-.12,z-.12,z,z],color, ...
    'FaceAlpha',.15,'EdgeColor',color,'LineStyle',lineStyle,'LineWidth',1, ...
    'HandleVisibility','off');
end
