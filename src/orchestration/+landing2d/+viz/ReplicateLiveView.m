classdef ReplicateLiveView < handle
% REPLICATELIVEVIEW  Live windows of landing2d.orchestration.runLive (display only).
%   view = landing2d.viz.ReplicateLiveView(spec,cfg,runs,episodes,visible)
%   view.update(episodes); view.finish(episodes)
% One window per method: approach in the pad frame (x_drone - x_pad against
% the height above the pad, dashed = camera-aim line e_aim = 0), aim error
% e_aim (landing2d.evaluation.aimError), height and the requested a_x, a_z of
% every sensor-noise replicate; one color per training seed, the dot is the
% current position, o = landed, x = other terminal reason. Orange = UGV
% acceleration [T1, T1+T2), gray = injected marker dropout.
% Comparison window: the across-replicate spread over time of the requested
% acceleration and of the aim error (ReplicateLiveView.spread), one line per
% method and training seed, with the live outcome counts in the title.
% Closing a window only stops drawing it.
    properties (SetAccess = private)
        Figures = gobjects(1,0)
    end
    properties (Access = private)
        Spec
        Config
        Runs
        MethodIds
        SeedColors
        EpisodeHandles
        MethodLayouts = {}
        Cursors = gobjects(1,0)
        CompareLayout
        CompareLines
        PadHeight
        Slope
    end

    methods
        function obj = ReplicateLiveView(spec,cfg,runs,episodes,visible)
            obj.Spec = spec; obj.Config = cfg; obj.Runs = runs;
            obj.PadHeight = spec.scenario.padHeight;
            obj.Slope = tan(-cfg.experiment.sensor.cameraPitchOffset);
            obj.MethodIds = unique({runs.id},'stable');
            seeds = unique([runs.trainSeed],'stable');
            if isscalar(seeds)
                obj.SeedColors = containers.Map('KeyType','double','ValueType','any');
            else
                palette = lines(numel(seeds));
                obj.SeedColors = containers.Map(num2cell(seeds),num2cell(palette,2)');
            end
            vis = 'off'; if visible, vis = 'on'; end
            handles = cell(1,numel(episodes));
            for m = 1:numel(obj.MethodIds)
                id = obj.MethodIds{m};
                run = runs(find(strcmp({runs.id},id),1));
                fig = figure('Name',sprintf('%s | %s live noise replicates',run.label,spec.id), ...
                    'Color','w','NumberTitle','off','Visible',vis, ...
                    'Position',[30+45*(m-1) 60+35*(m-1) 1150 820]);
                layout = tiledlayout(fig,3,2,'TileSpacing','compact','Padding','compact');
                axs = obj.methodAxes(layout);
                obj.Figures(end+1) = fig; obj.MethodLayouts{m} = layout;
                for i = find(strcmp({episodes.methodId},id))
                    handles{i} = obj.episodeHandles(axs,episodes(i),run);
                end
                if ~isscalar(seeds), obj.seedLegend(axs(1)); end
            end
            obj.EpisodeHandles = handles;
            obj.createComparison(vis,numel(obj.MethodIds));
            obj.update(episodes);
        end

        function update(obj,episodes)
            for i = 1:numel(episodes)
                h = obj.EpisodeHandles{i};
                if ~isvalid(h.trajectory), continue; end
                e = episodes(i); n = e.count; truth = 1:n+1;
                heightAbovePad = e.zDrone(truth)-obj.PadHeight;
                set(h.trajectory,'XData',e.xDrone(truth)-e.xPad(truth),'YData',heightAbovePad);
                set(h.head,'XData',e.xDrone(n+1)-e.xPad(n+1),'YData',heightAbovePad(end));
                set(h.aim,'XData',e.time(truth),'YData',landing2d.evaluation.aimError( ...
                    e.xPad(truth),e.xDrone(truth),heightAbovePad,obj.Config));
                set(h.height,'XData',e.time(truth),'YData',heightAbovePad);
                set(h.ax,'XData',e.time(1:n),'YData',e.requestedAcceleration(1,1:n));
                set(h.az,'XData',e.time(1:n),'YData',e.requestedAcceleration(2,1:n));
                if ~e.active
                    landed = strcmp(e.terminalReason,'SUCCESS');
                    marker = 'x'; if landed, marker = 'o'; end
                    set(h.head,'Marker',marker,'MarkerSize',7,'LineWidth',1.5);
                end
            end
            currentTime = max(arrayfun(@(e)e.time(e.count+1),episodes));
            for k = 1:numel(obj.Cursors)
                if isvalid(obj.Cursors(k)), obj.Cursors(k).Value = currentTime; end
            end
            obj.updateComparison(episodes);
            obj.updateTitles(episodes,currentTime);
            drawnow limitrate;
        end

        function finish(obj,episodes)
            obj.update(episodes);
            drawnow;
        end

        function open = isOpen(obj)
            open = any(isvalid(obj.Figures));
        end
    end

    methods (Static)
        function [actionSpread,aimSpread,time] = spread(episodes,c)
            % Across-replicate spread at every decision k with >= 2 replicates
            % still flying: actionSpread = sqrt(var a_x + var a_z) of the
            % requested acceleration [m/s^2]; aimSpread = std of the aim error
            % [m] after that decision; time = k * policyDt. Episodes of one
            % case share the deadline, so their NaN-padded logs stack.
            K = max([episodes.count]);
            requested = cat(3,episodes.requestedAcceleration);
            ax = reshape(requested(1,1:K,:),K,[])';
            az = reshape(requested(2,1:K,:),K,[])';
            truth = 2:K+1;
            xDrone = vertcat(episodes.xDrone); xPad = vertcat(episodes.xPad);
            zDrone = vertcat(episodes.zDrone);
            aim = landing2d.evaluation.aimError(xPad(:,truth),xDrone(:,truth), ...
                zDrone(:,truth)-c.experiment.scenario.padHeight,c);
            flying = sum(isfinite(ax),1);
            actionSpread = sqrt(var(ax,0,1,'omitnan')+var(az,0,1,'omitnan'));
            aimSpread = std(aim,0,1,'omitnan');
            actionSpread(flying < 2) = NaN; aimSpread(flying < 2) = NaN;
            time = (1:K)*c.experiment.policyDt;
        end
    end

    methods (Access = private)
        function axs = methodAxes(obj,layout)
            spec = obj.Spec;
            axs = gobjects(1,5);
            axs(1) = nexttile(layout,[1 2]);
            labels = {'','aim error e_{aim} [m]','height above pad [m]', ...
                'requested a_x [m/s^2]','requested a_z [m/s^2]'};
            for k = 2:5, axs(k) = nexttile(layout); end
            for k = 1:5
                hold(axs(k),'on'); grid(axs(k),'on'); box(axs(k),'on');
                if k > 1
                    ylabel(axs(k),labels{k}); xlabel(axs(k),'time [s]');
                    xlim(axs(k),[0,spec.scenario.deadline]);
                    obj.shadeEvents(axs(k));
                    obj.Cursors(end+1) = xline(axs(k),0,'Color',[0.4 0.4 0.4]);
                end
            end
            ax = axs(1);
            halfLength = obj.Config.padHalfLength;
            plot(ax,[-halfLength,halfLength],[0,0],'k-','LineWidth',4);
            heights = [0,1.15*spec.scenario.height];
            plot(ax,-obj.Slope*heights,heights,'--','Color',[0.55 0.55 0.55]);
            xlabel(ax,'x_{drone} - x_{pad} [m]'); ylabel(ax,'height above pad [m]');
            ylim(ax,[-0.3,Inf]);           % upper limit follows a climbing drone
            title(ax,'approach in the pad frame (dashed: camera-aim line e_{aim} = 0)', ...
                'FontWeight','normal');
            yline(axs(2),0,'Color',[0.55 0.55 0.55]);
        end

        function shadeEvents(obj,ax)
            spec = obj.Spec; s = spec.scenario;
            if s.a2 ~= 0
                xregion(ax,s.T1,s.T1+s.T2,'FaceColor',[1.0 0.6 0.2],'FaceAlpha',0.15);
            end
            events = spec.sensorEvents;
            if isfinite(events.dropoutStart)
                xregion(ax,events.dropoutStart,events.dropoutEnd,'FaceColor',[0.5 0.5 0.5], ...
                    'FaceAlpha',0.2);
            end
        end

        function h = episodeHandles(obj,axs,e,run)
            color = run.color;
            if isKey(obj.SeedColors,e.trainSeed), color = obj.SeedColors(e.trainSeed); end
            faint = 0.45*color+0.55;      % lighter shade; replicates overlap
            name = sprintf('%s s%d replicate %d',run.id,e.trainSeed,e.replicate);
            h = struct('trajectory',plot(axs(1),NaN,NaN,'Color',faint,'LineWidth',1, ...
                'DisplayName',name), ...
                'head',plot(axs(1),NaN,NaN,'.','Color',color,'MarkerSize',14,'DisplayName',name), ...
                'aim',plot(axs(2),NaN,NaN,'Color',faint,'DisplayName',name), ...
                'height',plot(axs(3),NaN,NaN,'Color',faint,'DisplayName',name), ...
                'ax',plot(axs(4),NaN,NaN,'Color',faint,'DisplayName',name), ...
                'az',plot(axs(5),NaN,NaN,'Color',faint,'DisplayName',name));
        end

        function seedLegend(obj,ax)
            seeds = cell2mat(keys(obj.SeedColors));
            proxies = gobjects(1,numel(seeds));
            for k = 1:numel(seeds)
                proxies(k) = plot(ax,NaN,NaN,'-','Color',obj.SeedColors(seeds(k)), ...
                    'LineWidth',1.5,'DisplayName',sprintf('training seed %d',seeds(k)));
            end
            legend(ax,proxies,'Location','northeast');
        end

        function createComparison(obj,vis,offset)
            fig = figure('Name',sprintf('%s across-replicate spread',obj.Spec.id), ...
                'Color','w','NumberTitle','off','Visible',vis, ...
                'Position',[30+45*offset 60+35*offset 1000 640]);
            layout = tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
            titles = {'requested acceleration: sqrt(var a_x + var a_z) across replicates', ...
                'aim error: std(e_{aim}) across replicates'};
            labels = {'spread [m/s^2]','spread [m]'};
            axs = gobjects(1,2);
            for k = 1:2
                axs(k) = nexttile(layout); hold(axs(k),'on'); grid(axs(k),'on'); box(axs(k),'on');
                ylabel(axs(k),labels{k}); xlabel(axs(k),'time [s]');
                title(axs(k),titles{k},'FontWeight','normal');
                xlim(axs(k),[0,obj.Spec.scenario.deadline]);
                obj.shadeEvents(axs(k));
                obj.Cursors(end+1) = xline(axs(k),0,'Color',[0.4 0.4 0.4]);
            end
            styles = {'-','--',':','-.'};
            seeds = unique([obj.Runs.trainSeed],'stable');
            spreadLines = gobjects(2,numel(obj.Runs));
            for r = 1:numel(obj.Runs)
                run = obj.Runs(r);
                style = styles{1+mod(find(seeds == run.trainSeed)-1,numel(styles))};
                name = run.label;
                if ~isscalar(seeds), name = sprintf('%s s%d',run.label,run.trainSeed); end
                for k = 1:2
                    spreadLines(k,r) = plot(axs(k),NaN,NaN,style,'Color',run.color, ...
                        'LineWidth',1.6,'DisplayName',name);
                end
            end
            legend(axs(1),spreadLines(1,:),'Location','northeast','Interpreter','none');
            obj.Figures(end+1) = fig; obj.CompareLayout = layout; obj.CompareLines = spreadLines;
        end

        function updateComparison(obj,episodes)
            for r = 1:numel(obj.Runs)
                if ~isvalid(obj.CompareLines(1,r)), return; end
                members = episodes([episodes.runIndex] == r);
                [actionSpread,aimSpread,time] = landing2d.viz.ReplicateLiveView.spread( ...
                    members,obj.Config);
                set(obj.CompareLines(1,r),'XData',time,'YData',actionSpread);
                set(obj.CompareLines(2,r),'XData',time,'YData',aimSpread);
            end
        end

        function updateTitles(obj,episodes,currentTime)
            spec = obj.Spec;
            counts = strings(1,numel(obj.MethodIds));
            for m = 1:numel(obj.MethodIds)
                id = obj.MethodIds{m};
                mine = episodes(strcmp({episodes.methodId},id));
                run = obj.Runs(find(strcmp({obj.Runs.id},id),1));
                landed = sum(strcmp({mine.terminalReason},'SUCCESS'));
                flying = sum([mine.active]);
                ended = numel(mine)-flying;
                counts(m) = sprintf('%s landed %d/%d',run.label,landed,numel(mine));
                if isvalid(obj.MethodLayouts{m})
                    title(obj.MethodLayouts{m},{sprintf(['%s | %s %s | training seed %s | ' ...
                        '%d sensor-noise replicates (same scenario and dropout)'],run.label, ...
                        spec.id,spec.name,strjoin(string(unique([mine.trainSeed])),', '), ...
                        numel(unique([mine.replicate]))),sprintf(['t = %.1f s | flying %d, ' ...
                        'ended %d, landed %d'],currentTime,flying,ended,landed)},'Interpreter','none');
                end
            end
            if isvalid(obj.CompareLayout)
                title(obj.CompareLayout,{sprintf(['%s %s: across-replicate spread ' ...
                    '(same scenario, different sensor-noise tables)'],spec.id,spec.name), ...
                    sprintf('t = %.1f s | %s',currentTime,strjoin(counts,' | '))}, ...
                    'Interpreter','none');
            end
        end
    end
end
