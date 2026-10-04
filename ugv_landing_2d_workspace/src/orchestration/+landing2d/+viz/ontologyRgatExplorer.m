function output = ontologyRgatExplorer(options)
% ONTOLOGYRGATEXPLORER  Complete ontology and R-GAT inspection in one GUI.
%
% The viewer is read-only. It loads the final ontology-RGAT checkpoint and
% a representative state from the saved paper validation, then exposes:
%   1) every ontology node, class, group, provenance, and directed edge;
%   2) all 12-by-9 runtime node features and the four readout groups;
%   3) Actor/Critic attention on all 26 edges, including self relations;
%   4) relation-wise parameter norms, tensor inventory, and edge messages.
%
% Example:
%   addpath('src/orchestration','src/simulations','src/algorithms')
%   view = landing2d.viz.ontologyRgatExplorer();
%
% Options:
%   scenarioId    'S1', 'S2', or 'S3' (default 'S3')
%   snapshotMode  'max_recovery', 'middle', or 'final'
%   checkpointFile final ontology-RGAT checkpoint path
%   studyFile      saved paper-validation path
%   figureVisible  true or false

if nargin < 1, options = struct(); end
root = landing2d.orchestration.projectRoot();
defaults = struct( ...
    'scenarioId','S3', ...
    'snapshotMode','max_recovery', ...
    'checkpointFile',fullfile(root,'results', ...
        'ppo_context_rgat_planar_visibility_v2.mat'), ...
    'studyFile',fullfile(root,'results','paper','paper_validation.mat'), ...
    'figureVisible',true);
options = parseOptions(options,defaults);

[schema,T] = landing2d.graphstate.contextSchema('context_rgat');
checkpoint = loadRequiredCheckpoint(options.checkpointFile);
agent = checkpoint.agent;
assert(strcmp(agent.encoderSpec.mode,'context_rgat'), ...
    'landing2d:OntologyRgatCheckpoint', ...
    'The selected checkpoint is not a context_rgat policy.');
assert(agent.encoderSpec.nNodes == schema.nNodes && ...
    agent.encoderSpec.inDim == schema.inDim, ...
    'landing2d:OntologyRgatSchema', ...
    'Checkpoint graph dimensions do not match the current ontology.');

[S,snapshot] = representativeState(options.studyFile,options.scenarioId, ...
    options.snapshotMode,agent.encoderSpec,schema);
[actorGraph,actorCache] = landing2d.graphstate.encoderForward( ...
    agent.policy.encoder,agent.encoderSpec,S,'policy');
[criticGraph,criticCache] = landing2d.graphstate.encoderForward( ...
    agent.value.encoder,agent.encoderSpec,S,'value');
actorLayer = actorCache.cache1;
criticLayer = criticCache.cache1;

X = reshape(S,schema.inDim,schema.nNodes);
actorAlpha = actorLayer.alpha(:,1);
criticAlpha = criticLayer.alpha(:,1);
actorNodeStrength = nodeStrength(actorCache.H);
criticNodeStrength = nodeStrength(criticCache.H);

nodeTable = makeNodeTable(schema);
edgeTable = makeEdgeTable(schema);
attentionTable = makeAttentionTable(schema,actorLayer,criticLayer);
relationTable = makeRelationTable(schema,agent,actorLayer,criticLayer);
parameterTable = makeParameterTable(agent);

visibility = onOff(options.figureVisible);
fig = figure('Name','Complete ontology and R-GAT explorer', ...
    'NumberTitle','off','Color','w','Visible',visibility, ...
    'Position',[40,45,1720,970]);
tabs = uitabgroup(fig);

buildSchemaTab(tabs,schema,nodeTable,edgeTable);
buildRuntimeTab(tabs,schema,actorAlpha,criticAlpha, ...
    actorNodeStrength,criticNodeStrength,snapshot);
buildTensorTab(tabs,schema,X,relationTable,snapshot);
buildAuditTab(tabs,schema,agent,attentionTable,parameterTable, ...
    actorGraph,criticGraph,snapshot,options.checkpointFile);

output = struct( ...
    'schemaVersion','ontology_rgat_explorer_v1', ...
    'figure',fig,'schema',schema,'topology',T,'snapshot',snapshot, ...
    'state',S,'nodeFeatures',X,'actorGraph',actorGraph, ...
    'criticGraph',criticGraph,'actorCache',actorCache, ...
    'criticCache',criticCache,'nodeTable',nodeTable, ...
    'edgeTable',edgeTable,'attentionTable',attentionTable, ...
    'relationTable',relationTable,'parameterTable',parameterTable, ...
    'checkpointFile',options.checkpointFile);
if nargout == 0
    assignin('base','ontologyRgatView',output);
end
end

function buildSchemaTab(tabs,schema,nodeTable,edgeTable)
tab = uitab(tabs,'Title','1  Ontology schema');
ax = axes(tab,'Units','normalized','Position',[0.025,0.08,0.50,0.86]);
drawGraph(ax,schema,ones(schema.nNodes,1),[], ...
    'Complete directed ontology schema',false);

uicontrol(tab,'Style','text','Units','normalized', ...
    'Position',[0.545,0.935,0.43,0.035], ...
    'String','All nodes: class, readout group, semantic role, causal provenance', ...
    'BackgroundColor','w','FontWeight','bold','HorizontalAlignment','left');
uitable(tab,'Units','normalized','Position',[0.545,0.53,0.43,0.40], ...
    'Data',nodeTable,'ColumnWidth',{40,125,105,85,75,310}, ...
    'RowName',[]);

uicontrol(tab,'Style','text','Units','normalized', ...
    'Position',[0.545,0.485,0.43,0.035], ...
    'String','All directed edges: 17 semantic edges + 9 self relations', ...
    'BackgroundColor','w','FontWeight','bold','HorizontalAlignment','left');
uitable(tab,'Units','normalized','Position',[0.545,0.08,0.43,0.40], ...
    'Data',edgeTable,'ColumnWidth',{45,135,135,125,75},'RowName',[]);
end

function buildRuntimeTab(tabs,schema,actorAlpha,criticAlpha, ...
        actorNodeStrength,criticNodeStrength,snapshot)
tab = uitab(tabs,'Title','2  Runtime R-GAT');
titleText = sprintf('%s / %s / step %d / %.2f s',snapshot.scenarioId, ...
    snapshot.mode,snapshot.step,snapshot.time);
uicontrol(tab,'Style','text','Units','normalized', ...
    'Position',[0.025,0.955,0.95,0.025],'String',titleText, ...
    'BackgroundColor','w','FontWeight','bold');

axActor = axes(tab,'Units','normalized','Position',[0.03,0.54,0.45,0.36]);
drawGraph(axActor,schema,actorNodeStrength,actorAlpha, ...
    'Actor R-GAT: node activation and edge attention',true);
axCritic = axes(tab,'Units','normalized','Position',[0.52,0.54,0.45,0.36]);
drawGraph(axCritic,schema,criticNodeStrength,criticAlpha, ...
    'Critic R-GAT: node activation and edge attention',true);

axActorMatrix = axes(tab,'Units','normalized','Position',[0.06,0.08,0.39,0.34]);
drawAttentionMatrix(axActorMatrix,schema,actorAlpha,'Actor attention matrix');
axCriticMatrix = axes(tab,'Units','normalized','Position',[0.55,0.08,0.39,0.34]);
drawAttentionMatrix(axCriticMatrix,schema,criticAlpha,'Critic attention matrix');
end

function buildTensorTab(tabs,schema,X,relationTable,snapshot)
tab = uitab(tabs,'Title','3  Features and readout');
axFeatures = axes(tab,'Units','normalized','Position',[0.055,0.12,0.58,0.80]);
imagesc(axFeatures,X);
colormap(axFeatures,divergingMap(256)); clim(axFeatures,[-1,1]);
cb = colorbar(axFeatures); cb.Label.String = 'Normalized feature value';
axFeatures.XTick = 1:schema.nNodes;
axFeatures.XTickLabel = schema.nodeNames;
axFeatures.XTickLabelRotation = 35;
axFeatures.YTick = 1:schema.inDim;
axFeatures.YTickLabel = schema.featureNames;
axFeatures.TickLabelInterpreter = 'none';
xlabel(axFeatures,'Ontology node'); ylabel(axFeatures,'Feature channel');
title(axFeatures,sprintf('Complete X_t tensor: 12 x 9 = 108 values (%s step %d)', ...
    snapshot.scenarioId,snapshot.step),'Interpreter','none');
addCellValues(axFeatures,X,'%.2f',7);

axGroups = axes(tab,'Units','normalized','Position',[0.69,0.57,0.27,0.35]);
imagesc(axGroups,schema.groupMatrix);
colormap(axGroups,parula(128)); clim(axGroups,[0,max(schema.groupMatrix(:))]);
axGroups.XTick = 1:schema.nNodes;
axGroups.XTickLabel = schema.nodeNames;
axGroups.XTickLabelRotation = 42;
axGroups.YTick = 1:numel(schema.groupNames);
axGroups.YTickLabel = schema.groupNames;
axGroups.TickLabelInterpreter = 'none';
title(axGroups,'Grouped readout matrix');
addCellValues(axGroups,schema.groupMatrix,'%.2f',8);

axRelation = axes(tab,'Units','normalized','Position',[0.69,0.12,0.27,0.32]);
values = [relationTable.ActorWNorm,relationTable.CriticWNorm, ...
    relationTable.ActorMeanAlpha,relationTable.CriticMeanAlpha];
bar(axRelation,values,'grouped'); grid(axRelation,'on');
axRelation.XTick = 1:height(relationTable);
axRelation.XTickLabel = relationTable.Relation;
axRelation.XTickLabelRotation = 28;
axRelation.TickLabelInterpreter = 'none';
legend(axRelation,{'Actor ||W_r||','Critic ||W_r||', ...
    'Actor mean alpha','Critic mean alpha'},'Location','best','FontSize',8);
title(axRelation,'Relation transforms and runtime use');
end

function buildAuditTab(tabs,schema,agent,attentionTable,parameterTable, ...
        actorGraph,criticGraph,snapshot,checkpointFile)
tab = uitab(tabs,'Title','4  Full audit');
axPipeline = axes(tab,'Units','normalized','Position',[0.03,0.72,0.94,0.23]);
drawPipeline(axPipeline,schema,agent,snapshot,actorGraph,criticGraph,checkpointFile);

uicontrol(tab,'Style','text','Units','normalized', ...
    'Position',[0.025,0.665,0.60,0.035], ...
    'String','All 26 edge computations: score, normalized attention, weighted message', ...
    'BackgroundColor','w','FontWeight','bold','HorizontalAlignment','left');
uitable(tab,'Units','normalized','Position',[0.025,0.07,0.61,0.59], ...
    'Data',attentionTable,'ColumnWidth',{45,125,125,110,75,75,90, ...
    75,75,90},'RowName',[]);

uicontrol(tab,'Style','text','Units','normalized', ...
    'Position',[0.655,0.665,0.32,0.035], ...
    'String','Complete learned graph-path tensor inventory', ...
    'BackgroundColor','w','FontWeight','bold','HorizontalAlignment','left');
uitable(tab,'Units','normalized','Position',[0.655,0.07,0.32,0.59], ...
    'Data',parameterTable,'ColumnWidth',{65,95,85,85,145},'RowName',[]);
end

function drawGraph(ax,schema,nodeStrength,edgeStrength,titleText,showValues)
cla(ax); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');
[x,y] = nodeCoordinates();
relationColors = [0.16,0.45,0.78; 0.93,0.49,0.16; ...
    0.18,0.63,0.32; 0.82,0.20,0.24; 0.45,0.45,0.45];
if isempty(edgeStrength), edgeStrength = 0.55*ones(numel(schema.src),1); end
edgeStrength = edgeStrength(:);
scale = max(max(edgeStrength),eps);
for e = 1:numel(schema.src)
    i = schema.src(e); j = schema.dst(e); r = schema.rel(e);
    strength = max(edgeStrength(e),0)/scale;
    color = (1-0.25-0.75*strength)*[1,1,1] + ...
        (0.25+0.75*strength)*relationColors(r,:);
    width = 0.65+3.6*strength;
    if i == j
        theta = linspace(0,1.8*pi,45);
        radius = 0.20;
        plot(ax,x(i)+0.24+radius*cos(theta), ...
            y(i)+0.24+radius*sin(theta),'Color',color,'LineWidth',width, ...
            'HandleVisibility','off');
    else
        dx = x(j)-x(i); dy = y(j)-y(i);
        quiver(ax,x(i)+0.13*dx,y(i)+0.13*dy,0.72*dx,0.72*dy,0, ...
            'Color',color,'LineWidth',width,'MaxHeadSize',0.28, ...
            'HandleVisibility','off');
    end
end

groupColors = [0.45,0.26,0.73; 0.12,0.47,0.71; ...
    0.95,0.55,0.16; 0.82,0.20,0.24];
groups = nodeGroups(schema);
nodeStrength = nodeStrength(:);
nodeStrength = nodeStrength/max(max(nodeStrength),eps);
for i = 1:schema.nNodes
    scatter(ax,x(i),y(i),310+260*nodeStrength(i),groupColors(groups(i),:), ...
        'filled','MarkerEdgeColor',[0.08,0.08,0.08],'LineWidth',1.2, ...
        'HandleVisibility','off');
    if showValues
        label = sprintf('%s\n||h|| %.2f',schema.nodeNames{i},nodeStrength(i));
    else
        label = schema.nodeNames{i};
    end
    text(ax,x(i),y(i)-0.47,label,'HorizontalAlignment','center', ...
        'VerticalAlignment','top','FontSize',8,'FontWeight','bold', ...
        'Interpreter','none');
end
for r = 1:schema.nRelations
    plot(ax,nan,nan,'Color',relationColors(r,:),'LineWidth',2.5, ...
        'DisplayName',schema.relationNames{r});
end
legend(ax,'Location','southoutside','Orientation','horizontal', ...
    'Interpreter','none','FontSize',8);
title(ax,titleText,'Interpreter','none');
if showValues
    subtitleText = ['Node color=readout group; edge color=relation; ' ...
        'width=normalized incoming attention'];
else
    subtitleText = 'All 17 semantic edges and 9 self relations';
end
subtitle(ax,subtitleText,'Interpreter','none');
text(ax,-3.0,2.48,['Groups: purple=Perception | blue=Tracking | ' ...
    'orange=Vehicle | red=Safety'],'FontSize',7.5,'Interpreter','none');
xlim(ax,[-3.1,3.1]); ylim(ax,[-2.8,2.65]);
end

function drawAttentionMatrix(ax,schema,alpha,titleText)
A = nan(schema.nNodes,schema.nNodes);
for e = 1:numel(schema.src)
    A(schema.src(e),schema.dst(e)) = alpha(e);
end
imagesc(ax,A,'AlphaData',isfinite(A));
ax.Color = [0.90,0.90,0.90];
colormap(ax,turbo(256)); clim(ax,[0,1]); colorbar(ax);
axis(ax,'image'); ax.YDir = 'normal';
ax.XTick = 1:schema.nNodes; ax.YTick = 1:schema.nNodes;
ax.XTickLabel = schema.nodeNames; ax.YTickLabel = schema.nodeNames;
ax.XTickLabelRotation = 40; ax.TickLabelInterpreter = 'none';
xlabel(ax,'Destination'); ylabel(ax,'Source'); title(ax,titleText);
addCellValues(ax,A,'%.2f',7);
end

function drawPipeline(ax,schema,agent,snapshot,actorGraph,criticGraph,checkpointFile)
cla(ax); hold(ax,'on'); axis(ax,[0,1,0,1]); axis(ax,'off');
labels = { ...
    sprintf('Causal packet\n26 fields'), ...
    sprintf('Ontology X_t\n%d features x %d nodes',schema.inDim,schema.nNodes), ...
    sprintf('Typed R-GAT\n%d relations / %d edges',schema.nRelations,numel(schema.src)), ...
    sprintf('Hidden nodes\n%d x %d',agent.encoderSpec.hiddenDim,schema.nNodes), ...
    sprintf('Grouped readout\n%d groups -> 4-D context',agent.encoderSpec.groupCount), ...
    sprintf('Raw 108-D bypass\n+ relation residual'), ...
    sprintf('Actor action /\nCritic value')};
colors = [0.80,0.88,0.96; 0.75,0.90,0.82; 0.95,0.82,0.62; ...
    0.90,0.78,0.92; 0.78,0.88,0.95; 0.92,0.90,0.72; 0.95,0.78,0.78];
x = linspace(0.01,0.87,numel(labels)); width = 0.12;
for i = 1:numel(labels)
    rectangle(ax,'Position',[x(i),0.42,width,0.34],'Curvature',0.10, ...
        'FaceColor',colors(i,:),'EdgeColor',[0.18,0.18,0.18],'LineWidth',1.2);
    text(ax,x(i)+width/2,0.59,labels{i},'HorizontalAlignment','center', ...
        'FontSize',8,'FontWeight','bold','Interpreter','none');
    if i < numel(labels)
        quiver(ax,x(i)+width,0.59,x(i+1)-x(i)-width-0.008,0,0, ...
            'Color',[0.15,0.15,0.15],'LineWidth',1.3,'MaxHeadSize',0.8);
    end
end
actorNorm = norm(actorGraph(end-3:end));
criticNorm = norm(criticGraph(end-3:end));
detail = sprintf(['Snapshot %s step %d (%.2f s) | readout=%s | ' ...
    'Actor context norm %.4g | Critic context norm %.4g | checkpoint %s'], ...
    snapshot.scenarioId,snapshot.step,snapshot.time,agent.encoderSpec.readout, ...
    actorNorm,criticNorm,checkpointFile);
text(ax,0.01,0.20,detail,'Interpreter','none','FontSize',8, ...
    'HorizontalAlignment','left');
title(ax,'Complete inference path: ontology semantics -> typed relations -> policy/value residual');
end

function tableOut = makeNodeTable(schema)
groups = nodeGroups(schema);
role = repmat("state",schema.nNodes,1);
role(schema.riskNodes) = "risk";
role(schema.goalNode) = "goal";
provenance = strings(schema.nNodes,1);
for i = 1:schema.nNodes
    provenance(i) = string(schema.provenance.(schema.nodeNames{i}));
end
tableOut = table((1:schema.nNodes)',string(schema.nodeNames(:)), ...
    string(schema.nodeClasses(:)),string(schema.groupNames(groups(:)))', ...
    role,provenance,'VariableNames', ...
    {'ID','Node','Class','Group','Role','CausalProvenance'});
end

function tableOut = makeEdgeTable(schema)
n = numel(schema.src);
kind = repmat("semantic",n,1);
kind(schema.src(:) == schema.dst(:)) = "self";
tableOut = table((1:n)',string(schema.nodeNames(schema.src))', ...
    string(schema.nodeNames(schema.dst))', ...
    string(schema.relationNames(schema.rel))',kind, ...
    'VariableNames',{'ID','Source','Destination','Relation','Kind'});
end

function tableOut = makeAttentionTable(schema,actor,critic)
n = numel(schema.src);
actorScore = leakyScore(actor.raw(:,1));
criticScore = leakyScore(critic.raw(:,1));
actorMessage = vecnorm(actor.msgs(:,:,1),2,1)'.*actor.alpha(:,1);
criticMessage = vecnorm(critic.msgs(:,:,1),2,1)'.*critic.alpha(:,1);
tableOut = table((1:n)',string(schema.nodeNames(schema.src))', ...
    string(schema.nodeNames(schema.dst))', ...
    string(schema.relationNames(schema.rel))', ...
    actorScore,actor.alpha(:,1),actorMessage, ...
    criticScore,critic.alpha(:,1),criticMessage, ...
    'VariableNames',{'ID','Source','Destination','Relation', ...
    'ActorScore','ActorAlpha','ActorMessage','CriticScore', ...
    'CriticAlpha','CriticMessage'});
end

function tableOut = makeRelationTable(schema,agent,actor,critic)
R = schema.nRelations;
edgeCount = zeros(R,1); actorMean = zeros(R,1); criticMean = zeros(R,1);
actorW = zeros(R,1); criticW = zeros(R,1);
actorA = zeros(R,1); criticA = zeros(R,1);
actorE = zeros(R,1); criticE = zeros(R,1);
for r = 1:R
    mask = schema.rel(:) == r;
    edgeCount(r) = sum(mask);
    actorMean(r) = mean(actor.alpha(mask,1));
    criticMean(r) = mean(critic.alpha(mask,1));
    actorW(r) = norm(agent.policy.encoder.W1(:,:,r),'fro');
    criticW(r) = norm(agent.value.encoder.W1(:,:,r),'fro');
    actorA(r) = norm(agent.policy.encoder.a1(:,:,r));
    criticA(r) = norm(agent.value.encoder.a1(:,:,r));
    actorE(r) = norm(agent.policy.encoder.E1(:,r));
    criticE(r) = norm(agent.value.encoder.E1(:,r));
end
tableOut = table(string(schema.relationNames(:)),edgeCount, ...
    actorW,criticW,actorA,criticA,actorE,criticE,actorMean,criticMean, ...
    'VariableNames',{'Relation','EdgeCount','ActorWNorm','CriticWNorm', ...
    'ActorAttentionNorm','CriticAttentionNorm','ActorEmbeddingNorm', ...
    'CriticEmbeddingNorm','ActorMeanAlpha','CriticMeanAlpha'});
end

function tableOut = makeParameterTable(agent)
rows = cell(0,5);
rows = appendEncoder(rows,'Actor',agent.policy.encoder);
rows = appendEncoder(rows,'Critic',agent.value.encoder);
rows(end+1,:) = parameterRow('Actor','relation.W',agent.policy.relation.W, ...
    'context-to-action residual');
rows(end+1,:) = parameterRow('Critic','relation.W',agent.value.relation.W, ...
    'context-to-value residual');
tableOut = cell2table(rows,'VariableNames', ...
    {'Head','Tensor','Size','FrobeniusNorm','Role'});
end

function rows = appendEncoder(rows,head,encoder)
roles = struct('W1','relation transforms','a1','attention vectors', ...
    'E1','relation embeddings','W0','local residual transform', ...
    'b0','local residual bias','Wg','grouped readout', ...
    'bg','grouped readout bias');
names = {'W1','a1','E1','W0','b0','Wg','bg'};
for i = 1:numel(names)
    name = names{i};
    rows(end+1,:) = parameterRow(head,name,encoder.(name),roles.(name)); %#ok<AGROW>
end
end

function row = parameterRow(head,name,value,role)
row = {head,name,sizeText(size(value)),norm(value(:)),role};
end

function [S,snapshot] = representativeState(file,scenarioId,mode,spec,schema)
assert(isfile(file),'landing2d:OntologyRgatStudy', ...
    'Paper validation file not found: %s',file);
loaded = load(file);
assert(isfield(loaded,'savedStudy'), ...
    'landing2d:OntologyRgatStudy','savedStudy is absent from %s.',file);
study = loaded.savedStudy;
scenarioIndex = find(strcmpi(string({study.scenarios.id}),string(scenarioId)),1);
policyIndex = find(strcmp(study.modes,'context_rgat'),1);
assert(~isempty(scenarioIndex) && ~isempty(policyIndex), ...
    'landing2d:OntologyRgatStudy','Requested scenario or R-GAT run is absent.');
trajectory = study.trajectories{scenarioIndex,policyIndex};
states = trajectory.state;
assert(size(states,1) == spec.stateDim && ~isempty(states), ...
    'landing2d:OntologyRgatState','Saved trajectory state has an invalid size.');
switch lower(mode)
    case 'max_recovery'
        score = zeros(1,size(states,2));
        for k = 1:size(states,2)
            X = reshape(states(:,k),schema.inDim,schema.nNodes);
            score(k) = X(9,7)+0.5*X(7,7)+0.5*X(1,9)+0.25*X(7,5);
        end
        [~,step] = max(score);
    case 'middle'
        step = max(1,round(size(states,2)/2));
    case 'final'
        step = size(states,2);
    otherwise
        error('landing2d:OntologyRgatSnapshot', ...
            'snapshotMode must be max_recovery, middle, or final.');
end
S = states(:,step);
dt = trajectory.dt;
if ~isscalar(dt), dt = dt(min(step,numel(dt))); end
snapshot = struct('scenarioId',char(study.scenarios(scenarioIndex).id), ...
    'scenarioName',char(study.scenarios(scenarioIndex).name), ...
    'mode',char(mode),'step',step,'time',(step-1)*dt, ...
    'trajectoryLength',size(states,2),'studyFile',file);
end

function checkpoint = loadRequiredCheckpoint(file)
assert(isfile(file),'landing2d:OntologyRgatCheckpoint', ...
    'Checkpoint not found: %s',file);
checkpoint = load(file);
assert(isfield(checkpoint,'agent'), ...
    'landing2d:OntologyRgatCheckpoint','agent is absent from %s.',file);
end

function strength = nodeStrength(H)
H = reshape(H,size(H,1),size(H,2));
strength = vecnorm(H,2,1)';
end

function score = leakyScore(raw)
score = 0.6*raw+0.4*abs(raw);
end

function groups = nodeGroups(schema)
groups = zeros(1,schema.nNodes);
for g = 1:numel(schema.readoutGroups)
    groups(schema.readoutGroups{g}) = g;
end
assert(all(groups > 0),'landing2d:OntologyRgatGroups', ...
    'Every ontology node must belong to one readout group.');
end

function [x,y] = nodeCoordinates()
x = [-2.45,-2.45,-2.45,-2.45,0.0,0.0,2.45,2.45,2.45];
y = [2.00,0.70,-0.70,-2.00,0.85,-0.85,1.80,0.00,-1.80];
end

function addCellValues(ax,A,format,fontSize)
for row = 1:size(A,1)
    for column = 1:size(A,2)
        if isfinite(A(row,column))
            text(ax,column,row,sprintf(format,A(row,column)), ...
                'HorizontalAlignment','center','FontSize',fontSize, ...
                'Color',contrastColor(A(row,column),ax.CLim));
        end
    end
end
end

function color = contrastColor(value,limits)
level = (value-limits(1))/max(diff(limits),eps);
if level < 0.28 || level > 0.72, color = [1,1,1]; else, color = [0,0,0]; end
end

function map = divergingMap(n)
if nargin < 1, n = 256; end
half = ceil(n/2);
blue = [linspace(0.12,1,half)',linspace(0.32,1,half)',ones(half,1)];
red = [ones(n-half,1),linspace(1,0.22,n-half)',linspace(1,0.18,n-half)'];
map = [blue;red];
end

function text = sizeText(sz)
text = strjoin(string(sz),'x');
text = char(text);
end

function value = onOff(flag)
if flag, value = 'on'; else, value = 'off'; end
end

function options = parseOptions(options,defaults)
assert(isstruct(options) && isscalar(options), ...
    'landing2d:OntologyRgatOptions','options must be a scalar struct.');
unknown = setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:OntologyRgatOptions', ...
    'Unknown option: %s',strjoin(unknown,', '));
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(options,names{i}), options.(names{i}) = defaults.(names{i}); end
end
options.scenarioId = char(options.scenarioId);
options.snapshotMode = char(options.snapshotMode);
options.checkpointFile = char(options.checkpointFile);
options.studyFile = char(options.studyFile);
options.figureVisible = logical(options.figureVisible);
assert(ismember(upper(options.scenarioId),{'S1','S2','S3'}), ...
    'landing2d:OntologyRgatScenario','scenarioId must be S1, S2, or S3.');
end
