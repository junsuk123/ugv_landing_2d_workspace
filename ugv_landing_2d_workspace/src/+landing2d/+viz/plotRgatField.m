function info = plotRgatField(ax,schema,nodeMean,nodeVariance,edgeAttention,mode,label)
% PLOTRGATFIELD  Scientific surface/attention views of ontology R-GAT data.
%
% The surface is a Gaussian interpolation of the discrete ontology node
% values for display only. Node markers are the measured values. Arrows or
% matrix cells use the second R-GAT layer's learned attention coefficients.
if nargin < 6 || isempty(mode), mode = 'surface'; end
if nargin < 7 || isempty(label), label = 'Ontology R-GAT'; end
nodeMean = nodeMean(:);
if nargin < 4 || isempty(nodeVariance)
    nodeVariance = zeros(size(nodeMean));
else
    nodeVariance = nodeVariance(:);
end
if nargin < 5, edgeAttention = []; end
assert(numel(nodeMean) == schema.nNodes, ...
    'landing2d:RgatFieldNodes','nodeMean must match schema.nNodes.');

[x,y] = semanticCoordinates(schema);
[field,X,Y] = interpolatedField(x,y,nodeMean);
A = attentionMatrix(schema,edgeAttention);
colorbar(ax,'off');
cla(ax,'reset');
switch lower(mode)
    case 'surface'
        renderSurface(ax,schema,x,y,nodeMean,nodeVariance,edgeAttention, ...
            field,X,Y,label);
    case 'attention'
        renderAttention(ax,schema,A,label);
    otherwise
        error('landing2d:RgatFieldMode','Unknown R-GAT field mode: %s',mode);
end
info = struct('x',x,'y',y,'X',X,'Y',Y,'field',field, ...
    'attentionMatrix',A);
end

function renderSurface(ax,schema,x,y,nodeMean,nodeVariance,edgeAttention,F,X,Y,label)
hold(ax,'on'); box(ax,'on'); grid(ax,'on');
surf(ax,X,Y,F,F,'EdgeColor','none','FaceAlpha',0.93, ...
    'HandleVisibility','off');
contour3(ax,X,Y,F,8,'Color',[0.18,0.18,0.18], ...
    'LineWidth',0.35,'HandleVisibility','off');
colormap(ax,turbo(128)); clim(ax,[0,1]);
cb = colorbar(ax); cb.Label.String = 'Normalized ontology node value';

nodeStd = sqrt(max(nodeVariance,0));
markerSize = 50+180*nodeStd/max(max(nodeStd),1e-9);
scatter3(ax,x,y,nodeMean+0.025,markerSize,nodeMean,'filled', ...
    'MarkerEdgeColor',[0.08,0.08,0.08],'LineWidth',0.8, ...
    'HandleVisibility','off');
for i = 1:schema.nNodes
    text(ax,x(i),y(i),min(nodeMean(i)+0.12,1.16),shortLabel(schema.nodeNames{i}), ...
        'HorizontalAlignment','center','FontSize',8,'Interpreter','none', ...
        'Color',[0.08,0.08,0.08],'BackgroundColor',[1,1,1],'Margin',0.5);
end

if ~isempty(edgeAttention)
    edgeAttention = edgeAttention(:);
    relationColors = lines(max(schema.nRelations,4));
    for e = 1:min(numel(edgeAttention),numel(schema.src))
        if schema.src(e) == schema.dst(e) || ~isfinite(edgeAttention(e))
            continue;
        end
        i = schema.src(e); j = schema.dst(e);
        z = max(nodeMean([i,j]))+0.055;
        a = min(max(edgeAttention(e),0),1);
        quiver3(ax,x(i),y(i),z,0.82*(x(j)-x(i)),0.82*(y(j)-y(i)),0,0, ...
            'Color',relationColors(schema.rel(e),:),'LineWidth',0.5+3.5*a, ...
            'MaxHeadSize',0.55,'HandleVisibility','off');
    end
end
xlabel(ax,'Semantic layout X'); ylabel(ax,'Semantic layout Y');
zlabel(ax,'Node activation'); zlim(ax,[0,1.2]);
view(ax,[-38,32]); axis(ax,'tight');
title(ax,sprintf('%s: ontology state surface + R-GAT attention flow',label), ...
    'Interpreter','none');
subtitle(ax,'Surface=Gaussian display interpolation; markers=nodes; arrows=layer-2 attention', ...
    'Interpreter','none');
end

function renderAttention(ax,schema,A,label)
hold(ax,'on'); box(ax,'on');
ax.Color = [0.91,0.91,0.91];
h = imagesc(ax,A);
h.AlphaData = isfinite(A);
colormap(ax,turbo(128)); clim(ax,[0,1]);
cb = colorbar(ax); cb.Label.String = 'Layer-2 attention coefficient';
axis(ax,'image'); ax.YDir = 'normal';
ticks = 1:schema.nNodes;
labels = cellfun(@shortLabel,schema.nodeNames,'UniformOutput',false);
ax.XTick = ticks; ax.YTick = ticks;
ax.XTickLabel = labels; ax.YTickLabel = labels;
ax.XTickLabelRotation = 42; ax.TickLabelInterpreter = 'none';
ax.FontSize = 8;
xlabel(ax,'Destination node'); ylabel(ax,'Source node');
title(ax,sprintf('%s: learned R-GAT attention matrix',label),'Interpreter','none');
subtitle(ax,'Gray=no edge; diagonal=self relation; row source -> column destination', ...
    'Interpreter','none');
end

function A = attentionMatrix(schema,edgeAttention)
A = nan(schema.nNodes,schema.nNodes);
if isempty(edgeAttention)
    return;
end
edgeAttention = edgeAttention(:);
for e = 1:min(numel(edgeAttention),numel(schema.src))
    i = schema.src(e); j = schema.dst(e);
    if ~isfinite(edgeAttention(e)), continue; end
    if isnan(A(i,j))
        A(i,j) = edgeAttention(e);
    else
        A(i,j) = max(A(i,j),edgeAttention(e));
    end
end
end

function [F,X,Y] = interpolatedField(x,y,value)
padding = 0.45;
xq = linspace(min(x)-padding,max(x)+padding,70);
yq = linspace(min(y)-padding,max(y)+padding,70);
[X,Y] = meshgrid(xq,yq);
numerator = zeros(size(X));
denominator = zeros(size(X));
sigma = 0.72;
for i = 1:numel(value)
    w = exp(-((X-x(i)).^2+(Y-y(i)).^2)/(2*sigma^2));
    numerator = numerator+w*value(i);
    denominator = denominator+w;
end
F = numerator./max(denominator,1e-12);
F = min(max(F,0),1);
end

function [x,y] = semanticCoordinates(schema)
theta = linspace(pi/2,pi/2+2*pi,schema.nNodes+1);
x = 2*cos(theta(1:end-1))';
y = 2*sin(theta(1:end-1))';
for i = 1:schema.nNodes
    switch schema.nodeNames{i}
        case 'PositionError',       x(i) = -2.0; y(i) = 1.0;
        case 'DescentSpeed',        x(i) = -1.0; y(i) = 1.7;
        case 'RelativeMotionRisk',  x(i) =  0.0; y(i) = 2.0;
        case 'FovMargin',           x(i) =  1.0; y(i) = 1.7;
        case 'SearchDuration',      x(i) =  2.0; y(i) = 1.0;
        case 'PadVisibility',       x(i) =  1.4; y(i) = 0.0;
        case 'RelativeDistance',    x(i) = -1.4; y(i) = 0.0;
        case 'TouchdownSafety',     x(i) =  0.0; y(i) = -1.0;
        case 'SafeLanding',         x(i) =  0.0; y(i) = -2.0;
    end
end
end

function text = shortLabel(name)
switch name
    case 'PositionError',      text = 'PosErr';
    case 'DescentSpeed',       text = 'Vz';
    case 'RelativeMotionRisk', text = 'RelRisk';
    case 'FovMargin',          text = 'FOV';
    case 'SearchDuration',     text = 'Search';
    case 'PadVisibility',      text = 'Visible';
    case 'RelativeDistance',   text = 'Distance';
    case 'TouchdownSafety',    text = 'Safety';
    case 'SafeLanding',        text = 'Landing';
    otherwise, text = regexprep(name,'([a-z])([A-Z])','$1 $2');
end
end
