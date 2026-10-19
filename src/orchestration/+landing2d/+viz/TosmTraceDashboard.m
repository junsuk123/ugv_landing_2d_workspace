classdef TosmTraceDashboard < handle
% TOSMTRACEDASHBOARD  Animated decision-trace dashboard of the TOSM R-GAT Actor.
%   dash = landing2d.viz.TosmTraceDashboard(trace)                 % replay
%   dash = landing2d.viz.TosmTraceDashboard(skeleton,struct('mode','live'))
%   dash.appendRecord(record); dash.finalize(trace)                 % live feed
% Reads a decision trace (landing2d.trace.recordEpisode); it never runs the
% simulation or the network. Layout:
%   left    per-source stream lanes on the simulation clock and status cards
%           (camera frame, ArUco detection, PnP, UGV KF measurement / time
%           update, UAV navigation estimate, policy decisions; the injected
%           dropout band is evaluation-only)
%   center  (A) sensor / estimator dataflow, (B) o_t -> node-feature
%           derivations (perturbation-derived, not message edges), (C) the
%           13 typed + 7 self R-GAT edges of the checkpoint (propagate solid,
%           modulate dashed with a gate ripple), then the readout of all 7
%           node embeddings -> Actor MLP -> requested acceleration
%   right   alpha per edge (per operator pool), X_t, H_t, the modulating
%           gate, g_A, the command; Critic g_V and V on a separate tab
%   bottom  Korean situation banner (after every decision) and the evidence
%           chain of the clicked element (Back = upstream, Forward =
%           downstream, Expand All = full chain)
% Playback: 0.25x-4x on the recorded simulation clock, pause, single step by
% decision, seek, follow-live, and an explanatory staged sweep that unfolds
% the computations of ONE decision time in display order (labeled as not a
% physical latency and not a multi-hop inference). Graphics are throttled
% (drawnow limitrate); the event log itself is never coalesced.
    properties (SetAccess = private)
        Trace
        Mode = 'replay'
        Figure
        DisplayTime = 0
        Decision = 0
        Phase = 7
        PhaseProgress = 1
        Playing = false
        Speed = 1
        Staged = false
        StageSeconds = 0.35
        FollowLive = true
        Focus = strings(1,0)
        StrengthMode = 'alpha'
        ShowSelf = false
        RelationFilter = 'all'
        Finished = false
        RenderCount = 0
    end
    properties (Access = private)
        H = struct()
        Geo = struct()
        Dep = []
        Timer = []
        LastTick = []
        StageClock = 0
        Visible = true
        ShownDecision = -1
        Chain = []
    end
    properties (Constant, Access = private)
        Colors = struct('camera',[0 0.62 0.82],'navigation',[0.33 0.22 0.72], ...
            'accepted',[0.10 0.58 0.25],'predicted',[0.55 0.55 0.55], ...
            'derived',[0.62 0.62 0.62],'propagate',[0 0.55 0.55], ...
            'modulate',[0.56 0.20 0.70],'readout',[0.85 0.62 0.05], ...
            'missing',[0.85 0.15 0.15],'faded',[0.88 0.88 0.88], ...
            'explicit',[0.86 0.92 0.98],'implicit',[0.99 0.92 0.78], ...
            'box',[0.95 0.95 0.95],'text',[0.12 0.12 0.12])
        PhaseNames = {'0 센서 사건','1 마커 검출·PnP','2 KF 갱신','3 o_t 생성', ...
            '4 노드 특징 파생','5 R-GAT 순전파 (단일 층)','6 리드아웃·액터','7 상황 설명'}
    end
    methods
        function obj = TosmTraceDashboard(decisionTrace,options)
            if nargin < 2, options = struct(); end
            options = merge(struct('mode','replay','visible',true,'speed',1, ...
                'staged',false,'title',''),options);
            obj.Trace = decisionTrace; obj.Mode = char(options.mode);
            obj.Visible = logical(options.visible); obj.Speed = options.speed;
            obj.Staged = logical(options.staged);
            obj.Dep = landing2d.trace.dependencyGraph(decisionTrace);
            obj.Finished = ~strcmp(obj.Mode,'live');
            obj.build(options.title);
            if ~isempty(decisionTrace.records)
                obj.showDecision(1,0); obj.refreshTimeline();
            end
            obj.Timer = timer('ExecutionMode','fixedSpacing','Period',0.04, ...
                'BusyMode','drop','TimerFcn',@(~,~)obj.tick(), ...
                'Name','TosmTraceDashboard');
            if strcmp(obj.Mode,'live'), obj.Playing = true; end
            if obj.Visible, start(obj.Timer); end
        end

        function delete(obj)
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer); delete(obj.Timer);
            end
            if ~isempty(obj.Figure) && isvalid(obj.Figure), delete(obj.Figure); end
        end

        function appendRecord(obj,record)
        % Live feed: one finished decision record (copied, read-only).
            if isempty(obj.Trace.records)
                obj.Trace.records = record;
            else
                obj.Trace.records(end+1) = record;
            end
            obj.Trace.events = landing2d.trace.buildEvents(obj.Trace);
            obj.refreshTimeline();
            if obj.ShownDecision < 1, obj.showDecision(1,0); end
            obj.updateSlider();
        end

        function finalize(obj,decisionTrace)
        % Live feed finished: the complete trace (terminal and events).
            obj.Trace = decisionTrace; obj.Finished = true;
            obj.refreshTimeline(); obj.updateSlider();
            obj.H.mode.Text = [obj.H.mode.Text,'  |  기록 완료 (재생 가능)'];
        end

        function play(obj), obj.Playing = true; obj.LastTick = []; obj.H.play.Text = '❚❚ 일시정지'; end
        function pause(obj), obj.Playing = false; obj.H.play.Text = '▶ 재생'; end

        function setSpeed(obj,speed)
            obj.Speed = speed;
            obj.H.speed.Value = sprintf('%gx',speed);
        end

        function setStaged(obj,staged)
            obj.Staged = logical(staged); obj.H.staged.Value = obj.Staged;
            obj.StageClock = 0;
        end

        function step(obj,delta)
        % Single step by decision (shows the completed decision).
            n = numel(obj.Trace.records);
            if n == 0, return; end
            k = min(max(max(obj.Decision,1)+delta,1),n);
            obj.pause();
            obj.DisplayTime = obj.Trace.records(k).time;
            obj.StageClock = 0;
            obj.showDecision(k,7,1);
        end

        function seek(obj,time)
            n = numel(obj.Trace.records);
            if n == 0, return; end
            times = [obj.Trace.records.time];
            obj.DisplayTime = min(max(time,times(1)),times(end)+obj.policyDt());
            k = find(times <= obj.DisplayTime+1e-9,1,'last');
            obj.showDecision(k,7,1);
        end

        function select(obj,focus)
        % Highlight the evidence chain of FOCUS (landing2d.trace.selectionChain ids).
            obj.Focus = string(focus);
            obj.updateChain();
            obj.applyHighlight();
        end

        function back(obj)
            if isempty(obj.Chain) || isempty(obj.Chain.parents), return; end
            obj.select(obj.Chain.parents);
        end

        function forward(obj)
            if isempty(obj.Chain) || isempty(obj.Chain.children), return; end
            obj.select(obj.Chain.children);
        end

        function expandAll(obj), obj.select("action"); end

        function clearSelection(obj)
            obj.Focus = strings(1,0); obj.Chain = [];
            obj.H.chain.Value = {'요소를 클릭하면 원천 → o_t → 노드 특징 → 간선 → 노드 임베딩 → 리드아웃 → 가속도 명령 근거 사슬을 표시합니다.'};
            obj.applyHighlight();
        end

        function setStrengthMode(obj,mode)
            obj.StrengthMode = char(mode); obj.H.strength.Value = obj.strengthLabel(mode);
            obj.ShownDecision = -1; obj.render();
        end

        function setShowSelf(obj,value)
            obj.ShowSelf = logical(value); obj.H.self.Value = obj.ShowSelf;
            obj.ShownDecision = -1; obj.render();
        end

        function setRelationFilter(obj,name)
            obj.RelationFilter = char(name); obj.H.filter.Value = obj.RelationFilter;
            obj.ShownDecision = -1; obj.render();
        end

        function exportPng(obj,file)
            drawnow;
            exportapp(obj.Figure,file);
        end

        function exportVideo(obj,file,options)
        % MP4 of the recorded trace (one frame per decision and phase step).
            if nargin < 3, options = struct(); end
            options = merge(struct('framesPerDecision',2,'frameRate',10,'staged',false),options);
            writer = VideoWriter(file,'MPEG-4'); writer.FrameRate = options.frameRate;
            open(writer); cleanup = onCleanup(@()close(writer));
            wasPlaying = obj.Playing; obj.pause();
            for k = 1:numel(obj.Trace.records)
                for f = 1:options.framesPerDecision
                    if options.staged
                        phase = min(7,floor(8*(f-1)/options.framesPerDecision));
                        obj.showDecision(k,phase,1);
                    else
                        obj.showDecision(k,7,f/options.framesPerDecision);
                    end
                    drawnow;
                    writeVideo(writer,getframe(obj.Figure));
                end
            end
            if wasPlaying, obj.play(); end
        end

        function S = snapshot(obj)
        % Displayed state (headless tests): what the panels show right now.
            S = struct('decision',obj.Decision,'phase',obj.Phase, ...
                'displayTime',obj.DisplayTime,'focus',obj.Focus, ...
                'mode',obj.H.mode.Text,'banner',string(obj.H.banner.Value), ...
                'chain',string(obj.H.chain.Value),'alphaBars',reshape(vertcat(obj.H.alphaBars.YData)',[],1), ...
                'X',obj.H.xImage.CData,'H',obj.H.hImage.CData,'gate',obj.H.gateImage.CData, ...
                'g',obj.H.gBars.YData(:),'action',obj.H.actionBars.YData(:), ...
                'activeSegments',{obj.activeSegmentIds()}, ...
                'highlighted',obj.highlightedIds(),'legend',{obj.H.legend.Value}, ...
                'phaseLabel',obj.H.time.Text,'renderCount',obj.RenderCount);
        end

        function render(obj)
        % Draw the decision and phase that correspond to the display clock.
            n = numel(obj.Trace.records);
            if n == 0 || ~isvalid(obj.Figure), return; end
            if obj.Staged
                k = max(obj.Decision,1);
                phase = min(7,floor(obj.StageClock)); progress = obj.StageClock-phase;
            else
                times = [obj.Trace.records.time];
                k = find(times <= obj.DisplayTime+1e-9,1,'last');
                if isempty(k), k = 1; end
                progress = min(max((obj.DisplayTime-times(k))/obj.policyDt(),0),1);
                phase = -1;                                   % all stages at once
            end
            obj.showDecision(k,phase,progress);
        end
    end

    methods (Access = private)
        function dt = policyDt(obj), dt = obj.Trace.context.policyDt; end
        function tf = isV2(obj)
            tf = isfield(obj.Trace.schema,'encoderVersion') && strcmp(obj.Trace.schema.encoderVersion,'rgat_v2');
        end
        function L = layerCount(obj)
            L = 1; if isfield(obj.Trace.schema,'layers'), L = obj.Trace.schema.layers; end
        end

        function tick(obj)
            try
                if ~isvalid(obj.Figure), stop(obj.Timer); return; end
                tickStart = tic;
                if isempty(obj.LastTick), elapsed = 0; else, elapsed = toc(obj.LastTick); end
                obj.LastTick = tickStart;
                n = numel(obj.Trace.records);
                if obj.Playing && n > 0
                    times = [obj.Trace.records.time];
                    if obj.Staged
                        obj.StageClock = obj.StageClock+elapsed/obj.StageSeconds;
                        if obj.StageClock >= 8
                            if obj.Decision < n
                                obj.Decision = obj.Decision+1; obj.StageClock = 0;
                            else
                                obj.StageClock = 8-1e-9;
                            end
                        end
                        obj.DisplayTime = times(max(obj.Decision,1));
                    else
                        obj.DisplayTime = obj.DisplayTime+elapsed*obj.Speed;
                        if strcmp(obj.Mode,'live') && obj.FollowLive && ~obj.Finished
                            obj.DisplayTime = max(obj.DisplayTime,times(end));
                        end
                        obj.DisplayTime = min(obj.DisplayTime,times(end)+obj.policyDt()-1e-9);
                    end
                end
                obj.render();
                drawnow limitrate;
            catch err
                warning('landing2d:TraceDashboard','%s',err.message);
            end
        end

        function showDecision(obj,k,phase,progress)
            if nargin < 4, progress = 1; end
            n = numel(obj.Trace.records);
            if n == 0, return; end
            k = min(max(k,1),n);
            changed = k ~= obj.ShownDecision;
            obj.Decision = k; obj.Phase = phase; obj.PhaseProgress = progress;
            if changed
                obj.updatePanels(k);
                obj.ShownDecision = k;
                if ~isempty(obj.Focus), obj.updateChain(); end
                obj.applyHighlight();
            end
            obj.updatePulses(k,phase,progress);
            obj.updateClock(k,phase);
            obj.RenderCount = obj.RenderCount+1;
        end

        % ------------------------------------------------------------- build
        function build(obj,titleText)
            L = obj.Trace.labels;
            screen = get(groot,'ScreenSize');
            figWidth = min(1720,max(1280,round(0.94*screen(3))));
            figHeight = min(1000,max(780,round(0.90*screen(4))));
            visible = 'off'; if obj.Visible, visible = 'on'; end
            if isempty(titleText), titleText = 'TOSM R-GAT 결정 추적 (decision trace)'; end
            obj.Figure = uifigure('Name',titleText,'Visible',visible, ...
                'Position',[20 30 figWidth figHeight],'Color','w', ...
                'CloseRequestFcn',@(~,~)obj.delete());
            try, obj.Figure.Theme = 'light'; catch, end
            root = uigridlayout(obj.Figure,[4 1],'RowHeight',{26,34,'1x',210}, ...
                'Padding',[6 6 6 6],'RowSpacing',4);
            obj.H.mode = uilabel(root,'Text',obj.modeText(),'FontWeight','bold', ...
                'FontColor',obj.modeColor());
            obj.buildToolbar(root);
            main = uigridlayout(root,[1 3],'ColumnWidth',{300,'1x',400},'Padding',[0 0 0 0], ...
                'ColumnSpacing',6);
            obj.buildStreams(main);
            obj.buildDiagram(main);
            obj.buildNumeric(main);
            bottom = uigridlayout(root,[1 3],'ColumnWidth',{'2x','3x',250},'Padding',[0 0 0 0], ...
                'ColumnSpacing',6);
            obj.H.banner = uitextarea(bottom,'Editable','off','FontSize',12.5, ...
                'Value',{'결정이 완료되면 현재 상황 의미가 여기에 표시됩니다.'});
            obj.H.chain = uitextarea(bottom,'Editable','off','FontSize',11);
            side = uigridlayout(bottom,[7 1],'RowHeight',{26,26,26,26,26,'1x',0}, ...
                'Padding',[0 0 0 0],'RowSpacing',3);
            uibutton(side,'Text','◀ 상류 (Back)','ButtonPushedFcn',@(~,~)obj.back());
            uibutton(side,'Text','하류 ▶ (Forward)','ButtonPushedFcn',@(~,~)obj.forward());
            uibutton(side,'Text','전체 근거 사슬 (Expand All)','ButtonPushedFcn',@(~,~)obj.expandAll());
            uibutton(side,'Text','LandingCondition 사슬','ButtonPushedFcn',@(~,~)obj.select("node:7"));
            uibutton(side,'Text','선택 해제','ButtonPushedFcn',@(~,~)obj.clearSelection());
            legendLines = L.legend;
            if obj.isV2() && isfield(L,'legendV2'), legendLines = L.legendV2; end
            obj.H.legend = uitextarea(side,'Editable','off','FontSize',9.5,'Value',legendLines);
            obj.clearSelection();
        end

        function buildToolbar(obj,root)
            toolbar = uigridlayout(root,[1 13],'ColumnWidth',{70,90,70,190,70,120,110,'1x',190,150,110,90,90}, ...
                'Padding',[0 0 0 0],'ColumnSpacing',4);
            uibutton(toolbar,'Text','◀ 결정','ButtonPushedFcn',@(~,~)obj.step(-1));
            obj.H.play = uibutton(toolbar,'Text','▶ 재생','ButtonPushedFcn',@(~,~)obj.togglePlay());
            uibutton(toolbar,'Text','결정 ▶','ButtonPushedFcn',@(~,~)obj.step(1));
            obj.H.slider = uislider(toolbar,'Limits',[0 1],'MajorTicks',[],'MinorTicks',[], ...
                'ValueChangedFcn',@(s,~)obj.seek(s.Value));
            obj.H.speed = uidropdown(toolbar,'Items',{'0.25x','0.5x','1x','2x','4x'}, ...
                'Value',sprintf('%gx',obj.Speed),'ValueChangedFcn',@(s,~)obj.setSpeedFromUi(s.Value));
            obj.H.staged = uicheckbox(toolbar,'Text','설명용 단계 재생','Value',obj.Staged, ...
                'ValueChangedFcn',@(s,~)obj.setStaged(s.Value));
            obj.H.follow = uicheckbox(toolbar,'Text','실시간 따라가기','Value',obj.FollowLive, ...
                'ValueChangedFcn',@(s,~)obj.setFollow(s.Value));
            obj.H.time = uilabel(toolbar,'Text','','FontSize',11);
            obj.H.strength = uidropdown(toolbar,'Items',{'간선 굵기: 균일','간선 굵기: 어텐션 계수 α', ...
                '간선 굵기: 가중 메시지 크기 |αWx|'},'Value','간선 굵기: 어텐션 계수 α', ...
                'ValueChangedFcn',@(s,~)obj.setStrengthFromUi(s.Value));
            names = [{'all'},obj.Trace.schema.relationNames];
            obj.H.filter = uidropdown(toolbar,'Items',names,'Value','all', ...
                'ValueChangedFcn',@(s,~)obj.setRelationFilter(s.Value));
            obj.H.self = uicheckbox(toolbar,'Text','자기 루프 표시','Value',obj.ShowSelf, ...
                'ValueChangedFcn',@(s,~)obj.setShowSelf(s.Value));
            uibutton(toolbar,'Text','PNG 저장','ButtonPushedFcn',@(~,~)obj.exportFromUi('png'));
            uibutton(toolbar,'Text','MP4 저장','ButtonPushedFcn',@(~,~)obj.exportFromUi('mp4'));
        end

        function buildStreams(obj,main)
            panel = uigridlayout(main,[2 1],'RowHeight',{'1x',230},'Padding',[0 0 0 0],'RowSpacing',4);
            ax = uiaxes(panel); obj.quiet(ax);
            lanes = {'카메라 프레임','ArUco 마커 검출','PnP 포즈 추정','KF 측정 갱신', ...
                'KF 시간 갱신(예측)','UAV 자체 항법 추정','정책 결정 (액터)','[평가 전용] 주입 누락'};
            ax.YLim = [0.4 numel(lanes)+0.6]; ax.YDir = 'reverse';
            ax.YTick = 1:numel(lanes); ax.YTickLabel = lanes; ax.FontSize = 9;
            ax.XLabel.String = '시뮬레이션 시각 [s]'; ax.Box = 'on'; hold(ax,'on'); grid(ax,'on');
            ax.Title.String = '원천별 사건 (데이터 시각 기준)'; ax.Title.FontSize = 10;
            C = obj.Colors;
            obj.H.laneDropout = patch(ax,NaN,NaN,[0.75 0.75 0.75],'FaceAlpha',0.35, ...
                'EdgeColor','none','HitTest','off');
            obj.H.lanes = struct( ...
                'frame',line(ax,NaN,NaN,'LineStyle','none','Marker','|','MarkerSize',9,'Color',C.camera), ...
                'markerValid',line(ax,NaN,NaN,'LineStyle','none','Marker','o','MarkerSize',4, ...
                    'MarkerFaceColor',C.accepted,'Color',C.accepted), ...
                'markerMissing',line(ax,NaN,NaN,'LineStyle','none','Marker','x','MarkerSize',6,'Color',C.missing), ...
                'pnpValid',line(ax,NaN,NaN,'LineStyle','none','Marker','o','MarkerSize',4, ...
                    'MarkerFaceColor',C.accepted,'Color',C.accepted), ...
                'pnpRejected',line(ax,NaN,NaN,'LineStyle','none','Marker','x','MarkerSize',6,'Color',C.missing), ...
                'kfMeasurement',line(ax,NaN,NaN,'LineStyle','none','Marker','s','MarkerSize',4, ...
                    'MarkerFaceColor',C.accepted,'Color',C.accepted), ...
                'kfTime',line(ax,NaN,NaN,'LineStyle','none','Marker','.','MarkerSize',9,'Color',C.predicted), ...
                'navigation',line(ax,NaN,NaN,'LineStyle','none','Marker','|','MarkerSize',9,'Color',C.navigation), ...
                'decision',line(ax,NaN,NaN,'LineStyle','none','Marker','^','MarkerSize',4, ...
                    'MarkerFaceColor',C.readout,'Color',C.readout));
            obj.H.laneCursor = xline(ax,0,'-','Color',[0.1 0.1 0.1],'LineWidth',1.2);
            names = fieldnames(obj.H.lanes);
            sourceOf = {'camera','marker','marker','pnp','pnp','kf','kf','navigation','actor'};
            for i = 1:numel(names)
                targetSource = sourceOf{i};
                if strcmp(targetSource,'actor'), focus = "action"; else, focus = "source:"+targetSource; end
                obj.H.lanes.(names{i}).ButtonDownFcn = @(~,~)obj.select(focus);
            end
            obj.H.streamAxes = ax;
            obj.H.status = uitextarea(panel,'Editable','off','FontSize',10.5,'FontName','Consolas');
        end

        function buildDiagram(obj,main)
            ax = uiaxes(main); obj.quiet(ax);
            ax.XLim = [0 124]; ax.YLim = [0 100]; ax.XTick = []; ax.YTick = [];
            ax.Box = 'on'; ax.XColor = [1 1 1]; ax.YColor = [1 1 1]; hold(ax,'on');
            ax.Title.String = '센서·추정기 데이터 흐름 → o_t → TOSM 노드 특징 → 단일 R-GAT 층 → 리드아웃 → 액터';
            ax.Title.FontSize = 11;
            obj.H.diagram = ax;
            S = obj.Trace.schema; P = obj.Trace.provenance; L = obj.Trace.labels; C = obj.Colors;
            G = struct();
            G.proc = [11 90; 11 77; 11 64; 11 51; 11 22];     % camera marker pnp kf navigation
            G.procSize = [17 8];
            nC = numel(P.channelNames);
            G.chan = [repmat(32,nC,1),(94-(0:nC-1)'*7.7)];
            G.chanSize = [17 5.4];
            G.node = [64 90; 52 70; 62 44; 72 64; 50 16; 80 24; 92 50];
            G.nodeRadius = 5.2;
            G.readout = [110 66]; G.actor = [110 50]; G.action = [110 32]; G.boxSize = [20 9];
            % layer labels
            text(ax,11,98.5,'(A) 원천·처리기','HorizontalAlignment','center','FontSize',9,'Color',[.4 .4 .4]);
            text(ax,32,98.5,'(B) o_t 12차원','HorizontalAlignment','center','FontSize',9,'Color',[.4 .4 .4]);
            text(ax,72,98.5,'(C) TOSM 노드 · 관계 간선 20개','HorizontalAlignment','center','FontSize',9,'Color',[.4 .4 .4]);
            text(ax,110,78,'리드아웃 · 액터','HorizontalAlignment','center','FontSize',9,'Color',[.4 .4 .4]);
            % (A) processor dataflow connectors
            seg = struct('id',{},'path',{},'phase',{},'kind',{});
            procIds = P.processors;
            pos = @(id)G.proc(strcmp(procIds,id),:);
            seg(end+1) = mk('cam-marker',obj.straight(pos('camera')-[0 4],pos('marker')+[0 4]),0,'camera');
            seg(end+1) = mk('marker-pnp',obj.straight(pos('marker')-[0 4],pos('pnp')+[0 4]),1,'detection');
            seg(end+1) = mk('pnp-kf',obj.straight(pos('pnp')-[0 4],pos('kf')+[0 4]),2,'kfMeasurement');
            seg(end+1) = mk('nav-pnp',obj.curve(pos('navigation')+[-8.5 2],pos('pnp')+[-8.5 -2],[-7 0]),1,'navAid');
            seg(end+1) = mk('nav-kf',obj.curve(pos('navigation')+[-5 4],pos('kf')+[-5 -4],[-3 0]),2,'navInit');
            theta = linspace(0.15*pi,1.85*pi,30)';
            seg(end+1) = mk('kf-time',pos('kf')+[11.5 0]+3.2*[cos(theta+pi) sin(theta+pi)],2,'kfTime');
            % (A)->(B) processor -> channel
            for k = 1:nC
                for p = find(P.channelSource(k,:))
                    from = pos(procIds{p})+[G.procSize(1)/2 0];
                    to = G.chan(k,:)-[G.chanSize(1)/2 0];
                    if strcmp(procIds{p},'kf'), kind = 'kfChannel'; else, kind = 'navChannel'; end
                    seg(end+1) = mk(sprintf('%s-ch%02d',procIds{p},k),obj.curve(from,to,[0 0]),3,kind); %#ok<AGROW>
                end
            end
            % (B)->(C) channel -> node feature derivations
            for k = 1:nC
                for n = find(P.channelToNode(k,:))
                    from = G.chan(k,:)+[G.chanSize(1)/2 0];
                    to = G.node(n,:)+G.nodeRadius*unit(G.chan(k,:)-G.node(n,:));
                    seg(end+1) = mk(sprintf('ch%02d-x%d',k,n),obj.curve(from,to,[0 0]),4,'derived'); %#ok<AGROW>
                end
            end
            % (C) typed R-GAT edges, curved; self loops
            for e = 1:S.nEdges
                i = S.src(e); j = S.dst(e);
                if i == j
                    c0 = G.node(i,:)+[0 G.nodeRadius+2.2];
                    t = linspace(-0.35*pi,1.35*pi,30)';
                    pts = c0+2.4*[cos(t) sin(t)];
                else
                    a = G.node(i,:); b = G.node(j,:); d = unit(b-a);
                    pts = obj.curve(a+G.nodeRadius*d,b-(G.nodeRadius+0.8)*d,0.12*norm(b-a)*[-d(2) d(1)]);
                end
                seg(end+1) = mk(sprintf('e%02d',e),pts,5,S.edgeOperator{e}); %#ok<AGROW>
            end
            % node -> readout -> actor -> action
            for n = 1:S.nNodes
                seg(end+1) = mk(sprintf('h%d-readout',n),obj.curve(G.node(n,:)+[G.nodeRadius 0], ...
                    G.readout-[G.boxSize(1)/2 0],[0 3]),6,'readout'); %#ok<AGROW>
            end
            seg(end+1) = mk('readout-actor',obj.straight(G.readout-[0 4.5],G.actor+[0 4.5]),6,'readout');
            seg(end+1) = mk('actor-action',obj.straight(G.actor-[0 4.5],G.action+[0 4.5]),6,'readout');
            G.seg = seg;
            obj.Geo = G;
            % draw connectors
            obj.H.seg = gobjects(1,numel(seg));
            for s = 1:numel(seg)
                [color,style,lineWidth] = obj.segmentStyle(seg(s).kind,false);
                obj.H.seg(s) = line(ax,seg(s).path(:,1),seg(s).path(:,2),'Color',color, ...
                    'LineStyle',style,'LineWidth',lineWidth);
                if isTypedEdge(seg(s).kind)
                    e = sscanf(seg(s).id,'e%d');
                    obj.H.seg(s).ButtonDownFcn = @(~,~)obj.select("edge:"+e);
                end
            end
            % arrowheads of typed edges
            obj.H.arrow = gobjects(1,S.nEdges);
            for e = 1:S.nEdges
                s = find(strcmp({seg.id},sprintf('e%02d',e)));
                p = seg(s).path; tip = p(end,:); d = unit(p(end,:)-p(end-2,:)); nrm = [-d(2) d(1)];
                [color] = obj.segmentStyle(seg(s).kind,false);
                obj.H.arrow(e) = patch(ax,[tip(1),tip(1)-1.8*d(1)+0.9*nrm(1),tip(1)-1.8*d(1)-0.9*nrm(1)], ...
                    [tip(2),tip(2)-1.8*d(2)+0.9*nrm(2),tip(2)-1.8*d(2)-0.9*nrm(2)],color, ...
                    'EdgeColor','none','HitTest','off');
            end
            % boxes
            obj.H.proc = gobjects(1,size(G.proc,1)); obj.H.procText = gobjects(1,size(G.proc,1));
            for p = 1:size(G.proc,1)
                [obj.H.proc(p),obj.H.procText(p)] = obj.drawBox(ax,G.proc(p,:),G.procSize, ...
                    sprintf('%s\n%s',L.sources(p).short,shortKind(L.sources(p).kind)),C.box,8.5);
                focus = "source:"+procIds{p};
                obj.H.proc(p).ButtonDownFcn = @(~,~)obj.select(focus);
                obj.H.procText(p).ButtonDownFcn = @(~,~)obj.select(focus);
            end
            markerBox = pos('marker');
            obj.H.missingMark = line(ax,markerBox(1)+10,markerBox(2),'LineStyle','none', ...
                'Marker','x','MarkerSize',12,'LineWidth',2,'Color',C.missing,'Visible','off');
            obj.H.chan = gobjects(1,nC); obj.H.chanText = gobjects(1,nC);
            for k = 1:nC
                [obj.H.chan(k),obj.H.chanText(k)] = obj.drawBox(ax,G.chan(k,:),G.chanSize, ...
                    L.channels(k).label,[1 1 1],8);
                obj.H.chan(k).ButtonDownFcn = @(~,~)obj.select("channel:"+k);
                obj.H.chanText(k).ButtonDownFcn = @(~,~)obj.select("channel:"+k);
            end
            t = linspace(0,2*pi,40);
            obj.H.node = gobjects(1,S.nNodes); obj.H.nodeText = gobjects(1,S.nNodes);
            obj.H.nodeAge = gobjects(1,S.nNodes);
            for n = 1:S.nNodes
                face = C.explicit; if strcmp(S.nodePerspective{n},'Implicit'), face = C.implicit; end
                obj.H.node(n) = patch(ax,G.node(n,1)+G.nodeRadius*cos(t),G.node(n,2)+G.nodeRadius*sin(t), ...
                    face,'EdgeColor',[0.3 0.3 0.3],'LineWidth',1.2);
                obj.H.nodeText(n) = text(ax,G.node(n,1),G.node(n,2)+1.2,sprintf('%s\n%s',S.nodeShort{n}, ...
                    S.nodePerspective{n}),'HorizontalAlignment','center','FontSize',8.5,'FontWeight','bold');
                obj.H.nodeAge(n) = text(ax,G.node(n,1),G.node(n,2)-G.nodeRadius-3.6,'', ...
                    'HorizontalAlignment','center','FontSize',7,'Color',C.predicted);
                obj.H.node(n).ButtonDownFcn = @(~,~)obj.select("node:"+n);
                obj.H.nodeText(n).ButtonDownFcn = @(~,~)obj.select("node:"+n);
            end
            % live 5-channel feature strip under each node (diverging colors)
            [vx,vy] = deal(zeros(4,5*S.nNodes));
            for n = 1:S.nNodes
                for f = 1:5
                    x0 = G.node(n,1)-4+(f-1)*1.6; y0 = G.node(n,2)-G.nodeRadius-2.2;
                    col = (n-1)*5+f;
                    vx(:,col) = [x0;x0+1.5;x0+1.5;x0]; vy(:,col) = [y0;y0;y0+1.6;y0+1.6];
                end
            end
            obj.H.featureStrip = patch(ax,vx,vy,ones(1,5*S.nNodes),'EdgeColor',[.5 .5 .5], ...
                'LineWidth',0.3,'HitTest','off');
            colormap(ax,diverging()); ax.CLim = [-1 1];
            [obj.H.readout,rt] = obj.drawBox(ax,G.readout,G.boxSize,sprintf('그래프 리드아웃\ng_A (16)'),[1 0.97 0.86],9);
            [obj.H.actor,at] = obj.drawBox(ax,G.actor,G.boxSize,sprintf('액터 MLP\n→ μ (tanh 이전)'),[1 0.97 0.86],9);
            [obj.H.action,actText] = obj.drawBox(ax,G.action,G.boxSize,'가속도 명령',[1 0.97 0.86],9);
            obj.H.actionText = actText;
            for pair = {{obj.H.readout,rt,"readout"},{obj.H.actor,at,"actor"},{obj.H.action,actText,"action"}}
                q = pair{1}; f = q{3};
                q{1}.ButtonDownFcn = @(~,~)obj.select(f); q{2}.ButtonDownFcn = @(~,~)obj.select(f);
            end
            % pulses
            obj.H.pulse = struct();
            kinds = {'camera','navigation','accepted','predicted','missing','derived', ...
                'propagate','modulate','readout'};
            markers = {'o','o','o','o','x','.','o','d','o'};
            for i = 1:numel(kinds)
                face = obj.Colors.(kinds{i});
                if strcmp(kinds{i},'modulate'), face = 'none'; end
                obj.H.pulse.(kinds{i}) = line(ax,NaN,NaN,'LineStyle','none','Marker',markers{i}, ...
                    'MarkerSize',6,'Color',obj.Colors.(kinds{i}),'MarkerFaceColor',face, ...
                    'LineWidth',1.5,'HitTest','off');
            end
            obj.H.pulse.plus = line(ax,NaN,NaN,'LineStyle','none','Marker','+','MarkerSize',5, ...
                'Color',[1 1 1],'LineWidth',1.2,'HitTest','off');
            obj.H.ripple = line(ax,NaN,NaN,'Color',C.modulate,'LineWidth',1.5,'LineStyle','--','HitTest','off');
            obj.H.phaseText = text(ax,62,3.5,'','HorizontalAlignment','center','FontSize',9,'Color',[.3 .3 .3]);
            obj.H.tooltip = text(ax,0,0,'','FontSize',8.5,'BackgroundColor',[1 1 0.9], ...
                'EdgeColor',[.5 .5 .5],'Visible','off','HitTest','off','Interpreter','none', ...
                'VerticalAlignment','top');
            obj.Figure.WindowButtonMotionFcn = @(~,~)obj.hover();
        end

        function buildNumeric(obj,main)
            tabs = uitabgroup(main);
            actorTab = uitab(tabs,'Title','액터 (Actor) 수치');
            criticTab = uitab(tabs,'Title','크리틱 (Critic)');
            actorGrid = uigridlayout(actorTab,[4 2],'RowHeight',{'1.5x','1x','1x','0.9x'}, ...
                'Padding',[2 2 2 2],'RowSpacing',3,'ColumnSpacing',3);
            S = obj.Trace.schema;
            ax = uiaxes(actorGrid); obj.quiet(ax); ax.Layout.Row = 1; ax.Layout.Column = [1 2];
            hold(ax,'on');
            colors = repmat(obj.Colors.propagate,S.nEdges,1);
            colors(S.edgePool==2,:) = repmat(obj.Colors.modulate,sum(S.edgePool==2),1);
            nLayers = obj.layerCount();
            if nLayers == 1
                obj.H.alphaBars = bar(ax,1:S.nEdges,zeros(1,S.nEdges),'FaceColor','flat','CData',colors, ...
                    'EdgeColor','none');
            else
                obj.H.alphaBars = bar(ax,1:S.nEdges,zeros(S.nEdges,nLayers),'grouped','EdgeColor','none');
                shades = [obj.Colors.propagate;0.45*obj.Colors.propagate;0.7*[1 1 1]];
                for l = 1:nLayers, obj.H.alphaBars(l).FaceColor = shades(min(l,3),:); end
            end
            ax.XTick = 1:S.nEdges; ax.XTickLabel = S.edgeLabel; ax.XTickLabelRotation = 60;
            ax.FontSize = 7.5; ax.YLim = [0 1.05];
            ax.Title.String = '어텐션 계수 α_ij (청록 = 전파+자기 루프 풀, 보라 = 조절 풀; 도착 노드별 합 1)';
            if obj.isV2()
                ax.Title.String = '어텐션 계수 α_ij — 밝은 막대 층 1, 어두운 막대 층 2 (층마다 도착 노드별 모든 간선 합 1)';
            end
            ax.Title.FontSize = 8.5; obj.H.alphaAxes = ax;
            for b = obj.H.alphaBars(:)'
                b.ButtonDownFcn = @(src,event)obj.select("edge:"+round(event.IntersectionPoint(1)));
            end
            ax = uiaxes(actorGrid); obj.quiet(ax); ax.Layout.Row = 2; ax.Layout.Column = 1;
            obj.H.xImage = imagesc(ax,zeros(6,7)); ax.CLim = [-1 1]; colormap(ax,diverging());
            obj.styleMatrix(ax,'노드 특징 X_t (6×7)',S.nodeShort,{'f1','f2','f3','f4','f5','id'});
            ax = uiaxes(actorGrid); obj.quiet(ax); ax.Layout.Row = 2; ax.Layout.Column = 2;
            obj.H.hImage = imagesc(ax,zeros(16,7)); ax.CLim = [-2 2]; colormap(ax,diverging());
            obj.styleMatrix(ax,'노드 임베딩 H_t (16×7)',S.nodeShort,[]);
            ax = uiaxes(actorGrid); obj.quiet(ax); ax.Layout.Row = 3; ax.Layout.Column = 1;
            obj.H.gateImage = imagesc(ax,ones(16,7)); ax.CLim = [0 2]; colormap(ax,diverging());
            obj.styleMatrix(ax,'조절 게이트 1+tanh(Z_mod) (1 = 조절 없음)',S.nodeShort,[]);
            if obj.isV2()
                ax.CLim = [-1 1];
                ax.Title.String = '층 1 노드 임베딩 H^1 (16×7) — rgat_v2에는 게이트 없음';
                obj.H.hImage.Parent.CLim = [-1 1];
                obj.H.hImage.Parent.Title.String = '최종 노드 임베딩 H^2 (16×7, 리드아웃 입력)';
            end
            ax = uiaxes(actorGrid); obj.quiet(ax); ax.Layout.Row = 3; ax.Layout.Column = 2;
            obj.H.gBars = bar(ax,zeros(1,S.graphDim),'FaceColor',obj.Colors.readout,'EdgeColor','none');
            ax.YLim = [-1 1]; ax.FontSize = 7.5; ax.Title.String = '액터 그래프 임베딩 g_t^A (16)';
            ax.Title.FontSize = 8.5;
            ax = uiaxes(actorGrid); obj.quiet(ax); ax.Layout.Row = 4; ax.Layout.Column = 1;
            obj.H.actionBars = bar(ax,[0 0],'FaceColor','flat','CData',[obj.Colors.readout;obj.Colors.readout], ...
                'EdgeColor','none');
            limits = obj.Trace.context.actionLimits;
            hold(ax,'on'); ax.XTickLabel = {'a_x','a_z'}; ax.YLim = [-max(limits) max(limits)]*1.05;
            yline(ax,[-limits(1) limits(1)],':','Color',[.5 .5 .5]);
            ax.FontSize = 8; ax.Title.String = '요구 가속도 [m/s^2]'; ax.Title.FontSize = 8.5;
            obj.H.actionInfo = uitextarea(actorGrid,'Editable','off','FontSize',9.5,'FontName','Consolas');
            obj.H.actionInfo.Layout.Row = 4; obj.H.actionInfo.Layout.Column = 2;
            cgrid = uigridlayout(criticTab,[2 1],'RowHeight',{'1x',90});
            ax = uiaxes(cgrid); obj.quiet(ax);
            obj.H.criticBars = bar(ax,zeros(1,S.graphDim),'FaceColor',[.45 .45 .45],'EdgeColor','none');
            ax.YLim = [-1 1]; ax.Title.String = '크리틱 그래프 임베딩 g_t^V (16)';
            obj.H.criticInfo = uitextarea(cgrid,'Editable','off','FontSize',10.5);
        end

        % ------------------------------------------------------------ update
        function updatePanels(obj,k)
            r = obj.Trace.records(k); S = obj.Trace.schema; A = r.actor;
            switch obj.StrengthMode
                case 'message', barValues = A.weightedMessageNormLayers;
                otherwise, barValues = A.alphaLayers;
            end
            for l = 1:numel(obj.H.alphaBars), obj.H.alphaBars(l).YData = barValues(:,l)'; end
            obj.H.alphaAxes.YLim = [0 max(1.05,1.05*max(barValues,[],'all'))];
            obj.H.xImage.CData = r.graph.X;
            obj.H.hImage.CData = A.H;
            obj.H.gateImage.CData = A.gate;
            if obj.isV2(), obj.H.gateImage.CData = A.layerH{1}; end
            obj.H.gBars.YData = A.g(:)';
            obj.H.actionBars.YData = r.command.requestedAcceleration(:)';
            obj.H.actionInfo.Value = { ...
                sprintf('μ (tanh 이전)  [%+.3f %+.3f]',A.mu); ...
                sprintf('u (사용 표본)  [%+.3f %+.3f]%s',A.preTanhAction,ternary(A.sampled,' 확률적',' = μ')); ...
                sprintf('tanh(u)        [%+.3f %+.3f]',A.normalizedAction); ...
                sprintf('요구 a [m/s²]  [%+.3f %+.3f]',r.command.requestedAcceleration); ...
                sprintf('적용 평균      [%+.3f %+.3f]',r.command.appliedAccelerationIntervalMean); ...
                sprintf('[평가] 실제    [%+.3f %+.3f]',r.evaluation.realizedAccelerationMean)};
            obj.H.criticBars.YData = r.critic.g(:)';
            obj.H.criticInfo.Value = {sprintf('V(s_t) = %+.3f  (결정 #%d, t = %.2f s)',r.critic.value,k,r.time); ...
                '크리틱은 PPO 학습의 가치 추정이며 실행 중 행동 선택에 쓰이지 않습니다.'};
            obj.H.actionText.String = sprintf('가속도 명령\n[%+.2f, %+.2f]',r.command.requestedAcceleration);
            % feature strip and node freshness
            strip = r.graph.X(1:5,:);
            obj.H.featureStrip.CData = strip(:)';
            status = landing2d.trace.channelStatus(obj.Trace,k);
            P = obj.Trace.provenance;
            for n = 1:S.nNodes
                codes = status.code(P.channelToNode(:,n));
                if any(codes=="predicted")
                    obj.H.node(n).LineStyle = '--';
                    obj.H.nodeAge(n).String = sprintf('예측 기반 %.2f s',r.time-r.sensing.kf.lastUpdateTime);
                elseif any(codes=="none")
                    obj.H.node(n).LineStyle = ':'; obj.H.nodeAge(n).String = '추정 없음';
                else
                    obj.H.node(n).LineStyle = '-'; obj.H.nodeAge(n).String = '';
                end
            end
            for c = 1:numel(status.code)
                switch status.code(c)
                    case "measured", face = [0.88 0.97 0.90];
                    case "predicted", face = [0.93 0.93 0.93];
                    case "none", face = [0.98 0.90 0.90];
                    case "navigation", face = [0.92 0.90 0.99];
                    otherwise, face = [1 1 1];
                end
                obj.H.chan(c).FaceColor = face;
            end
            obj.H.missingMark.Visible = onOff(r.sensing.camera.frameCaptured && r.sensing.camera.markerCount==0);
            % edge widths by strength mode, relation filter, self loops
            for e = 1:S.nEdges
                s = obj.segIndex(sprintf('e%02d',e));
                switch obj.StrengthMode
                    case 'uniform', w = 1.6;
                    case 'message', w = 0.6+5*mean(A.weightedMessageNormLayers(e,:))/max(mean(A.weightedMessageNormLayers,2));
                    otherwise, w = 0.6+4*mean(A.alphaLayers(e,:));
                end
                obj.H.seg(s).LineWidth = w;
                isSelf = S.src(e)==S.dst(e);
                shown = (~isSelf || obj.ShowSelf);
                obj.H.seg(s).Visible = onOff(shown); obj.H.arrow(e).Visible = onOff(shown);
            end
            obj.H.banner.Value = {landing2d.trace.explainDecision(obj.Trace,k).banner};
            obj.updateStatus(k);
            obj.H.laneCursor.Value = r.time;
            obj.H.streamAxes.XLim = [r.time-4 r.time+1];
        end

        function updateStatus(obj,k)
            r = obj.Trace.records(k); s = r.sensing; E = obj.Trace.events; t = r.time;
            rate = @(type)observedRate(E,type,t);
            content = { ...
                sprintf('카메라 프레임 (측정원)'); ...
                sprintf('  마지막 %s  Δt %s  %s', stampText(s.camera.stamp), ...
                    numText(lastGap(E,"camera_frame",t),'%.2f s'),numText(rate("camera_frame"),'%.1f Hz')); ...
                sprintf('  프레임 %s  마커 %d개 %s',ternary(s.camera.frameCaptured,'유효','없음'), ...
                    s.camera.markerCount,idsText(s.camera.markerIds)); ...
                sprintf('ArUco 마커 검출 · PnP (처리기)'); ...
                sprintf('  PnP %s  재투영 %s', pnpText(s.pnp),numText(s.pnp.reprojectionRms,'%.2f px')); ...
                sprintf('UGV 칼만 필터 (상태 추정기)'); ...
                sprintf('  %s  마지막 측정 %s  경과 %s',kfText(s.kf.update),stampText(s.kf.lastUpdateTime), ...
                    numText(t-s.kf.lastUpdateTime,'%.2f s')); ...
                sprintf('UAV 자체 항법 추정'); ...
                sprintf('  마지막 %s  %s  %s',stampText(s.navigation.stamp), ...
                    numText(rate("own_navigation_update"),'%.1f Hz'),ternary(s.navigation.valid,'유효','무효')); ...
                sprintf('  v = [%+.2f %+.2f] m/s',s.navigation.velocityXZ); ...
                sprintf('정책 결정 #%d  t = %.2f s  %s',k,t,numText(rate("actor_action_decided"),'%.1f Hz'))};
            if r.evaluation.injectedDropout
                content{end+1} = '[평가 전용] 외부 주입 마커 누락 구간';
            end
            obj.H.status.Value = content;
        end

        function refreshTimeline(obj)
            E = obj.Trace.events;
            if isempty(E), return; end
            lanes = {'frame',"camera_frame",1;'markerValid',"marker_valid",2;'markerMissing',"marker_missing",2; ...
                'pnpValid',"pnp_valid",3;'pnpRejected',"pnp_rejected",3;'kfMeasurement',"kf_measurement_update",4; ...
                'kfTime',"kf_time_update",5;'navigation',"own_navigation_update",6;'decision',"actor_action_decided",7};
            for i = 1:size(lanes,1)
                t = E.Time_s(E.Type==lanes{i,2});
                obj.H.lanes.(lanes{i,1}).XData = t; obj.H.lanes.(lanes{i,1}).YData = lanes{i,3}*ones(size(t));
            end
            ev = obj.Trace.evaluationOnly.sensorEvents;
            if isfinite(ev.dropoutStart)
                obj.H.laneDropout.XData = [ev.dropoutStart ev.dropoutEnd ev.dropoutEnd ev.dropoutStart];
                obj.H.laneDropout.YData = [7.6 7.6 8.4 8.4];
            end
        end

        function updateSlider(obj)
            if isempty(obj.Trace.records), return; end
            times = [obj.Trace.records.time];
            obj.H.slider.Limits = [times(1) max(times(end),times(1)+1e-3)+obj.policyDt()];
        end

        function updateClock(obj,k,phase)
            r = obj.Trace.records(k);
            names = obj.PhaseNames;
            if obj.isV2(), names{6} = sprintf('5 R-GAT 순전파 (층 1 → 층 %d)',obj.layerCount()); end
            if obj.Staged && phase >= 0
                obj.H.time.Text = sprintf('결정 #%d  t_k = %.2f s | 설명용 단계 %s (같은 결정 시각, 물리 지연 아님)', ...
                    k,r.time,names{phase+1});
            else
                obj.H.time.Text = sprintf('표시 t = %.2f s | 결정 #%d (t_k = %.2f s) | %gx', ...
                    obj.DisplayTime,k,r.time,obj.Speed);
            end
            simultaneous = '같은 결정 시각의 계산은 동시에 표시 (R-GAT 간선 메시지는 단일 층 동시 집계)';
            if obj.isV2()
                simultaneous = sprintf(['같은 결정 시각의 계산은 동시에 표시 (R-GAT %d개 층, 층마다 모든 간선 ' ...
                    '동시 집계; 펄스 앞 절반 = 층 1, 뒤 절반 = 층 2)'],obj.layerCount());
            end
            obj.H.phaseText.String = ternary(obj.Staged && phase >= 0, ...
                ['단계 ',names{max(phase,0)+1},' — 같은 결정 시각 t_k의 계산을 펼친 설명용 순서'], ...
                simultaneous);
            if ~isvalid(obj.H.slider), return; end
            limits = obj.H.slider.Limits;
            obj.H.slider.Value = min(max(r.time,limits(1)),limits(2));
        end

        function updatePulses(obj,k,phase,progress)
        % Pulses only on segments whose computation really happened at decision k.
            r = obj.Trace.records(k); s = r.sensing; seg = obj.Geo.seg; S = obj.Trace.schema;
            buckets = struct('camera',[],'navigation',[],'accepted',[],'predicted',[], ...
                'missing',[],'derived',[],'propagate',[],'modulate',[],'readout',[]);
            ripple = [];
            status = landing2d.trace.channelStatus(obj.Trace,k);
            for i = 1:numel(seg)
                [active,bucket] = obj.segmentActive(seg(i),s,status,S);
                if ~active, continue; end
                if phase >= 0 && seg(i).phase ~= phase, continue; end
                u = progress;
                % rgat_v2: the same edge carries a layer-1 message (first
                % half of the edge interval) and a layer-2 message (second).
                if seg(i).phase == 5 && obj.layerCount() > 1
                    u = mod(progress*obj.layerCount(),1);
                end
                point = pointAt(seg(i).path,u);
                buckets.(bucket)(end+1,:) = point;
                if strcmp(bucket,'modulate') && u > 0.75
                    e = sscanf(seg(i).id,'e%d'); c0 = obj.Geo.node(S.dst(e),:);
                    radius = obj.Geo.nodeRadius*(1+0.6*(u-0.75)/0.25);
                    t = linspace(0,2*pi,24)';
                    ripple = [ripple; c0+radius*[cos(t) sin(t)]; NaN NaN]; %#ok<AGROW>
                end
            end
            names = fieldnames(buckets);
            for i = 1:numel(names)
                p = buckets.(names{i});
                if isempty(p), p = [NaN NaN]; end
                obj.H.pulse.(names{i}).XData = p(:,1); obj.H.pulse.(names{i}).YData = p(:,2);
            end
            p = buckets.propagate; if isempty(p), p = [NaN NaN]; end
            obj.H.pulse.plus.XData = p(:,1); obj.H.pulse.plus.YData = p(:,2);
            if isempty(ripple), ripple = [NaN NaN]; end
            obj.H.ripple.XData = ripple(:,1); obj.H.ripple.YData = ripple(:,2);
            if phase == 7 || phase < 0
                obj.H.banner.BackgroundColor = ternary(phase==7 && progress < 0.5,[1 0.98 0.85],[1 1 1]);
            end
        end

        function [active,bucket] = segmentActive(obj,sg,s,status,S)
            active = true; bucket = 'derived';
            kind = sg.kind;
            switch kind
                case 'camera', active = s.camera.frameCaptured; bucket = 'camera';
                case 'detection'
                    active = s.pnp.attempted;
                    bucket = ternary(s.pnp.valid,'accepted','missing');
                case 'kfMeasurement'
                    active = any(strcmp(s.kf.update,{'measurement_update','initialization'})); bucket = 'accepted';
                case 'kfTime', active = strcmp(s.kf.update,'time_update'); bucket = 'predicted';
                case 'navAid', active = s.navigation.valid && s.pnp.attempted; bucket = 'navigation';
                case 'navInit', active = strcmp(s.kf.update,'initialization'); bucket = 'navigation';
                case 'kfChannel'
                    k = sscanf(sg.id,'kf-ch%d');
                    active = status.code(k) ~= "none";
                    bucket = ternary(status.code(k)=="measured",'accepted','predicted');
                case 'navChannel', active = s.navigation.valid; bucket = 'navigation';
                case 'derived', bucket = 'derived';
                case {'propagate','modulate','message'}
                    e = sscanf(sg.id,'e%d');
                    isSelf = S.src(e)==S.dst(e);
                    active = (~isSelf || obj.ShowSelf) && (strcmp(obj.RelationFilter,'all') ...
                        || strcmp(obj.RelationFilter,S.relationNames{S.rel(e)}));
                    bucket = kind;
                    if strcmp(kind,'message'), bucket = 'propagate'; end
                case 'readout', bucket = 'readout';
            end
            active = logical(active);
        end

        function updateChain(obj)
            if isempty(obj.Focus) || isempty(obj.Trace.records), return; end
            k = max(obj.Decision,1);
            obj.Chain = landing2d.trace.selectionChain(obj.Trace,k,obj.Focus,obj.Dep);
            content = obj.Chain.lines;
            if any(ismember(obj.Chain.focus,["action","actor","readout","x:7","h:7"]))
                X = landing2d.trace.explainDecision(obj.Trace,k);
                fullChain = {'', '===== 전체 근거 사슬 (full end-to-end chain) ====='};
                for i = 1:size(X.sections,1)
                    fullChain = [fullChain,X.sections(i,1),strcat({'  '},X.sections{i,2})]; %#ok<AGROW>
                end
                content = [content;fullChain(:)];
            end
            obj.H.chain.Value = content;
        end

        function applyHighlight(obj)
            seg = obj.Geo.seg; C = obj.Colors; S = obj.Trace.schema;
            if isempty(obj.Focus) || isempty(obj.Chain)
                mask = true(1,numel(obj.Dep.ids));
            else
                mask = obj.Chain.mask;
            end
            on = @(id)any(mask(obj.Dep.ids==id));
            hasRecord = ~isempty(obj.Trace.records);
            if hasRecord
                k = max(obj.Decision,1); sensing = obj.Trace.records(k).sensing;
                status = landing2d.trace.channelStatus(obj.Trace,k);
            end
            for i = 1:numel(seg)
                lit = obj.segmentLit(seg(i).id,on,S);
                [color,style,lineWidth] = obj.segmentStyle(seg(i).kind,~lit);
                % A computation that did not happen at this decision (no
                % frame, no detection, rejected PnP, no measurement update,
                % filtered relation) is drawn dotted light gray, never lit.
                if hasRecord && ~obj.segmentActive(seg(i),sensing,status,S)
                    color = [0.82 0.82 0.82]; style = ':';
                end
                obj.H.seg(i).Color = color; obj.H.seg(i).LineStyle = style;
                if ~isTypedEdge(seg(i).kind), obj.H.seg(i).LineWidth = lineWidth; end
                if isTypedEdge(seg(i).kind)
                    e = sscanf(seg(i).id,'e%d'); obj.H.arrow(e).FaceColor = color;
                end
            end
            for p = 1:numel(obj.H.proc)
                lit = on("src:"+obj.Trace.provenance.processors{p});
                obj.H.proc(p).EdgeColor = ternary(lit && ~isempty(obj.Focus),[0 0 0],[.6 .6 .6]);
                obj.H.proc(p).LineWidth = ternary(lit && ~isempty(obj.Focus),2,0.8);
                obj.H.procText(p).Color = ternary(lit,C.text,[.7 .7 .7]);
            end
            for k = 1:numel(obj.H.chan)
                lit = on(compose("ch:%02d",k));
                obj.H.chanText(k).Color = ternary(lit,C.text,[.75 .75 .75]);
                obj.H.chan(k).EdgeColor = ternary(lit && ~isempty(obj.Focus),[0 0 0],[.7 .7 .7]);
            end
            for n = 1:S.nNodes
                lit = on(compose("x:%d",n)) || any(arrayfun(@(l)on(compose("h%d:%d",l,n)),1:obj.layerCount()));
                obj.H.nodeText(n).Color = ternary(lit,C.text,[.7 .7 .7]);
                obj.H.node(n).EdgeColor = ternary(lit && ~isempty(obj.Focus),[0 0 0],[.3 .3 .3]);
                obj.H.node(n).LineWidth = ternary(lit && ~isempty(obj.Focus),2.4,1.2);
            end
            for pair = {{obj.H.readout,"readout"},{obj.H.actor,"actor"},{obj.H.action,"action"}}
                q = pair{1}; lit = on(q{2});
                q{1}.EdgeColor = ternary(lit && ~isempty(obj.Focus),[0 0 0],[.6 .6 .6]);
                q{1}.LineWidth = ternary(lit && ~isempty(obj.Focus),2,0.8);
            end
        end

        function lit = segmentLit(obj,id,on,S)
            if startsWith(id,'e')
                e = sscanf(id,'e%d'); lit = any(arrayfun(@(l)on(compose("e%d:%02d",l,e)),1:obj.layerCount()));
            elseif startsWith(id,'ch')
                v = sscanf(id,'ch%d-x%d'); lit = on(compose("ch:%02d",v(1))) && on(compose("x:%d",v(2)));
            elseif startsWith(id,'h')
                n = sscanf(id,'h%d'); lit = on(compose("h%d:%d",obj.layerCount(),n)) && on("readout");
            elseif any(strcmp(id,{'readout-actor','actor-action'}))
                lit = on("actor");
            elseif contains(id,'-ch')
                parts = split(string(id),'-ch'); k = str2double(parts(2));
                lit = on("src:"+parts(1)) && on(compose("ch:%02d",k));
            else
                map = struct('cam_marker',["src:camera","src:marker"],'marker_pnp',["src:marker","src:pnp"], ...
                    'pnp_kf',["src:pnp","src:kf"],'nav_pnp',["src:navigation","src:pnp"], ...
                    'nav_kf',["src:navigation","src:kf"],'kf_time',["src:kf","src:kf"]);
                ends = map.(strrep(id,'-','_'));
                lit = on(ends(1)) && on(ends(2));
            end
            if isempty(obj.Focus), lit = true; end
            lit = lit && (S.nNodes > 0);
        end

        function [color,style,lineWidth] = segmentStyle(obj,kind,faded)
            C = obj.Colors; style = '-';
            switch kind
                case 'camera', color = C.camera; lineWidth = 1.6;
                case 'detection', color = C.accepted; lineWidth = 1.6;
                case 'kfMeasurement', color = C.accepted; lineWidth = 1.8;
                case 'kfTime', color = C.predicted; style = ':'; lineWidth = 1.4;
                case {'navAid','navInit'}, color = C.navigation; style = '--'; lineWidth = 1;
                case 'kfChannel', color = C.accepted; lineWidth = 0.8;
                case 'navChannel', color = C.navigation; lineWidth = 0.6;
                case 'derived', color = C.derived; style = '--'; lineWidth = 0.6;
                case {'propagate','message'}, color = C.propagate; lineWidth = 1.6;
                case 'modulate', color = C.modulate; style = '--'; lineWidth = 1.6;
                otherwise, color = C.readout; lineWidth = 1;
            end
            if faded, color = C.faded; end
        end

        function hover(obj)
            try
                ax = obj.H.diagram; cp = ax.CurrentPoint(1,1:2);
                if any(cp < [ax.XLim(1) ax.YLim(1)]) || any(cp > [ax.XLim(2) ax.YLim(2)]) ...
                        || isempty(obj.Trace.records)
                    obj.H.tooltip.Visible = 'off'; return;
                end
                k = max(obj.Decision,1); r = obj.Trace.records(k); S = obj.Trace.schema; A = r.actor;
                G = obj.Geo; label = '';
                d = vecnorm(G.node-cp,2,2); [dn,n] = min(d);
                if dn < G.nodeRadius
                    label = sprintf('%s (%s, %s)\nX = %s\n|H| = %.3f, 게이트 평균 %.3f\n리드아웃 참여 (7개 노드 모두)', ...
                        S.nodeNames{n},S.nodePerspective{n},S.nodeLabel{n},mat2str(round(r.graph.X(1:5,n)',3)), ...
                        norm(A.H(:,n)),mean(A.gate(:,n)));
                else
                    best = Inf; e = 0;
                    for i = 1:S.nEdges
                        s = obj.segIndex(sprintf('e%02d',i));
                        if strcmp(obj.H.seg(s).Visible,'off'), continue; end
                        dist = min(vecnorm(G.seg(s).path-cp,2,2));
                        if dist < best, best = dist; e = i; end
                    end
                    if best < 1.6
                        layerText = strjoin(arrayfun(@(l)sprintf('층 %d: α = %.3f, |W h| = %.3f, |α W h| = %.3f', ...
                            l,A.alphaLayers(e,l),A.projectedMessageNormLayers(e,l), ...
                            A.weightedMessageNormLayers(e,l)),1:size(A.alphaLayers,2),'UniformOutput',false),newline);
                        label = sprintf(['간선 %02d %s → %s\n관계 유형 %s: %s\n연산 %s, 풀 %s\n%s\n' ...
                            '최근 순전파 t = %.2f s (결정 #%d)\n구조적 도달: H_%s → 리드아웃 (비인과)'], ...
                            e,S.nodeNames{S.src(e)},S.nodeNames{S.dst(e)},S.relationNames{S.rel(e)}, ...
                            S.edgePurposeKo{e},S.edgeOperator{e},S.poolNames{S.edgePool(e)},layerText, ...
                            r.time,k,S.nodeShort{S.dst(e)});
                    end
                end
                if isempty(label), obj.H.tooltip.Visible = 'off'; return; end
                obj.H.tooltip.Position = [min(cp(1)+1.5,92) min(cp(2)+1,98) 0];
                obj.H.tooltip.String = label; obj.H.tooltip.Visible = 'on';
            catch
            end
        end

        % ----------------------------------------------------------- helpers
        function i = segIndex(obj,id), i = find(strcmp({obj.Geo.seg.id},id),1); end

        function ids = activeSegmentIds(obj)
            ids = {};
            if isempty(obj.Trace.records), return; end
            k = max(obj.Decision,1); s = obj.Trace.records(k).sensing;
            status = landing2d.trace.channelStatus(obj.Trace,k);
            for i = 1:numel(obj.Geo.seg)
                [active,bucket] = obj.segmentActive(obj.Geo.seg(i),s,status,obj.Trace.schema);
                if active, ids{end+1} = [obj.Geo.seg(i).id,':',bucket]; end %#ok<AGROW>
            end
        end

        function ids = highlightedIds(obj)
            if isempty(obj.Chain), ids = strings(1,0); else, ids = obj.Chain.vertices; end
        end

        function togglePlay(obj)
            if obj.Playing, obj.pause(); else, obj.play(); end
        end

        function setSpeedFromUi(obj,value), obj.Speed = sscanf(value,'%fx'); end
        function setFollow(obj,value), obj.FollowLive = logical(value); end

        function setStrengthFromUi(obj,value)
            if contains(value,'균일'), m = 'uniform'; elseif contains(value,'메시지'), m = 'message'; else, m = 'alpha'; end
            obj.StrengthMode = m; obj.ShownDecision = -1; obj.render();
        end

        function label = strengthLabel(~,mode)
            switch mode
                case 'uniform', label = '간선 굵기: 균일';
                case 'message', label = '간선 굵기: 가중 메시지 크기 |αWx|';
                otherwise, label = '간선 굵기: 어텐션 계수 α';
            end
        end

        function exportFromUi(obj,kind)
            folder = fullfile(landing2d.orchestration.projectRoot(),'results','trace');
            if ~isfolder(folder), mkdir(folder); end
            stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
            if strcmp(kind,'png')
                file = fullfile(folder,sprintf('dashboard_%s.png',stamp)); obj.exportPng(file);
            else
                file = fullfile(folder,sprintf('dashboard_%s.mp4',stamp)); obj.exportVideo(file);
            end
            uialert(obj.Figure,file,'저장됨','Icon','success');
        end

        function label = modeText(obj)
            id = obj.Trace.identity;
            status = ''; if isfield(id,'modelStatus'), status = id.modelStatus; end
            switch obj.Mode
                case 'live', prefix = 'LIVE — 시뮬레이션 진행 중 기록';
                case 'test', prefix = 'TEST ONLY — 학습되지 않은 모의 에이전트 (학습된 정책 추론 아님)';
                otherwise, prefix = 'REPLAY — 저장된 추적 재생 (시뮬레이션·신경망 재실행 없음)';
            end
            label = sprintf('%s | %s | %s | 시드 %d | 그래프 %s…',prefix,status, ...
                fieldOr(id,'scenarioId',''),fieldOr(id,'episodeSeed',NaN), ...
                obj.Trace.schema.graphHash(1:min(12,end)));
        end

        function color = modeColor(obj)
            if strcmp(obj.Mode,'test'), color = [0.8 0 0]; else, color = [0.1 0.1 0.1]; end
        end

        function quiet(~,ax)
            try, disableDefaultInteractivity(ax); catch, end
            try, ax.Toolbar.Visible = 'off'; catch, end
            ax.Interactions = [];
        end

        function styleMatrix(~,ax,titleText,columns,rows)
            ax.XTick = 1:numel(columns); ax.XTickLabel = columns; ax.FontSize = 7.5;
            if isempty(rows), ax.YTick = [1 8 16]; else, ax.YTick = 1:numel(rows); ax.YTickLabel = rows; end
            ax.Title.String = titleText; ax.Title.FontSize = 8.5; axis(ax,'tight');
        end

        function [handle,label] = drawBox(~,ax,center,boxSize,textValue,face,fontSize)
            x = center(1)-boxSize(1)/2; y = center(2)-boxSize(2)/2;
            handle = rectangle(ax,'Position',[x y boxSize],'Curvature',0.25,'FaceColor',face, ...
                'EdgeColor',[.6 .6 .6],'LineWidth',0.8);
            label = text(ax,center(1),center(2),textValue,'HorizontalAlignment','center', ...
                'VerticalAlignment','middle','FontSize',fontSize,'Interpreter','none');
        end

        function pts = straight(~,a,b)
            u = linspace(0,1,20)'; pts = a+u.*(b-a);
        end

        function pts = curve(~,a,b,bend)
            u = linspace(0,1,30)'; m = (a+b)/2+bend;
            pts = (1-u).^2.*a+2*(1-u).*u.*m+u.^2.*b;
        end
    end
end

% ----------------------------------------------------------------- local
function s = mk(id,pts,phase,kind)
s = struct('id',id,'path',pts,'phase',phase,'kind',kind);
end

function out = merge(base,in)
out = base; keys = fieldnames(in);
for i = 1:numel(keys), out.(keys{i}) = in.(keys{i}); end
end

function tf = isTypedEdge(kind)
tf = any(strcmp(kind,{'propagate','modulate','message'}));
end

function v = unit(v)
v = v/max(norm(v),eps);
end

function p = pointAt(pts,u)
d = [0;cumsum(vecnorm(diff(pts),2,2))];
targetSource = u*d(end);
i = find(d <= targetSource,1,'last'); i = min(i,size(pts,1)-1);
w = (targetSource-d(i))/max(d(i+1)-d(i),eps);
p = pts(i,:)+w*(pts(i+1,:)-pts(i,:));
end

function m = diverging()
n = 128; a = linspace(0,1,n)';
blue = [0.19 0.40 0.74]; red = [0.80 0.25 0.20]; white = [0.97 0.97 0.97];
m = [blue+(white-blue).*a; white+(red-white).*a];
end

function out = ternary(condition,a,b)
if condition, out = a; else, out = b; end
end

function s = onOff(value)
if value, s = 'on'; else, s = 'off'; end
end

function value = fieldOr(s,name,default)
value = default;
if isfield(s,name), value = s.(name); end
end

function label = shortKind(kind)
if contains(kind,'센서 아님'), label = '(처리기)'; elseif contains(kind,'항법'), label = '(항법 추정)'; else, label = '(측정원)'; end
end

function label = stampText(t)
if isfinite(t), label = sprintf('%.2f s',t); else, label = '없음'; end
end

function label = numText(x,format)
if isfinite(x), label = sprintf(format,x); else, label = '—'; end
end

function label = idsText(ids)
if isempty(ids), label = ''; else, label = sprintf('(ID %s)',strjoin(string(ids),',')); end
end

function label = pnpText(p)
if p.attempted && p.valid, label = '채택'; elseif p.attempted, label = '기각'; else, label = '미수행'; end
end

function label = kfText(update)
switch update
    case 'measurement_update', label = '측정 갱신';
    case 'initialization', label = '초기화';
    case 'time_update', label = '시간 갱신(예측)';
    otherwise, label = '초기화 전';
end
end

function rate = observedRate(E,type,t)
stamps = unique(E.Time_s(E.Type==type & E.Time_s <= t+1e-9 & E.Time_s >= t-2));
rate = NaN;
if numel(stamps) >= 2, rate = (numel(stamps)-1)/(stamps(end)-stamps(1)); end
end

function gap = lastGap(E,type,t)
stamps = unique(E.Time_s(E.Type==type & E.Time_s <= t+1e-9));
gap = NaN;
if numel(stamps) >= 2, gap = stamps(end)-stamps(end-1); end
end
