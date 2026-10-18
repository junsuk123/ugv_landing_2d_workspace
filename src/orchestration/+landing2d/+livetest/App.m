classdef App < handle
    % APP Native MATLAB UI for frozen-policy attention diagnostics.
    properties (SetAccess=private)
        Session
        Figure
        Timer
        UI = struct()
        LastError = ''
    end
    properties (Access=private)
        GraphIndex
        GraphViews
        Scene
        Series
        DeltaBars
        HistoryLines
        ActionLines
        TerminalTicks = 0
        Closing = false
    end
    methods
        function obj=App(options)
            obj.Session=landing2d.livetest.Session(options);
            obj.GraphIndex=find(~cellfun(@(q)isempty(q.actorAlpha),obj.Session.Current),1);
            assert(~isempty(obj.GraphIndex),'landing2d:LiveTestGraph','No compatible graph checkpoint.');
            obj.build(); obj.rebuildGraphs(); obj.render();
            obj.Timer=timer('Name','landing2d live attention','ExecutionMode','fixedSpacing', ...
                'Period',max(.02,.1/obj.Session.Options.playbackSpeed),'BusyMode','drop', ...
                'TimerFcn',@(~,~)obj.tick());
            if obj.Session.Options.autoStart, obj.start(); end
        end

        function start(obj)
            if strcmp(obj.Timer.Running,'off'), start(obj.Timer); end
            obj.UI.Start.Text='일시정지';
        end

        function pause(obj)
            if ~isempty(obj.Timer)&&isvalid(obj.Timer), stop(obj.Timer); end
            if isgraphics(obj.Figure), obj.UI.Start.Text='시작 / 재개'; end
        end

        function stepOnce(obj)
            obj.pause(); obj.Session.step(); obj.render();
        end

        function [ok,message]=triggerPulse(obj)
            [ok,message]=obj.Session.pulse(obj.UI.Acceleration.Value, ...
                obj.UI.Duration.Value,obj.UI.Coast.Value);
            obj.UI.Event.Text=message; obj.render();
        end

        function [ok,message]=triggerCut(obj)
            try
                [ok,message]=obj.Session.cut(obj.UI.Graph.Value,obj.UI.CutHead.Value, ...
                    obj.UI.CutScope.Value,obj.UI.CutTarget.Value,obj.UI.CutDuration.Value);
            catch err
                if ~strcmp(err.identifier,'landing2d:LiveTestCutTarget'), rethrow(err); end
                ok=false; message=err.message;
            end
            obj.UI.Event.Text=message;
            if ok
                obj.UI.AnalysisTabs.SelectedTab=obj.UI.EffectTab;
                obj.UI.DetailTabs.SelectedTab=obj.UI.ActionsTab;
            end
            obj.render();
        end

        function restoreCut(obj)
            obj.Session.restoreCut(); obj.UI.Event.Text='단절 해제: 현재 관측에서 정상 그래프로 복구했습니다.';
            obj.render();
        end

        function reset(obj)
            obj.Session.reset(); obj.TerminalTicks=0;
            obj.UI.Event.Text='새 에피소드. 같은 seed/잡음으로 반복하며 이벤트는 초기화됩니다.';
            obj.render();
        end

        function file=saveLog(obj)
            file=obj.Session.save(); obj.UI.Event.Text=['저장: ',file];
        end

        function delete(obj)
            if obj.Closing, return; end
            obj.Closing=true;
            if ~isempty(obj.Timer)&&isvalid(obj.Timer), stop(obj.Timer); delete(obj.Timer); end
            if ~isempty(obj.Figure)&&isgraphics(obj.Figure)
                obj.Figure.CloseRequestFcn=[]; delete(obj.Figure);
            end
        end
    end
    methods (Access=private)
        function tick(obj)
            if obj.Closing || ~isgraphics(obj.Figure), return; end
            try
                if obj.Session.done()
                    obj.TerminalTicks=obj.TerminalTicks+1;
                    if obj.UI.AutoReset.Value && obj.TerminalTicks>=20
                        obj.reset();
                    elseif ~obj.UI.AutoReset.Value
                        obj.pause();
                    end
                else
                    obj.Session.step(); obj.TerminalTicks=0;
                end
                obj.render();
            catch err
                obj.LastError=getReport(err,'extended','hyperlinks','off'); obj.pause();
                obj.UI.Event.Text=['중지: ',err.message];
                warning('landing2d:LiveTestRuntime','%s',obj.LastError);
            end
        end

        function toggle(obj)
            if strcmp(obj.Timer.Running,'on'), obj.pause(); else, obj.start(); end
        end

        function modeChanged(obj)
            obj.Session.configure(obj.UI.Mode.Value,obj.UI.Controller.Value,obj.UI.Noise.Value);
            obj.TerminalTicks=0; obj.UI.Event.Text='제어 모드/잡음 변경: 새 에피소드로 시작합니다.';
            obj.render();
        end

        function speedChanged(obj)
            running=strcmp(obj.Timer.Running,'on'); obj.pause();
            obj.Timer.Period=max(.02,.1/obj.UI.Speed.Value);
            if running, obj.start(); end
        end

        function graphChanged(obj)
            obj.GraphIndex=find(strcmp(obj.Session.MethodIds,obj.UI.Graph.Value),1);
            obj.rebuildGraphs(); obj.cutTargetsChanged(); obj.render();
        end

        function cutTargetsChanged(obj)
            d=obj.Session.Current{obj.GraphIndex}; t=d.graph;
            switch obj.UI.CutScope.Value
                case 'edge'
                    labels=compose('%02d | %s → %s (%s) | %s',(1:t.nEdges)', ...
                        string(d.nodeNames(t.src))',string(d.nodeNames(t.dst))', ...
                        string(d.relationNames(t.rel))',string(d.edgePurpose(:)));
                    values=1:t.nEdges; selected=1;
                case 'relation'
                    values=unique(t.rel); labels=string(d.relationNames(values)); selected=values(1);
                otherwise
                    values=1:t.nNodes; labels=string(d.nodeNames); selected=3;
            end
            obj.UI.CutTarget.ItemsData=[];
            obj.UI.CutTarget.Items=cellstr(labels(:)');
            obj.UI.CutTarget.ItemsData=values;
            obj.UI.CutTarget.Value=selected;
        end

        function baseline(obj)
            obj.Session.captureBaseline(); obj.UI.Event.Text='현재 추론을 Δattention 비교 기준으로 고정했습니다.';
            obj.render();
        end

        function build(obj)
            o=obj.Session.Options;
            obj.Figure=uifigure('Name','Ontology attention live test + temporary edge cut — run_livetest', ...
                'Position',[40 40 1580 980],'Color',[.97 .98 1], ...
                'Visible',o.figureVisible,'CloseRequestFcn',@(~,~)delete(obj));
            main=uigridlayout(obj.Figure,[8 1]);
            main.RowHeight={32,38,38,38,26,30,'1x',28}; main.Padding=[12 10 12 8];
            titleLabel=uilabel(main,'Text','온톨로지 ATTENTION LAB  |  고정 모델 · 실시간 추론 · 재학습 없음', ...
                'FontSize',20,'FontWeight','bold','FontColor',[.12 .20 .34]);
            titleLabel.Layout.Row=1;
            controls=uigridlayout(main,[1 12]); controls.Layout.Row=2;
            controls.ColumnWidth={94,66,86,230,145,170,78,100,94,62,62,'1x'};
            controls.Padding=[0 0 0 0]; controls.ColumnSpacing=6;
            obj.UI.Start=uibutton(controls,'Text','시작 / 재개','ButtonPushedFcn',@(~,~)obj.toggle());
            obj.UI.Step=uibutton(controls,'Text','한 스텝','ButtonPushedFcn',@(~,~)obj.stepOnce());
            obj.UI.Reset=uibutton(controls,'Text','다시 시작','ButtonPushedFcn',@(~,~)obj.reset());
            obj.UI.Mode=uidropdown(controls,'Items',{'장시간 관측: 구동기 비행 / 정책 추론','정책 직접 비행: 착륙 후 반복'}, ...
                'ItemsData',{'hold','policy'},'Value',o.mode,'ValueChangedFcn',@(~,~)obj.modeChanged());
            obj.UI.Controller=uidropdown(controls,'Items',cellstr("비행: "+string(obj.Session.MethodIds)), ...
                'ItemsData',obj.Session.MethodIds,'Value',o.controller, ...
                'Tooltip','직접 비행 모드의 제어 정책','ValueChangedFcn',@(~,~)obj.modeChanged());
            graphIds=obj.Session.MethodIds(~cellfun(@(q)isempty(q.actorAlpha),obj.Session.Current));
            obj.UI.Graph=uidropdown(controls,'Items',cellstr("그래프: "+string(graphIds)), ...
                'ItemsData',graphIds, ...
                'Tooltip','표시할 그래프: 모든 모델은 같은 현재 관측에서 추론', ...
                'ValueChangedFcn',@(~,~)obj.graphChanged());
            obj.UI.Speed=uidropdown(controls,'Items',{'0.25×','0.5×','1×','2×','4×'}, ...
                'ItemsData',[.25 .5 1 2 4],'Value',1, ...
                'Tooltip','목표 재생 배속 (하드 실시간 아님)','ValueChangedFcn',@(~,~)obj.speedChanged());
            if ismember(o.playbackSpeed,[.25 .5 1 2 4]), obj.UI.Speed.Value=o.playbackSpeed; end
            obj.UI.Save=uibutton(controls,'Text','로그 저장','ButtonPushedFcn',@(~,~)obj.saveLog());
            obj.UI.AutoReset=uicheckbox(controls,'Text','자동 반복','Value',o.autoReset);
            uilabel(controls,'Text','잡음 배율');
            obj.UI.Noise=uieditfield(controls,'numeric','Value',o.sensorNoiseScale,'Limits',[0 5], ...
                'ValueChangedFcn',@(~,~)obj.modeChanged());
            uilabel(controls,'Text',sprintf('최대 %.0f s / 회',o.duration));

            intervention=uigridlayout(main,[1 9]); intervention.Layout.Row=3;
            intervention.ColumnWidth={90,66,70,62,72,62,160,140,'1x'};
            intervention.Padding=[0 0 0 0]; intervention.ColumnSpacing=6;
            uilabel(intervention,'Text','가속도 [m/s²]');
            obj.UI.Acceleration=uieditfield(intervention,'numeric','Limits',[.1 3],'Value',o.pulseAcceleration);
            uilabel(intervention,'Text','가속 [s]');
            obj.UI.Duration=uieditfield(intervention,'numeric','Limits',[.1 5],'Value',o.pulseDuration);
            uilabel(intervention,'Text','유지 [s]');
            obj.UI.Coast=uieditfield(intervention,'numeric','Limits',[0 20],'Value',o.pulseCoast);
            obj.UI.Pulse=uibutton(intervention,'Text','패드 급가속 ▶','FontWeight','bold', ...
                'BackgroundColor',[1 .74 .34],'ButtonPushedFcn',@(~,~)obj.triggerPulse());
            uibutton(intervention,'Text','현재를 Δα 기준으로','ButtonPushedFcn',@(~,~)obj.baseline());
            obj.UI.Event=uilabel(intervention,'Text','급가속 → 유지 → 같은 크기로 자동 감속 (속도 원복)', ...
                'FontColor',[.45 .24 .06]);
            cutControls=uigridlayout(main,[1 9]); cutControls.Layout.Row=4;
            cutControls.ColumnWidth={90,138,'1x',144,60,60,134,100,240};
            cutControls.Padding=[0 0 0 0]; cutControls.ColumnSpacing=6;
            uilabel(cutControls,'Text','임시 그래프 단절','FontWeight','bold');
            obj.UI.CutScope=uidropdown(cutControls, ...
                'Items',{'단일 간선','노드 발신 (self 제외)','노드 수신 (self 제외)','노드 양방향 (self 제외)','관계 전체'}, ...
                'ItemsData',{'edge','outgoing','incoming','incident','relation'},'Value','outgoing', ...
                'ValueChangedFcn',@(~,~)obj.cutTargetsChanged());
            obj.UI.CutTarget=uidropdown(cutControls,'Tooltip','위의 그래프 모델에만 적용. 기본: PadVelocity의 발신 간선.');
            obj.UI.CutHead=uidropdown(cutControls,'Items',{'Actor: 행동','Critic: V만','Actor + Critic'}, ...
                'ItemsData',{'actor','critic','both'},'Value','actor');
            uilabel(cutControls,'Text','기간 [s]');
            obj.UI.CutDuration=uieditfield(cutControls,'numeric','Limits',[.1 60],'Value',o.cutDuration);
            obj.UI.Cut=uibutton(cutControls,'Text','임시 단절 (α=0)','FontWeight','bold', ...
                'BackgroundColor',[1 .68 .65],'ButtonPushedFcn',@(~,~)obj.triggerCut());
            obj.UI.Restore=uibutton(cutControls,'Text','즉시 복구','ButtonPushedFcn',@(~,~)obj.restoreCut());
            uilabel(cutControls,'Text','시뮬레이션 시간 · 재정규화 없음','FontColor',[.5 .15 .15]);
            obj.UI.CutStatus=uilabel(main,'FontSize',12); obj.UI.CutStatus.Layout.Row=5;
            obj.UI.Status=uilabel(main,'FontSize',12,'FontWeight','bold'); obj.UI.Status.Layout.Row=6;
            body=uigridlayout(main,[2 3]); body.Layout.Row=7;
            body.RowHeight={'1x','1x'}; body.ColumnWidth={'1x','1x','1.15x'};
            body.Padding=[0 0 0 0]; body.ColumnSpacing=10; body.RowSpacing=10;
            obj.UI.World=uiaxes(body); obj.UI.World.Layout.Row=1; obj.UI.World.Layout.Column=1;
            obj.UI.Actor=uiaxes(body); obj.UI.Actor.Layout.Row=1; obj.UI.Actor.Layout.Column=2;
            obj.UI.Critic=uiaxes(body); obj.UI.Critic.Layout.Row=1; obj.UI.Critic.Layout.Column=3;
            obj.UI.Series=uiaxes(body); obj.UI.Series.Layout.Row=2; obj.UI.Series.Layout.Column=1;
            tabs=uitabgroup(body); tabs.Layout.Row=2; tabs.Layout.Column=2;
            obj.UI.AnalysisTabs=tabs;
            deltaTab=uitab(tabs,'Title','버튼 전후 Δattention'); g=uigridlayout(deltaTab,[1 1]);
            g.Padding=[40 10 10 10];
            obj.UI.Delta=uiaxes(g);
            historyTab=uitab(tabs,'Title','Actor 노드 attention 이력'); g=uigridlayout(historyTab,[1 1]);
            obj.UI.History=uiaxes(g);
            obj.UI.EffectTab=uitab(tabs,'Title','단절 효과: 행동');
            g=uigridlayout(obj.UI.EffectTab,[2 1]); g.Padding=[5 5 5 5];
            obj.UI.ActionX=uiaxes(g); obj.UI.ActionZ=uiaxes(g);
            obj.ActionLines=gobjects(2,2);
            axesList=[obj.UI.ActionX,obj.UI.ActionZ];
            for k=1:2
                ax=axesList(k); hold(ax,'on'); grid(ax,'on');
                obj.ActionLines(k,1)=plot(ax,nan,nan,'--','Color',[.3 .3 .3],'LineWidth',1.5);
                obj.ActionLines(k,2)=plot(ax,nan,nan,'Color',[.75 .15 .25],'LineWidth',1.2);
                legend(ax,{'정상 (동일 관측)','현재 (단절 반영)'},'Location','best','FontSize',8);
                xlabel(ax,'inference time [s]');
            end
            ylabel(obj.UI.ActionX,'a_x [m/s²]'); ylabel(obj.UI.ActionZ,'a_z [m/s²]');
            detailTabs=uitabgroup(body); detailTabs.Layout.Row=2; detailTabs.Layout.Column=3;
            names={'노드 가중치','간선 가중치','입력 12D','노드 특징','정책 요청'};
            fields={'Nodes','Edges','Observation','Features','Actions'};
            for k=1:numel(names)
                tab=uitab(detailTabs,'Title',names{k}); g=uigridlayout(tab,[1 1]); g.Padding=[3 3 3 3];
                obj.UI.(fields{k})=uitable(g,'RowName',{},'FontSize',11);
                if strcmp(fields{k},'Actions'), obj.UI.ActionsTab=tab; end
            end
            obj.UI.DetailTabs=detailTabs;
            note=uilabel(main,'Text',['노드 색/크기 = 나가는 비자기 간선 α 평균. 선 굵기 = 실제 간선 α. ' ...
                '빨강 = 강제 단절 (α=0). 노드 자체 입력/W0 경로는 유지됩니다. 진단 결과 ≠ 온톨로지 전체 효과의 증명.'], ...
                'FontColor',[.35 .37 .43]); note.Layout.Row=8;
            if ~isempty(obj.Session.Unavailable)
                obj.UI.Event.Text='관계 교란 모델은 서명 불일치/파일 부재로 제외했습니다. 재학습·추론 재순열 없음.';
            end
            obj.createScene(); obj.createSeries(); obj.cutTargetsChanged();
        end

        function rebuildGraphs(obj)
            d=obj.Session.Current{obj.GraphIndex}; t=d.graph;
            g=digraph(t.src,t.dst,[],t.nNodes);
            order=zeros(t.nEdges,1);
            for e=1:t.nEdges, order(findedge(g,t.src(e),t.dst(e)))=e; end
            colors=[.17 .44 .75;.13 .62 .47;.49 .29 .68;.90 .50 .08; ...
                .80 .20 .20;.33 .56 .78;.52 .57 .61];
            labels=d.nodeNames;
            xy=landing2d.viz.graphLayout(labels);
            assert(size(xy,1)==t.nNodes,'landing2d:LiveTestLayout', ...
                'Add a live graph layout coordinate for every ontology node.');
            axesList=[obj.UI.Actor,obj.UI.Critic]; obj.GraphViews=struct([]);
            for h=1:2
                ax=axesList(h); cla(ax);
                p=plot(ax,g,'XData',xy(:,1),'YData',xy(:,2),'NodeLabel',labels, ...
                    'NodeCData',zeros(t.nNodes,1),'MarkerSize',12,'ArrowSize',10, ...
                    'EdgeColor',colors(t.rel(order),:),'NodeFontSize',11);
                colormap(ax,parula(128)); clim(ax,[0 1]);
                cb=colorbar(ax); cb.Label.String='mean outgoing α (no self)';
                ax.XTick=[]; ax.YTick=[]; ax.Box='on'; xlim(ax,[-2.9 4.4]); ylim(ax,[-1.3 3.8]);
                obj.GraphViews(h).plot=p; obj.GraphViews(h).order=order;
                obj.GraphViews(h).colors=colors(t.rel(order),:);
            end
            title(obj.UI.Actor,'ACTOR · 관계별 메시지 attention');
            title(obj.UI.Critic,'CRITIC · 관계별 메시지 attention');
            for ax=axesList
                subtitle(ax,strjoin(d.relationNames,' | '),'Interpreter','none','FontSize',8);
            end
            ax=obj.UI.Delta; cla(ax); obj.DeltaBars=barh(ax,zeros(t.nNodes,2),'grouped');
            obj.DeltaBars(1).FaceColor=[.38 .20 .66]; obj.DeltaBars(2).FaceColor=[.08 .48 .57];
            ax.YTick=1:t.nNodes; ax.YTickLabel=labels; ax.YDir='reverse';
            ax.FontSize=10; ax.TickLabelInterpreter='none'; ax.PositionConstraint='outerposition';
            xlabel(ax,'Δ mean outgoing α'); grid(ax,'on'); legend(ax,{'Actor','Critic'},'Location','best');
            ax=obj.UI.History; cla(ax); hold(ax,'on'); grid(ax,'on');
            obj.HistoryLines=plot(ax,NaN(2,t.nNodes),NaN(2,t.nNodes),'LineWidth',1.2);
            legend(ax,labels,'FontSize',9,'Location','eastoutside'); xlabel(ax,'time [s]'); ylabel(ax,'mean outgoing α');
        end

        function createScene(obj)
            ax=obj.UI.World; hold(ax,'on'); grid(ax,'on'); box(ax,'on');
            xlabel(ax,'absolute x [m]'); ylabel(ax,'absolute z [m]');
            obj.Scene.fov=patch(ax,nan,nan,[.2 .7 .4],'FaceAlpha',.14,'EdgeColor','none');
            obj.Scene.trail=plot(ax,nan,nan,'Color',[.38 .2 .66],'LineWidth',1.2);
            obj.Scene.pad=patch(ax,nan,nan,[.85 .55 .18],'EdgeColor',[.35 .25 .15]);
            obj.Scene.drone=plot(ax,nan,nan,'-o','Color',[.26 .15 .54],'LineWidth',3,'MarkerFaceColor',[.26 .15 .54]);
            obj.Scene.ground=plot(ax,[-1e5 1e5],[0 0],'Color',[.5 .5 .5]);
        end

        function createSeries(obj)
            ax=obj.UI.Series; hold(ax,'on'); grid(ax,'on');
            yyaxis(ax,'left'); obj.Series.pad=plot(ax,nan,nan,'k--','LineWidth',1.3,'DisplayName','pad v_x');
            obj.Series.drone=plot(ax,nan,nan,'Color',[.16 .38 .73],'LineWidth',1.3,'DisplayName','drone v_x');
            ylabel(ax,'velocity [m/s]');
            yyaxis(ax,'right'); obj.Series.height=plot(ax,nan,nan,'Color',[.51 .3 .7],'LineWidth',1.3,'DisplayName','height');
            ylabel(ax,'height above pad [m]'); xlabel(ax,'time [s]');
            legend(ax,'Location','best','FontSize',9); title(ax,'물리 상태 · 실제 시간');
        end

        function render(obj)
            s=obj.Session; e=s.Env; state=e.physicalState; d=s.Current{obj.GraphIndex}; b=s.Baseline{obj.GraphIndex};
            if strcmp(s.Options.mode,'hold')
                mode='관측 모드: 별도 구동기 비행, 학습 정책은 추론만';
            else
                mode=['직접 비행: ',s.Options.controller];
            end
            suffix=''; if s.done(), suffix=[' | 종료 ',e.episodeStatus.terminalReason,' (마지막 추론 고정)']; end
            obj.UI.Status.Text=sprintf('%s | 회차 %d · %.1f / %.0f s | vPad %.2f · aPad %+.2f | 영상갱신 %d · age %.1f s%s', ...
                mode,s.Episode,e.time,e.scenario.deadline,e.pad.vx,e.pad.ax, ...
                e.commonObservation.ugv.visionUpdated,e.commonObservation.ugv.visionAge,suffix);
            obj.UI.Cut.Enable=~s.done() && s.ActiveCut==0;
            obj.UI.Restore.Enable=s.ActiveCut>0;
            if s.ActiveCut>0
                cut=s.CutEvents(s.ActiveCut); remaining=max(0,cut.plannedEnd-e.time);
                if strcmp(cut.head,'critic')
                    effect='Critic V만 변화: 행동에는 영향 없음';
                elseif strcmp(s.Options.mode,'policy') && strcmp(s.Options.controller,cut.methodId)
                    effect='단절 후 Actor 명령으로 실제 비행';
                else
                    effect='추론만 비교: 현재 비행 명령에는 미적용';
                end
                obj.UI.CutStatus.Text=sprintf('단절 #%d | %s / %s | 간선 %s | 남은 %.1f s | %s', ...
                    cut.id,cut.methodId,cut.head,mat2str(cut.edgeIds),remaining,effect);
                obj.UI.CutStatus.FontColor=[.72 .1 .14];
            else
                obj.UI.CutStatus.Text='단절 없음 / 복구됨 | 행동 변화는 「단절 효과」와 「정책 요청」 탭. 정상 값은 현재와 동일 관측에서 재계산합니다.';
                obj.UI.CutStatus.FontColor=[.25 .32 .4];
                if s.done() && (any(d.actorCut)||any(d.criticCut))
                    obj.UI.CutStatus.Text='종료로 단절 해제 | 화면은 마지막 결정 시점의 단절 추론 고정. 다시 시작하면 정상 그래프입니다.';
                end
            end
            for h=1:2
                if h==1
                    alpha=d.actorAlpha; node=d.actorNode; cut=d.actorCut;
                else
                    alpha=d.criticAlpha; node=d.criticNode; cut=d.criticCut;
                end
                p=obj.GraphViews(h).plot; order=obj.GraphViews(h).order;
                p.NodeCData=node; p.MarkerSize=10+14*node; p.LineWidth=.5+5*alpha(order);
                colors=obj.GraphViews(h).colors; colors(cut(order),:)=repmat([.9 .12 .16],sum(cut),1);
                p.EdgeColor=colors;
            end
            da=d.actorNode-b.actorNode; dc=d.criticNode-b.criticNode;
            obj.DeltaBars(1).YData=da; obj.DeltaBars(2).YData=dc;
            limit=max(.002,1.15*max(abs([da;dc]))); xlim(obj.UI.Delta,[-limit limit]);
            title(obj.UI.Delta,sprintf('기준 t=%.1f s · 현재 t=%.1f s',s.BaselineTime,e.time),'FontSize',11);
            featureChange=vecnorm(d.features-b.features,2,1)';
            obj.UI.Nodes.Data=[string(d.nodeNames(:)),compose('%.3f',featureChange), ...
                compose('%.4f',d.actorNode),compose('%+.4f',da),compose('%.4f',d.criticNode),compose('%+.4f',dc)];
            obj.UI.Nodes.ColumnName={'Node','dX norm','Actor α','Δα','Critic α','Δα'};
            obj.UI.Nodes.ColumnWidth={126,58,65,65,65,65};
            t=d.graph;
            obj.UI.Edges.Data=[string(d.nodeNames(t.src))',string(d.nodeNames(t.dst))', ...
                string(d.relationNames(t.rel))',string(d.edgePurpose(:)),compose('%.4f',d.actorAlpha), ...
                compose('%+.4f',d.actorAlpha-b.actorAlpha),compose('%.4f',d.criticAlpha), ...
                compose('%+.4f',d.criticAlpha-b.criticAlpha),string(d.actorCut),string(d.criticCut)];
            obj.UI.Edges.ColumnName={'Source','Target','Relation','Semantic purpose','Actor α','Δα','Critic α','Δα','Actor cut','Critic cut'};
            obj.UI.Edges.ColumnWidth={112,112,76,260,65,65,65,65,70,70};
            schema=s.Config.experiment.observationSchema;
            obj.UI.Observation.Data=[string(schema.names(:)),compose('%.5f',s.InferenceObservation)];
            obj.UI.Observation.ColumnName={'Common observation (bounded)','Value'};
            obj.UI.Observation.ColumnWidth={250,100};
            obj.UI.Features.Data=[string(d.nodeNames(:)),compose('%.4f',d.features')];
            obj.UI.Features.ColumnName=[{'Node'},s.Agents{obj.GraphIndex}.encoderSpec.schema.featureNames];
            rows=strings(3*numel(s.Current),5);
            for m=1:numel(s.Current)
                q=s.Current{m}; nominal=[q.nominalRequest;q.nominalValue]; actual=[q.request;q.value];
                rows(3*m-2:3*m,:)=[repmat(string(s.MethodIds{m}),3,1),["a_x";"a_z";"V"], ...
                    compose('%.5f',nominal),compose('%.5f',actual),compose('%+.5f',actual-nominal)];
            end
            obj.UI.Actions.Data=rows;
            obj.UI.Actions.ColumnName={'동일 관측 / 모델','출력','정상','현재','Δ 현재−정상'};
            obj.UI.Actions.ColumnWidth={156,46,84,84,94};
            log=s.Log; n=log.count; ix=find(log.time(1:n)>=max(0,e.time-s.Options.historySeconds));
            axesList=[obj.UI.ActionX,obj.UI.ActionZ];
            for k=1:2
                obj.ActionLines(k,1).XData=log.inferenceTime(ix);
                obj.ActionLines(k,1).YData=reshape(log.nominalRequests(k,obj.GraphIndex,ix),1,[]);
                obj.ActionLines(k,2).XData=log.inferenceTime(ix);
                obj.ActionLines(k,2).YData=reshape(log.requests(k,obj.GraphIndex,ix),1,[]);
                xlim(axesList(k),[max(0,e.time-s.Options.historySeconds),max(1,e.time)]);
            end
            delta=d.request-d.nominalRequest;
            title(obj.UI.ActionX,sprintf('동일 관측 Δa_x=%+.4f · Δa_z=%+.4f m/s²',delta(1),delta(2)),'FontSize',10);
            for j=1:numel(obj.HistoryLines)
                obj.HistoryLines(j).XData=log.time(ix);
                obj.HistoryLines(j).YData=log.nodeActor{obj.GraphIndex}(j,ix);
            end
            xlim(obj.UI.History,[max(0,e.time-s.Options.historySeconds),max(1,e.time)]);
            obj.Series.pad.XData=log.time(ix); obj.Series.pad.YData=log.truth(6,ix);
            obj.Series.drone.XData=log.time(ix); obj.Series.drone.YData=log.truth(3,ix);
            obj.Series.height.XData=log.time(ix); obj.Series.height.YData=log.truth(2,ix)-s.Config.padHeight;
            xlim(obj.UI.Series,[max(0,e.time-s.Options.historySeconds),max(1,e.time)]);
            obj.Scene.trail.XData=log.truth(1,ix); obj.Scene.trail.YData=log.truth(2,ix);
            width=s.Config.padHalfLength; z=e.pad.z; x=e.pad.x;
            obj.Scene.pad.XData=x+width*[-1 1 1 -1]; obj.Scene.pad.YData=[z-.18 z-.18 z z];
            obj.Scene.drone.XData=state.x+.34*[-1 1]*cos(state.theta);
            obj.Scene.drone.YData=state.z-.34*[-1 1]*sin(state.theta);
            center=(state.x+x)/2; half=max(7,abs(state.x-x)/2+3);
            xlim(obj.UI.World,center+[-half half]); ylim(obj.UI.World,[0 max(s.Options.height+2,state.z+1)]);
            title(obj.UI.World,sprintf('h %.2f m · xDrone−xPad %+.2f m',state.z-z,state.x-x),'FontSize',11);
            obj.drawFov();
            drawnow limitrate nocallbacks;
        end

        function drawFov(obj)
            e=obj.Session.Env; s=e.physicalState; sensor=e.config.experiment.sensor;
            a=s.theta+sensor.cameraPitchOffset; angle=atan2(-cos(a),-sin(a));
            xs=s.x; zs=s.z;
            for sign=[-1 1]
                ray=[cos(angle+sign*sensor.fov/2);sin(angle+sign*sensor.fov/2)];
                reach=20;
                if ray(2)<-1e-3, reach=min(20,max(0,s.z-e.pad.z)/-ray(2)); end
                xs(end+1)=s.x+reach*ray(1); zs(end+1)=s.z+reach*ray(2); %#ok<AGROW>
            end
            obj.Scene.fov.XData=xs; obj.Scene.fov.YData=zs;
            if e.commonObservation.ugv.visionUpdated, color=[.2 .7 .4]; else, color=[.85 .2 .18]; end
            obj.Scene.fov.FaceColor=color;
        end
    end
end
