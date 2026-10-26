function E = episodes(runs,d,seeds)
% EPISODES Paired rollouts at every registered gain: runs x cells x gains x seeds.
% Each row is landing2d.evaluation.episodeMetrics of one rollout (same identity
% fields as the protocol-v2 episode table) plus the gain, the clipping and
% saturation shares of the applied a_x, the mean |requested a_x| and the time
% the episode spent inside the UGV acceleration phase (AccelerationExposure_s;
% 0 without UGV acceleration).
if nargin<3, seeds = d.environmentSeeds; end
cells = d.cells; gains = d.gains; saturation = d.saturationThreshold;
rows = {};
for r = 1:numel(runs)
    run = runs(r);
    base = struct('MethodId',string(run.id),'Method',string(run.label),'TrainSeed',run.trainSeed);
    for c = 1:size(cells,1)
        [envConfig,scale] = landing2d.bias_diagnostics.condition(d,run.config,cells{c,1},cells{c,2});
        identity = base; identity.Factor = string(cells{c,1}); identity.Shift = string(cells{c,2});
        agent = run.agent; parts = cell(1,numel(seeds));
        parfor i = 1:numel(seeds)
            parts{i} = oneSeed(agent,envConfig,seeds(i),scale,gains,identity,saturation);
        end
        rows{end+1} = struct2table([parts{:}]); %#ok<AGROW>
        fprintf('[gain] %-18s seed %d %-7s %-3s (%d episodes x %d gains)\n',run.id, ...
            run.trainSeed,cells{c,1},cells{c,2},numel(seeds),numel(gains));
    end
end
E = vertcat(rows{:});
end

function rows = oneSeed(agent,c,seed,scale,gains,identity,saturation)
rows = [];
for gain = gains
    [result,traj,info] = landing2d.gain_audit.rollout(agent,c,seed,gain, ...
        struct('sensorNoiseScale',scale,'saturation',saturation));
    id = identity; id.EpisodeSeed = seed;
    row = landing2d.evaluation.episodeMetrics(result,traj,c,id,[]);
    s = result.scenario; exposure = 0;
    if s.a2>0, exposure = max(0,min(result.time(end),s.T1+s.T2)-s.T1); end
    row.Gain = info.Gain; row.ClippedFraction = info.ClippedFraction;
    row.SaturatedFraction = info.SaturatedFraction;
    row.MeanAbsRequestedAx_mps2 = info.MeanAbsRequestedAx_mps2;
    row.AccelerationExposure_s = exposure;
    rows = [rows,row]; %#ok<AGROW>
end
end
