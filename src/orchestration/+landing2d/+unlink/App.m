classdef App < handle
    % APP Click-to-disable paired closed-loop ontology-PPO explorer.
    properties (SetAccess=private)
        Options
        Config
        Agent
        Identity
        Spec
        Selection
        Normal
        Current
        Figure
        UI=struct()
        Busy=false
        LastError=''
        CacheHits=0
        ComputationSeconds=0
    end
    properties (Access=private)
        Cache
        Closing=false
        RelationColors=[.17 .44 .75;.13 .62 .47;.49 .29 .68;.90 .50 .08; ...
            .80 .20 .20;.33 .56 .78;.52 .57 .61]
    end
    methods
        function obj=App(options)
            if nargin<1, options=struct(); end
            assert(~isfield(options,'cutStart')&&~isfield(options,'cutDuration'), ...
                'landing2d:UnlinkInteractiveWindow','Interactive cuts last the entire flight. Use mode=''batch'' for timed cuts.');
            if ~isfield(options,'saveResults'), options.saveResults=false; end
            obj.Options=landing2d.unlink.options(options);
            c=landing2d.config.primaryConfig(landing2d.orchestration.projectRoot());
            c.outputDir=obj.Options.checkpointDir;
            obj.Config=landing2d.config.applyMethod(c,'onto_rgat_ppo',obj.Options.trainSeed,1);
            [obj.Agent,~,file]=landing2d.rl.loadCheckpoint(obj.Config);
            assert(strcmp(obj.Agent.encoderSpec.mode,'context_rgat'), ...
                'landing2d:UnlinkGraph','Interactive inspector requires the planar ontology.');
            obj.Identity=landing2d.rl.runIdentity(obj.Agent,obj.Config,file);
            obj.Selection=landing2d.unlink.selection(obj.Agent.encoderSpec.T,[],[]);
            obj.build(); obj.drawGraph();
            obj.newScenario(obj.Options.scenarioId,obj.Options.seed,obj.Options.sensorNoiseScale);
        end

        function toggleNode(obj,id)
            if obj.Busy || obj.Closing, return; end
            ids=obj.Selection.nodeIds;
            if ismember(id,ids), ids(ids==id)=[]; else, ids(end+1)=id; end
            obj.setSelection(ids,obj.Selection.edgeIds);
        end

        function toggleEdge(obj,id)
            if obj.Busy || obj.Closing, return; end
            ids=obj.Selection.edgeIds;
            if ismember(id,ids), ids(ids==id)=[]; else, ids(end+1)=id; end
            obj.setSelection(obj.Selection.nodeIds,ids);
        end

        function setSelection(obj,nodeIds,edgeIds,force)
            if nargin<4, force=false; end
            if obj.Busy || obj.Closing, return; end
            selected=landing2d.unlink.selection(obj.Agent.encoderSpec.T,nodeIds,edgeIds);
            previous=obj.Selection; obj.Selection=selected;
            obj.Busy=true; obj.enableControls(false); cleanup=onCleanup(@()obj.idle());
            obj.updateGraph(); obj.UI.Status.Text='계산 중: 선택 상태를 에피소드 전체에 적용합니다. 이전 결과는 완료 후 교체됩니다.';
            drawnow limitrate nocallbacks;
            try
                key=obj.cacheKey(selected); clock=tic;
                if ~force && isKey(obj.Cache,key)
                    result=obj.Cache(key); obj.CacheHits=obj.CacheHits+1;
                else
                    result=landing2d.unlink.rollout(obj.Agent,obj.Config,obj.Spec,obj.Options,selected, ...
                        @(time,deadline)obj.progress(time,deadline));
                    assert(strcmp(result.manifest.hash,obj.Normal.manifest.hash),'landing2d:UnlinkPairing', ...
                        'The normal and disabled flights must share the exogenous manifest.');
                    % Bound memory for long exploration; baseline is stored separately.
                    if obj.Cache.Count>=64, obj.Cache=containers.Map('KeyType','char','ValueType','any'); end
                    obj.Cache(key)=result;
                end
                obj.ComputationSeconds=toc(clock); obj.Current=result; obj.LastError='';
                obj.renderResults(); obj.updateGraph();
            catch err
                obj.Selection=previous; obj.updateGraph();
                obj.LastError=getReport(err,'extended','hyperlinks','off');
                obj.UI.Status.Text=['계산 실패 (기존 선택/결과 유지): ',err.message];
                warning('landing2d:UnlinkInteractive','%s',obj.LastError);
            end
            clear cleanup;
            if isempty(obj.LastError) && obj.Options.saveResults, obj.saveResult(); end
        end

        function restoreAll(obj)
            if obj.Busy, return; end
            obj.setSelection([],[]);
        end

        function recompute(obj)
            obj.setSelection(obj.Selection.nodeIds,obj.Selection.edgeIds,true);
        end

        function newScenario(obj,id,seed,noise)
            if obj.Busy, return; end
            previousOptions=obj.Options; previousSpec=obj.Spec;
            o=obj.Options; o.scenarioId=id; o.seed=seed; o.sensorNoiseScale=noise;
            o=landing2d.unlink.options(o);
            specs=landing2d.paper.representativeScenarios(obj.Config);
            spec=specs(strcmp({specs.id},o.scenarioId)); if ~isempty(seed), spec.seed=seed; end
            o.cutStart=0; o.cutDuration=spec.scenario.deadline;
            obj.Busy=true; obj.enableControls(false); cleanup=onCleanup(@()obj.idle());
            obj.UI.Status.Text='정상 연결 기준 궤적 계산 중...'; drawnow limitrate nocallbacks;
            try
                normal=landing2d.unlink.rollout(obj.Agent,obj.Config,spec,o,0, ...
                    @(time,deadline)obj.progress(time,deadline));
            catch err
                obj.Options=previousOptions; obj.Spec=previousSpec; rethrow(err);
            end
            obj.Options=o; obj.Spec=spec; obj.Normal=normal;
            obj.Cache=containers.Map('KeyType','char','ValueType','any');
            obj.Cache(obj.cacheKey(landing2d.unlink.selection(obj.Agent.encoderSpec.T,[],[])))=normal;
            obj.UI.Scenario.Value=spec.id; obj.UI.Seed.Value=spec.seed; obj.UI.Noise.Value=noise;
            clear cleanup;
            obj.setSelection(obj.Selection.nodeIds,obj.Selection.edgeIds);
        end

        function files=saveResult(obj)
            assert(~obj.Busy,'landing2d:UnlinkBusy','Wait for the current comparison to finish before saving.');
            assert(~isempty(obj.Current),'landing2d:UnlinkNoResult','No completed result to save.');
            obj.Busy=true; obj.enableControls(false); cleanup=onCleanup(@()obj.idle());
            after=landing2d.rl.runIdentity(obj.Agent,obj.Config,obj.Identity.CheckpointFile);
            assert(strcmp(obj.Identity.CheckpointHash,after.CheckpointHash),'landing2d:UnlinkMutation','Checkpoint changed.');
            folder=fullfile(obj.Options.outputDir,['interactive_',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
            if ~isfolder(folder), mkdir(folder); end
            result=struct('schemaVersion','action_semantic_interactive_unlink_v2','identity',obj.Identity, ...
                'options',obj.Options,'scenario',obj.Spec,'selection',obj.Selection, ...
                'normal',obj.Normal,'disabled',obj.Current, ...
                'semantics',['Actor only, entire episode: node features zero, incident post-softmax alpha zero, ' ...
                    'node H/readout zero. Individual edges: post-softmax alpha zero only. ' ...
                    'No renormalization; overlapping information in other nodes remains. Critic unchanged.']);
            files=struct('mat',fullfile(folder,'interactive_unlink.mat'),'png',fullfile(folder,'interactive_unlink.png'));
            save(files.mat,'result','-v7.3'); exportapp(obj.Figure,files.png);
            obj.UI.Status.Text=['저장: ',folder];
            clear cleanup;
        end

        function delete(obj)
            if obj.Closing, return; end
            obj.Closing=true;
            if ~isempty(obj.Figure)&&isgraphics(obj.Figure), delete(obj.Figure); end
        end
    end
    methods (Access=private)
        function idle(obj)
            if ~isvalid(obj)||obj.Closing, return; end
            obj.Busy=false;
            obj.enableControls(true);
        end

        function enableControls(obj,value)
            state='off'; if value, state='on'; end
            for field=["Scenario","Seed","Noise","Restore","Recompute","Save","Nodes","Edges","Relations"]
                obj.UI.(field).Enable=state;
            end
        end

        function key=cacheKey(~,selection)
            key=[mat2str(selection.nodeIds),'|',mat2str(selection.edgeIds)];
        end

        function progress(obj,time,deadline)
            if obj.Closing, return; end
            obj.UI.Status.Text=sprintf('계산 중 %.1f / 최대 %.1f s | 완료된 궤적만 결과로 표시합니다.',time,deadline);
            drawnow limitrate nocallbacks;
        end

        function controlsChanged(obj,useDefaultSeed)
            if obj.Busy, return; end
            seed=obj.UI.Seed.Value; if useDefaultSeed, seed=[]; end
            obj.newScenario(obj.UI.Scenario.Value,seed,obj.UI.Noise.Value);
        end

        function tableEdited(obj,kind,event)
            if obj.Busy || event.Indices(2)~=1, return; end
            id=event.Indices(1);
            switch kind
                case 'node'
                    selected=obj.Selection.nodeIds;
                    if event.NewData, selected=setdiff(selected,id); else, selected=union(selected,id); end
                    obj.setSelection(selected,obj.Selection.edgeIds);
                case 'edge'
                    selected=obj.Selection.edgeIds;
                    if event.NewData, selected=setdiff(selected,id); else, selected=union(selected,id); end
                    obj.setSelection(obj.Selection.nodeIds,selected);
                case 'relation'
                    ids=find(obj.Agent.encoderSpec.T.rel==id);
                    selected=obj.Selection.edgeIds;
                    if event.NewData, selected=setdiff(selected,ids); else, selected=union(selected,ids); end
                    obj.setSelection(obj.Selection.nodeIds,selected);
            end
        end

        function build(obj)
            obj.Figure=uifigure('Name','run_unlink | click-to-disable ontology PPO', ...
                'Position',[30 40 1500 940],'Color',[.97 .98 1],'Visible',obj.Options.figureVisible, ...
                'CloseRequestFcn',@(~,~)delete(obj));
            main=uigridlayout(obj.Figure,[5 1]); main.RowHeight={34,38,28,'1x',44};
            uilabel(main,'Text','ONTOLOGY PPO  |  클릭 → 비활성화 → 착륙 궤적 자동 비교', ...
                'FontWeight','bold','FontSize',21,'FontColor',[.12 .2 .34]);
            controls=uigridlayout(main,[1 11]); controls.Padding=[0 0 0 0];
            controls.ColumnWidth={75,90,50,100,65,70,110,110,110,'1x',220};
            uilabel(controls,'Text','시나리오');
            obj.UI.Scenario=uidropdown(controls,'Items',{'S1','S2','S3'},'Value',obj.Options.scenarioId, ...
                'ValueChangedFcn',@(~,~)obj.controlsChanged(true));
            uilabel(controls,'Text','Seed');
            obj.UI.Seed=uieditfield(controls,'numeric','Value',41001,'Limits',[0,2^31-1], ...
                'RoundFractionalValues','on','ValueDisplayFormat','%.0f','ValueChangedFcn',@(~,~)obj.controlsChanged(false));
            uilabel(controls,'Text','잡음 배율');
            obj.UI.Noise=uieditfield(controls,'numeric','Value',obj.Options.sensorNoiseScale,'Limits',[0 Inf], ...
                'ValueChangedFcn',@(~,~)obj.controlsChanged(false));
            obj.UI.Restore=uibutton(controls,'Text','전체 복구','ButtonPushedFcn',@(~,~)obj.restoreAll());
            obj.UI.Recompute=uibutton(controls,'Text','다시 계산','ButtonPushedFcn',@(~,~)obj.recompute());
            obj.UI.Save=uibutton(controls,'Text','결과 저장','ButtonPushedFcn',@(~,~)obj.saveResult());
            uilabel(controls,'Text','Actor에만 적용 · 에피소드 처음부터 끝까지','FontWeight','bold');
            obj.UI.Count=uilabel(controls,'Text','모두 활성');
            obj.UI.Status=uilabel(main,'Text','준비 중','FontColor',[.32 .35 .43]);
            body=uigridlayout(main,[1 2]); body.Padding=[0 0 0 0]; body.ColumnWidth={'1x','1.35x'};
            left=uigridlayout(body,[2 1]); left.Padding=[0 0 0 0]; left.RowHeight={'1.45x','1x'};
            obj.UI.Graph=uiaxes(left); obj.UI.Graph.Toolbar.Visible='off';
            obj.UI.Graph.Interactions=[];
            tabs=uitabgroup(left);
            fields={'Nodes','Edges','Relations'}; labels={'노드','관계 간선','관계 전체'};
            for k=1:3
                tab=uitab(tabs,'Title',labels{k}); grid=uigridlayout(tab,[1 1]); grid.Padding=[2 2 2 2];
                obj.UI.(fields{k})=uitable(grid,'RowName',{},'ColumnEditable',[true false false], ...
                    'ColumnFormat',{'logical','char','char'},'FontSize',11);
            end
            obj.UI.Nodes.CellEditCallback=@(~,event)obj.tableEdited('node',event);
            obj.UI.Edges.CellEditCallback=@(~,event)obj.tableEdited('edge',event);
            obj.UI.Relations.CellEditCallback=@(~,event)obj.tableEdited('relation',event);
            right=uigridlayout(body,[3 1]); right.Padding=[0 0 0 0]; right.RowHeight={'2x','1x',94};
            obj.UI.World=uiaxes(right); obj.UI.Difference=uiaxes(right);
            obj.UI.Summary=uitable(right,'RowName',{},'FontSize',11);
            uilabel(main,'Text',{'그래프의 원/노드 이름 또는 간선/E번호를 클릭하면 활성 ↔ 비활성 전환. 여러 요소를 함께 끌 수 있습니다. 표의 「사용」 체크도 같은 기능입니다.', ...
                '간선: α=0 (재정규화 없음). 노드: 특징 0 + 모든 입출력/self 간선 α=0 + 로컬/읽기 출력 0. 다른 노드의 중복 정보는 남습니다. 재학습·모델 저장 없음.'}, ...
                'FontColor',[.37 .39 .45],'FontSize',11);
        end

        function drawGraph(obj)
            ax=obj.UI.Graph; cla(ax); hold(ax,'on'); axis(ax,'equal');
            t=obj.Agent.encoderSpec.T;
            xy=landing2d.viz.graphLayout(obj.Agent.encoderSpec.schema.nodeNames);
            assert(size(xy,1)==t.nNodes,'landing2d:UnlinkLayout', ...
                'Add a graph layout coordinate for every ontology node.');
            obj.UI.EdgeLines=gobjects(t.nEdges,1); obj.UI.EdgeArrows=gobjects(t.nEdges,1);
            obj.UI.EdgeLabels=gobjects(t.nEdges,1);
            for e=1:t.nEdges
                a=xy(t.src(e),:); b=xy(t.dst(e),:); color=obj.RelationColors(t.rel(e),:);
                if t.src(e)==t.dst(e)
                    angles=linspace(-.35*pi,1.25*pi,45)';
                    points=a+[.27 .26]+.27*[cos(angles),sin(angles)];
                else
                    delta=b-a; unit=delta/norm(delta); a=a+.16*unit; b=b-.16*unit;
                    reverse=find(t.src==t.dst(e)&t.dst==t.src(e),1);
                    bend=.10*mod(e-1,3)-.10;
                    if ~isempty(reverse), bend=.32*sign(e-reverse); end
                    middle=(a+b)/2+bend*[-unit(2),unit(1)]; q=linspace(0,1,45)';
                    points=(1-q).^2*a+2*(1-q).*q*middle+q.^2*b;
                end
                callback=@(~,~)obj.toggleEdge(e);
                obj.UI.EdgeLines(e)=plot(ax,points(:,1),points(:,2),'Color',color,'LineWidth',2, ...
                    'ButtonDownFcn',callback,'PickableParts','all','BusyAction','cancel');
                tip=points(end,:); tail=points(end-3,:); vector=tip-tail;
                obj.UI.EdgeArrows(e)=quiver(ax,tail(1),tail(2),vector(1),vector(2),0, ...
                    'Color',color,'LineWidth',1.5,'MaxHeadSize',2,'ButtonDownFcn',callback,'BusyAction','cancel');
                mid=points(round(end/2),:);
                obj.UI.EdgeLabels(e)=text(ax,mid(1),mid(2),sprintf('E%02d',e),'FontSize',10, ...
                    'Color',color,'BackgroundColor','w','Margin',1,'HorizontalAlignment','center', ...
                    'ButtonDownFcn',callback,'PickableParts','all','BusyAction','cancel');
            end
            labels=obj.Agent.encoderSpec.schema.nodeNames;
            obj.UI.NodeHandles=gobjects(t.nNodes,1); obj.UI.NodeLabels=gobjects(t.nNodes,1);
            angle=linspace(0,2*pi,40);
            for n=1:t.nNodes
                obj.UI.NodeHandles(n)=patch(ax,xy(n,1)+.15*cos(angle),xy(n,2)+.15*sin(angle),[.1 .45 .73], ...
                    'EdgeColor','w','LineWidth',1.5,'ButtonDownFcn',@(~,~)obj.toggleNode(n),'BusyAction','cancel');
                obj.UI.NodeLabels(n)=text(ax,xy(n,1),xy(n,2)-.24,labels{n}, ...
                    'HorizontalAlignment','center','FontSize',12,'FontWeight','bold', ...
                    'ButtonDownFcn',@(~,~)obj.toggleNode(n),'PickableParts','all','BusyAction','cancel');
            end
            xlim(ax,[-2.9 4.4]); ylim(ax,[-1.3 3.8]); ax.XTick=[]; ax.YTick=[]; box(ax,'on');
            title(ax,'클릭하여 비활성화 / 다시 클릭하여 복구','FontSize',13);
            subtitle(ax,strjoin(obj.Agent.encoderSpec.schema.relationNames,' | '), ...
                'Interpreter','none','FontSize',9);
        end

        function updateGraph(obj)
            s=obj.Selection; t=obj.Agent.encoderSpec.T;
            names=obj.Agent.encoderSpec.schema.nodeNames; relations=obj.Agent.encoderSpec.schema.relationNames;
            for n=1:t.nNodes
                color=[.1 .45 .73]; if ~s.nodeKeep(n), color=[.83 .16 .19]; end
                obj.UI.NodeHandles(n).FaceColor=color; obj.UI.NodeLabels(n).Color=color;
            end
            edges=cell(t.nEdges,3); nodes=cell(t.nNodes,3); groups=cell(t.nRelations,3);
            purposes=repmat({''},t.nEdges,1);
            if isfield(obj.Agent.encoderSpec.schema,'edgePurpose')
                purposes=obj.Agent.encoderSpec.schema.edgePurpose(:);
            end
            for e=1:t.nEdges
                color=obj.RelationColors(t.rel(e),:); style='-';
                if ~s.effectiveEdgeKeep(e), color=[.83 .16 .19]; style='--'; end
                obj.UI.EdgeLines(e).Color=color; obj.UI.EdgeLines(e).LineStyle=style;
                obj.UI.EdgeArrows(e).Color=color; obj.UI.EdgeLabels(e).Color=color;
                state='활성';
                if ~s.edgeKeep(e), state='직접 비활성';
                elseif ~s.effectiveEdgeKeep(e), state='노드 때문에 차단'; end
                edges(e,:)={s.edgeKeep(e),sprintf('E%02d %s -> %s (%s) | %s',e, ...
                    names{t.src(e)},names{t.dst(e)},relations{t.rel(e)},purposes{e}),state};
            end
            for n=1:t.nNodes
                state='활성'; if ~s.nodeKeep(n), state='특징/연결/읽기 출력 제거'; end
                nodes(n,:)={s.nodeKeep(n),names{n},state};
            end
            for r=1:t.nRelations
                ids=t.rel==r;
                groups(r,:)={all(s.edgeKeep(ids)),relations{r},sprintf('실제 차단 %d / %d',sum(~s.effectiveEdgeKeep(ids)),sum(ids))};
            end
            obj.UI.Nodes.Data=nodes; obj.UI.Nodes.ColumnName={'사용','노드','상태'};
            obj.UI.Nodes.ColumnWidth={44,190,'auto'};
            obj.UI.Edges.Data=edges; obj.UI.Edges.ColumnName={'사용','간선','상태'};
            obj.UI.Edges.ColumnWidth={44,360,130};
            obj.UI.Relations.Data=groups; obj.UI.Relations.ColumnName={'사용','관계','상태'};
            obj.UI.Relations.ColumnWidth={44,190,'auto'};
            obj.UI.Count.Text=sprintf('노드 %d / 간선 %d개 비활성',numel(s.nodeIds),sum(~s.effectiveEdgeKeep));
        end

        function renderResults(obj)
            a=obj.Normal; b=obj.Current; ax=obj.UI.World; cla(ax); hold(ax,'on'); grid(ax,'on');
            blue=[.1 .36 .73]; red=[.84 .2 .14];
            h1=plot(ax,a.truth(1,:),a.truth(2,:),'Color',blue,'LineWidth',1.8);
            h2=plot(ax,b.truth(1,:),b.truth(2,:),'--','Color',red,'LineWidth',1.8);
            plot(ax,a.truth(1,1),a.truth(2,1),'kp','MarkerFaceColor','k','MarkerSize',9);
            for row=1:2
                r=a; color=blue; marker='o'; if row==2, r=b; color=red; marker='x'; end
                plot(ax,r.truth(1,end),r.truth(2,end),marker,'Color',color,'MarkerSize',8,'LineWidth',1.4);
                x=r.truth(6,end); z=r.truth(7,end); w=obj.Config.padHalfLength;
                patch(ax,x+w*[-1 1 1 -1],[z-.13 z-.13 z z],color,'FaceAlpha',.2,'EdgeColor',color);
            end
            legend(ax,[h1 h2],{'정상 ontology-PPO','현재 비활성화 조합'},'Location','northeast');
            xlabel(ax,'absolute x [m]'); ylabel(ax,'absolute z [m]');
            title(ax,'동일 초기조건·외생 잡음에서 각각 독립적으로 비행','FontSize',13);
            subtitle(ax,sprintf('%s · seed %d | 노드 %s · 직접 선택 간선 %s',obj.Spec.id,obj.Spec.seed, ...
                mat2str(obj.Selection.nodeIds),mat2str(obj.Selection.edgeIds)),'Interpreter','none','FontSize',10);
            xs=[a.truth(1,:),b.truth(1,:),a.truth(6,end),b.truth(6,end)];
            zs=[a.truth(2,:),b.truth(2,:)]; pad=max(1,.04*(max(xs)-min(xs)));
            xlim(ax,[min(xs)-pad,max(xs)+pad]); ylim(ax,[min(0,min(zs)-.2),max(zs)+.5]);
            common=a.time<=min(a.time(end),b.time(end));
            paired=interp1(b.time',b.truth(1:2,:)',a.time(common)','linear')';
            gap=vecnorm(a.truth(1:2,common)-paired,2,1);
            ax=obj.UI.Difference; cla(ax); plot(ax,a.time(common),gap,'Color',[.55 .15 .6],'LineWidth',1.5); grid(ax,'on');
            xlabel(ax,'time [s]'); ylabel(ax,'position difference [m]');
            title(ax,sprintf('동시각 두 궤적 위치 차이 · 최대 %.4f m (공통 비행 시간만)',max(gap)),'FontSize',11);
            obj.UI.Summary.Data={'정상',a.terminalReason,a.time(end),a.truth(1,end)-a.truth(6,end),a.return; ...
                '비활성화',b.terminalReason,b.time(end),b.truth(1,end)-b.truth(6,end),b.return};
            obj.UI.Summary.ColumnName={'모델','종료','종료 시각 [s]','최종 패드 상대 x [m]','누적 보상'};
            obj.UI.Summary.ColumnWidth={90,175,130,170,'auto'};
            obj.UI.Status.Text=sprintf('완료 %.2f s | 정상 %s / 비활성화 %s | 다시 클릭하면 복구 · 동일 조합 결과 재사용 가능', ...
                obj.ComputationSeconds,a.terminalReason,b.terminalReason);
            drawnow limitrate nocallbacks;
        end
    end
end
