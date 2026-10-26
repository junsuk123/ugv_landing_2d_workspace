classdef TrainingMonitor < handle
% TRAININGMONITOR  Live PPO training figure, redrawn after every update (display only).
%   monitor = landing2d.viz.TrainingMonitor();                    % visible figure
%   monitor = landing2d.viz.TrainingMonitor(struct('visible',false));
%   monitor.update(message)   % messages of landing2d.rl.ppoTrain (c.trainingMonitor)
% Every PPO update adds one point per run: the training return and landing
% rate of that update's episodes (landing as a trailing mean over the last
% rl.evaluateEvery updates, 6 episodes alone being too coarse) and the
% approximate KL of the update. Validation landing/unsafe rates appear every
% rl.evaluateEvery updates, the schedule that selects the checkpoint; the
% filled marker is the best validation so far (the selected checkpoint once
% the run is done). Lines are colored by method; hovering shows the run name.
% The figure opens on the first message, so no window appears when every
% checkpoint is reused, and it is not reopened after the user closes it.
% Training never depends on it: ppoTrain only sends read values.
    properties (SetAccess = private)
        Figure = []
        Runs = struct('name',{},'methodId',{},'trainSeed',{},'color',{},'state',{}, ...
            'ppoIterations',{},'evaluateEvery',{},'wallSeconds',{},'iteration',{}, ...
            'trainReturn',{},'trainLanding',{},'approxKL',{},'validationIteration',{}, ...
            'validationLanding',{},'validationUnsafe',{},'bestIteration',{},'graphics',{})
        MessageCount = 0
    end
    properties (Access = private)
        Visible
        Axes
        Layout
        Colors
        Labels
        LegendMethods = {}
        LegendProxies = gobjects(1,0)
        Closed = false
        Warned = false
    end
    methods
        function obj = TrainingMonitor(options)
            if nargin < 1, options = struct(); end
            obj.Visible = ~isfield(options,'visible') || logical(options.visible);
            registry = landing2d.config.methodRegistry(options);
            obj.Colors = containers.Map({registry.methods.id},{registry.methods.color});
            obj.Labels = containers.Map({registry.methods.id},{registry.methods.label});
        end

        function update(obj,message)
            % One ppoTrain progress message ('init', 'update' or 'done').
            if obj.Closed, return; end
            try
                if isempty(obj.Figure), obj.createFigure(); end
                if ~isvalid(obj.Figure), obj.Closed = true; return; end
                obj.MessageCount = obj.MessageCount+1;
                k = obj.runIndex(message);
                obj.addMessage(k,message);
                obj.redraw(k);
                obj.updateTitle(k);
                drawnow limitrate;
            catch err
                if ~obj.Warned
                    warning('landing2d:TrainingMonitor', ...
                        'Live training figure stopped updating: %s',err.message);
                    obj.Warned = true;
                end
            end
        end
    end

    methods (Access = private)
        function createFigure(obj)
            visible = 'off'; if obj.Visible, visible = 'on'; end
            obj.Figure = figure('Name','PPO training monitor','Color','w', ...
                'NumberTitle','off','Visible',visible,'Position',[80 80 1250 720]);
            obj.Layout = tiledlayout(obj.Figure,2,2,'TileSpacing','compact','Padding','compact');
            titles = {'training return (each update, mean of its episodes)', ...
                'training landing rate (trailing mean)', ...
                'validation landing (solid) and unsafe (dotted) rate', ...
                'approximate KL of each update'};
            labels = {'return','landing rate','rate','KL'};
            obj.Axes = gobjects(1,4);
            for i = 1:4
                ax = nexttile(obj.Layout);
                hold(ax,'on'); grid(ax,'on'); box(ax,'on');
                title(ax,titles{i},'FontWeight','normal');
                xlabel(ax,'PPO update'); ylabel(ax,labels{i});
                obj.Axes(i) = ax;
            end
            ylim(obj.Axes(2),[0,1]); ylim(obj.Axes(3),[0,1]);
            title(obj.Layout,'PPO training monitor');
        end

        function k = runIndex(obj,message)
            k = find(strcmp({obj.Runs.name},message.runName),1);
            if ~isempty(k), return; end
            color = [0.3 0.3 0.3];
            if isKey(obj.Colors,message.methodId), color = obj.Colors(message.methodId); end
            name = message.runName;
            graphics = struct( ...
                'trainReturn',line(obj.Axes(1),NaN,NaN,'Color',color,'LineWidth',1,'DisplayName',name), ...
                'trainLanding',line(obj.Axes(2),NaN,NaN,'Color',color,'LineWidth',1.2,'DisplayName',name), ...
                'validationLanding',line(obj.Axes(3),NaN,NaN,'Color',color,'LineWidth',1.2, ...
                    'Marker','.','MarkerSize',10,'DisplayName',name), ...
                'validationUnsafe',line(obj.Axes(3),NaN,NaN,'Color',color,'LineWidth',1, ...
                    'LineStyle',':','DisplayName',[name,' unsafe']), ...
                'best',line(obj.Axes(3),NaN,NaN,'Color',color,'LineStyle','none', ...
                    'Marker','o','MarkerFaceColor',color,'MarkerSize',6,'DisplayName',[name,' best']), ...
                'approxKL',line(obj.Axes(4),NaN,NaN,'Color',color,'LineWidth',1,'DisplayName',name));
            obj.Runs(end+1) = struct('name',name,'methodId',message.methodId, ...
                'trainSeed',message.trainSeed,'color',color,'state','running', ...
                'ppoIterations',message.ppoIterations,'evaluateEvery',message.evaluateEvery, ...
                'wallSeconds',0,'iteration',zeros(1,0),'trainReturn',zeros(1,0), ...
                'trainLanding',zeros(1,0),'approxKL',zeros(1,0), ...
                'validationIteration',zeros(1,0),'validationLanding',zeros(1,0), ...
                'validationUnsafe',zeros(1,0),'bestIteration',NaN,'graphics',graphics);
            k = numel(obj.Runs);
            if k == 1
                title(obj.Axes(2),sprintf('training landing rate (trailing mean of %d updates)', ...
                    message.evaluateEvery),'FontWeight','normal');
                title(obj.Axes(3),sprintf(['validation every %d updates: landing (solid), ' ...
                    'unsafe (dotted), best (filled)'],message.evaluateEvery),'FontWeight','normal');
            end
            for i = 1:4
                xlim(obj.Axes(i),[0,max([obj.Runs.ppoIterations,1])]);
            end
            obj.updateLegend(message);
        end

        function addMessage(obj,k,message)
            run = obj.Runs(k);
            run.wallSeconds = message.wallSeconds;
            switch message.event
                case 'update'
                    run.iteration(end+1) = message.iteration;
                    run.trainReturn(end+1) = message.trainReturn;
                    run.trainLanding(end+1) = message.trainLandingRate;
                    run.approxKL(end+1) = message.approxKL;
                case 'done'
                    run.state = 'done';
                    run.bestIteration = message.selectedIteration;
            end
            if ~isempty(message.validation)
                v = message.validation;
                run.validationIteration(end+1) = message.iteration;
                run.validationLanding(end+1) = v.landingRate;
                run.validationUnsafe(end+1) = v.unsafeRate;
                if v.best, run.bestIteration = message.iteration; end
            end
            obj.Runs(k) = run;
        end

        function redraw(obj,k)
            run = obj.Runs(k); h = run.graphics;
            window = max(run.evaluateEvery,1);
            set(h.trainReturn,'XData',run.iteration,'YData',run.trainReturn);
            set(h.trainLanding,'XData',run.iteration, ...
                'YData',movmean(run.trainLanding,[window-1,0],'omitnan'));
            set(h.approxKL,'XData',run.iteration,'YData',run.approxKL);
            set(h.validationLanding,'XData',run.validationIteration,'YData',run.validationLanding);
            set(h.validationUnsafe,'XData',run.validationIteration,'YData',run.validationUnsafe);
            best = find(run.validationIteration == run.bestIteration,1,'last');
            if isempty(best)
                set(h.best,'XData',NaN,'YData',NaN);
            else
                set(h.best,'XData',run.validationIteration(best), ...
                    'YData',run.validationLanding(best));
            end
        end

        function updateTitle(obj,k)
            run = obj.Runs(k);
            active = sum(strcmp({obj.Runs.state},'running'));
            done = numel(obj.Runs)-active;
            last = 0; if ~isempty(run.iteration), last = run.iteration(end); end
            status = sprintf('%s update %d/%d, %.1f min',run.name,last, ...
                run.ppoIterations,run.wallSeconds/60);
            if strcmp(run.state,'done')
                status = sprintf('%s done at update %d, selected update %d',run.name, ...
                    last,run.bestIteration);
            elseif last > 0
                remaining = run.wallSeconds/last*(run.ppoIterations-last);
                status = sprintf('%s, budget end in about %.0f min',status,remaining/60);
            end
            title(obj.Layout,{sprintf('PPO training monitor | runs active %d, done %d', ...
                active,done),status},'Interpreter','none');
        end

        function updateLegend(obj,message)
            if ismember(message.methodId,obj.LegendMethods), return; end
            % One proxy line per method keeps each run line's DisplayName (its
            % run name, shown when hovering) out of the legend.
            obj.LegendMethods{end+1} = message.methodId;
            k = find(strcmp({obj.Runs.methodId},message.methodId),1);
            name = message.methodId;
            if isKey(obj.Labels,name), name = obj.Labels(name); end
            obj.LegendProxies(end+1) = line(obj.Axes(1),NaN,NaN,'Color',obj.Runs(k).color, ...
                'LineWidth',1.5,'DisplayName',name);
            legend(obj.Axes(1),obj.LegendProxies,'Location','best','Interpreter','none');
        end
    end
end
