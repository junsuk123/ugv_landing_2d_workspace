function test_planar_visibility_viz()
% V2 comparison accepts unequal/short trajectories and renders every tab.
c=landing2d.config.primaryConfig(fileparts(fileparts(mfilename('fullpath'))));
c.figureVisible=false; c.saveResults=false; c.showLiveDashboard=false;
modes={'baseline','context_flat','context_rgat'};
labels={'Low-level MLP PPO','Semantic-flat MLP PPO','Ontology R-GAT PPO'};
results=cell(1,3); infos=cell(1,3); profiles=cell(1,3); training=cell(1,3);
for i=1:3
    arm=landing2d.graphstate.applyStateRepresentation(c,modes{i});
    rs=RandStream('threefry','Seed',700+i);
    agent=landing2d.rl.agentInit(arm.rl,rs,arm.graphState);
    results{i}=landing2d.rl.rolloutEpisodeV2(agent,arm,2201, ...
        struct('deterministic',true,'maxDecisions',4));
    infos{i}=struct('landingRate',0,'unsafeRate',0,'safeAbortRate',0, ...
        'meanCaptureRate',mean(results{i}.visible),'nodeMean',[], ...
        'nodeVariance',[],'edgeAttentionMean',[],'graphSchema',struct());
    profiles{i}=struct('totalInferenceMs',0.1*i,'parameterCount',100*i);
    training{i}=struct('history',struct('iteration',0,'score',results{i}.return));
end
runs=struct('results',results,'label',labels,'info',infos, ...
    'profile',profiles,'training',training);
[fig,tabs,layouts]=landing2d.viz.replayPlanarVisibilityComparison(runs,c, ...
    struct('animate',false,'playbackSpeed',Inf));
cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
assert(isgraphics(fig) && numel(tabs)==2 && numel(layouts)==2);
axesList=findobj(fig,'Type','axes');
assert(~isempty(axesList));
trajectoryAxes=findobj(fig,'Type','axes','Tag','landing2dV2TrajectoryAxes');
assert(numel(trajectoryAxes)==1 && strcmp(trajectoryAxes.XLimMode,'manual') ...
    && strcmp(trajectoryAxes.YLimMode,'manual'));
phaseBands=findall(trajectoryAxes,'Type','patch','Tag','Landing2dV2PhaseBackground');
assert(numel(phaseBands)==3);
end
