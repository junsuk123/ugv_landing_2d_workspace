function varargout = liveDashboard(action,varargin)
% LIVEDASHBOARD  학습, 온톨로지 상태, 평가 궤적을 한 창에서 실시간 표시.
%
% 수치 계산과 독립된 표시 전용 상태를 persistent로 보관합니다. 창을 닫으면 이후
% 갱신은 조용히 무시하므로 장시간 학습을 중단시키지 않습니다.
persistent dashboard
if nargin < 1
    action = 'state';
end

switch lower(action)
    case 'init'
        c = varargin{1};
        if ~isempty(dashboard) && isfield(dashboard,'fig') && isgraphics(dashboard.fig)
            delete(dashboard.fig);
        end
        dashboard = createDashboard(c);
        if nargout > 0, varargout{1} = dashboard.fig; end
        return;
    case 'close'
        if isOpen(dashboard), delete(dashboard.fig); end
        dashboard = [];
        return;
    case 'state'
        if nargout > 0, varargout{1} = dashboard; end
        return;
end

if ~isOpen(dashboard)
    return;
end
payload = varargin{1};
switch lower(action)
    case 'training'
        dashboard = updateTraining(dashboard,payload);
    case 'ontology'
        dashboard = updateOntologyTraining(dashboard,payload);
    case 'montecarloprogress'
        dashboard = updateMonteCarloProgress(dashboard,payload);
    case 'montecarlo'
        dashboard = updateMonteCarlo(dashboard,payload);
    case 'done'
        dashboard.status.String = payload.message;
end
drawnow limitrate;
end

function st = createDashboard(c)
visible = 'on';
if isfield(c,'figureVisible') && ~c.figureVisible, visible = 'off'; end
st.fig = figure('Name','UGV landing - live learning dashboard', ...
    'NumberTitle','off','Color','w','Visible',visible, ...
    'Position',[40,60,1500,860],'Tag','landing2dLiveDashboard');
st.layout = tiledlayout(st.fig,2,2,'TileSpacing','compact','Padding','compact');
title(st.layout,'실시간 학습 · 온톨로지 · 평가 대시보드');

st.axScore = nexttile(st.layout,1);
hold(st.axScore,'on'); grid(st.axScore,'on'); box(st.axScore,'on');
xlabel(st.axScore,'PPO iteration'); ylabel(st.axScore,'Return / score');
title(st.axScore,'정책 학습 곡선');

st.axRate = nexttile(st.layout,2);
hold(st.axRate,'on'); grid(st.axRate,'on'); box(st.axRate,'on');
xlabel(st.axRate,'PPO iteration'); ylabel(st.axRate,'Rate [%]');
ylim(st.axRate,[0,100]); title(st.axRate,'평가 성공률');

st.axOntology = nexttile(st.layout,3);
hold(st.axOntology,'on'); box(st.axOntology,'on');
title(st.axOntology,'온톨로지 상태 G_t'); axis(st.axOntology,'off');
schema = landing2d.graphstate.schemaFor('ontology_rgat');
G = digraph(schema.src,schema.dst,[],schema.nodeNames);
st.graph = plot(st.axOntology,G,'Layout','force','NodeLabel',schema.nodeNames, ...
    'MarkerSize',2,'LineWidth',0.8,'ArrowSize',8);
st.graph.NodeColor = [0.45,0.45,0.45];
st.graph.EdgeColor = [0.72,0.72,0.72];
st.nodeValues = scatter(st.axOntology,st.graph.XData,st.graph.YData,100, ...
    0.5*ones(schema.nNodes,1),'filled','MarkerEdgeColor',[0.2,0.2,0.2]);
colormap(st.axOntology,parula(64));
clim(st.axOntology,[0,1]);
st.colorbar = colorbar(st.axOntology);
st.colorbar.Label.String = '정규화 노드 값';
st.schema = schema;

st.axEval = nexttile(st.layout,4);
hold(st.axEval,'on'); grid(st.axEval,'on'); box(st.axEval,'on');
xlabel(st.axEval,'Forward position x [m]'); ylabel(st.axEval,'Altitude z [m]');
title(st.axEval,'몬테카를로 평균 궤적 + 1σ 공분산');
yline(st.axEval,c.padHeight,':','Pad height','HandleVisibility','off');

st.status = subtitle(st.layout,'대시보드 준비 완료');
st.series = struct();
st.mcSeries = struct();
st.lastDraw = tic;
end

function yes = isOpen(st)
yes = ~isempty(st) && isstruct(st) && isfield(st,'fig') && isgraphics(st.fig);
end

function st = updateTraining(st,p)
key = matlab.lang.makeValidName(p.label);
if ~isfield(st.series,key)
    color = agentColor(st,p.label);
    item.score = animatedline(st.axScore,'Color',color,'LineWidth',1.8, ...
        'DisplayName',[p.label,' eval']);
    item.train = animatedline(st.axScore,'Color',color,'LineStyle',':', ...
        'LineWidth',1.1,'DisplayName',[p.label,' train']);
    item.landing = animatedline(st.axRate,'Color',color,'LineWidth',1.8, ...
        'DisplayName',[p.label,' landing']);
    item.capture = animatedline(st.axRate,'Color',color,'LineStyle','--', ...
        'LineWidth',1.2,'DisplayName',[p.label,' capture']);
    st.series.(key) = item;
    legend(st.axScore,'Location','best','Interpreter','none');
    legend(st.axRate,'Location','best','Interpreter','none');
end
item = st.series.(key);
addpoints(item.score,p.iteration,p.score);
if isfinite(p.trainReturn), addpoints(item.train,p.iteration,p.trainReturn); end
addpoints(item.landing,p.iteration,100*p.landingRate);
addpoints(item.capture,p.iteration,100*p.captureRate);
st.status.String = sprintf('%s 학습 %d/%d | score %.2f | landing %.0f%% | capture %.0f%%', ...
    p.label,p.iteration,p.maxIteration,p.score,100*p.landingRate,100*p.captureRate);
end

function st = updateOntologyTraining(st,p)
title(st.axOntology,sprintf('온톨로지 R-GAT %d/%d | train %.4f | val %.4f', ...
    p.epoch,p.maxEpoch,p.trainLoss,p.validationLoss));
st.status.String = sprintf('온톨로지 잠재함수 학습 %d/%d',p.epoch,p.maxEpoch);
end

function st = updateMonteCarloProgress(st,p)
st.status.String = sprintf('%s 몬테카를로 평가 · scenario %d · %d/%d', ...
    p.label,p.scenario,p.index,p.total);
drawnow limitrate;
end

function st = updateMonteCarlo(st,p)
key = matlab.lang.makeValidName(sprintf('%s_s%d',p.label,p.scenario));
color = agentColor(st,p.label);
styles = {'-','--',':','-.'};
style = styles{1+mod(p.scenario-1,numel(styles))};
if isfield(st.mcSeries,key)
    old = st.mcSeries.(key);
    delete(old.meanLine(isgraphics(old.meanLine)));
    delete(old.endMarker(isgraphics(old.endMarker)));
    delete(old.ellipses(isgraphics(old.ellipses)));
end
item.meanLine = plot(st.axEval,p.meanX,p.meanZ,'Color',color, ...
    'LineStyle',style,'LineWidth',1.8, ...
    'DisplayName',sprintf('%s / S%d mean (n=%d)',p.label,p.scenario,p.nRuns));
item.endMarker = plot(st.axEval,p.meanX(end),p.meanZ(end),'o','Color',color, ...
    'MarkerFaceColor',color,'HandleVisibility','off');
ellipseIndex = unique(round(linspace(1,numel(p.time),10)));
theta = linspace(0,2*pi,48);
item.ellipses = gobjects(1,numel(ellipseIndex));
for q = 1:numel(ellipseIndex)
    k = ellipseIndex(q);
    covariance = [p.varX(k),p.covXZ(k);p.covXZ(k),p.varZ(k)];
    covariance = 0.5*(covariance+covariance');
    [V,D] = eig(covariance);
    radius = sqrt(max(diag(D),0));
    points = V*diag(radius)*[cos(theta);sin(theta)];
    item.ellipses(q) = patch(st.axEval,p.meanX(k)+points(1,:), ...
        p.meanZ(k)+points(2,:),color,'FaceAlpha',0.10,'EdgeColor',color, ...
        'EdgeAlpha',0.35,'HandleVisibility','off');
end
st.mcSeries.(key) = item;
legend(st.axEval,'Location','best','Interpreter','none');
if isfield(p,'nodeMean') && numel(p.nodeMean) == numel(st.graph.XData)
    nodeStd = sqrt(max(p.nodeVariance(:),0));
    set(st.nodeValues,'XData',st.graph.XData,'YData',st.graph.YData, ...
        'CData',p.nodeMean(:),'SizeData',80+240*nodeStd);
    title(st.axOntology,sprintf(['온톨로지 상태 G_t · %s / S%d\n' ...
        '색=MC 평균, 크기=표준편차'],p.label,p.scenario),'Interpreter','none');
end
if isfinite(p.meanLandingTime)
    landingText = sprintf('mean touchdown %.2f s',p.meanLandingTime);
else
    landingText = 'no touchdown';
end
st.status.String = sprintf('%s MC 완료 · S%d · landing %.0f%% · %s', ...
    p.label,p.scenario,100*p.landingRate,landingText);
end

function color = agentColor(~,label)
% 레이블에서 안정적으로 색을 정해 호출 순서와 무관하게 같은 에이전트는 같은 색입니다.
lowerLabel = lower(label);
if contains(lowerLabel,'guidance') || contains(lowerLabel,'pd control')
    index = 1;
elseif contains(lowerLabel,'baseline')
    index = 2;
elseif contains(lowerLabel,'legacy')
    index = 4;
elseif contains(lowerLabel,'ontology') || contains(lowerLabel,'gat') ...
        || contains(lowerLabel,'node_pool')
    index = 3;
else
    index = 1+mod(sum(double(label)),7);
end
palette = lines(7);
color = palette(index,:);
end
