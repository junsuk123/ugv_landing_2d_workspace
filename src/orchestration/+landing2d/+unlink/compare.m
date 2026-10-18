function output=compare(options)
% COMPARE All checkpoint edges, no cherry-picking or on-line learning.
if nargin<1, options=struct(); end
o=landing2d.unlink.options(options);
c=landing2d.config.primaryConfig(landing2d.orchestration.projectRoot());
c.outputDir=o.checkpointDir;
c=landing2d.config.applyMethod(c,'onto_rgat_ppo',o.trainSeed,1);
[agent,~,file]=landing2d.rl.loadCheckpoint(c);
assert(strcmp(agent.encoderSpec.mode,'context_rgat'), ...
    'landing2d:UnlinkGraph','Expected the planar ontology R-GAT graph.');
originalAgent=agent; identity=landing2d.rl.runIdentity(agent,c,file);
specs=landing2d.paper.representativeScenarios(c); spec=specs(strcmp({specs.id},o.scenarioId));
if ~isempty(o.seed), spec.seed=o.seed; end
assert(o.cutStart+o.cutDuration<=spec.scenario.deadline+1e-9, ...
    'landing2d:UnlinkWindow','Cut window must fit within the scenario deadline.');
fprintf('Unlink: %s | seed %d | Actor alpha=0 during [%.2f, %.2f) s | no renormalization\n', ...
    spec.id,spec.seed,o.cutStart,o.cutStart+o.cutDuration);
normal=landing2d.unlink.rollout(agent,c,spec,o,0);
fprintf('  intact: %s at %.2f s\n',normal.terminalReason,normal.time(end));
t=agent.encoderSpec.T; names=agent.encoderSpec.schema.nodeNames;
relations=agent.encoderSpec.schema.relationNames;
nEdges=t.nEdges; cases=cell(nEdges,1); rows=cell(nEdges,1);
purposes=repmat({''},nEdges,1);
if isfield(agent.encoderSpec.schema,'edgePurpose')
    purposes=agent.encoderSpec.schema.edgePurpose(:);
end
for e=1:nEdges
    r=landing2d.unlink.rollout(agent,c,spec,o,e);
    assert(strcmp(r.manifest.hash,normal.manifest.hash),'landing2d:UnlinkPairing', ...
        'Initial state, motion, sensor events, and time-indexed noise must match.');
    prefix=find(normal.time<o.cutStart-1e-9);
    prefix=prefix(prefix<=numel(r.time));
    assert(isequal(r.time(prefix),normal.time(prefix)) && ...
        isequal(r.truth(:,prefix),normal.truth(:,prefix)), ...
        'landing2d:UnlinkPrefix','Trajectories must agree before the intervention.');
    common=normal.time<=min(normal.time(end),r.time(end))+1e-9;
    paired=interp1(r.time',r.truth(1:2,:)',normal.time(common)','linear')';
    separation=vecnorm(normal.truth(1:2,common)-paired,2,1);
    cases{e}=r;
    rows{e}=struct('EdgeId',e,'Source',string(names{t.src(e)}), ...
        'Target',string(names{t.dst(e)}),'Relation',string(relations{t.rel(e)}), ...
        'Purpose',string(purposes{e}), ...
        'NormalResult',string(normal.terminalReason),'CutResult',string(r.terminalReason), ...
        'NormalEnd_s',normal.time(end),'CutEnd_s',r.time(end), ...
        'CutStart_s',r.cut.actualStart,'CutStop_s',r.cut.actualEnd, ...
        'AppliedCut_s',r.cut.appliedDuration,'CutDecisions',r.cut.decisionCount, ...
        'RestoredInFlight',r.cut.restoredInFlight,'CutStatus',string(r.cut.reason), ...
        'MaxPairedSeparation_m',max(separation), ...
        'FinalPadError_m',r.truth(1,end)-r.truth(6,end));
    fprintf('  edge %02d %-18s -> %-18s %-10s | %-22s | max gap %.4f m\n', ...
        e,names{t.src(e)},names{t.dst(e)},relations{t.rel(e)},r.terminalReason,max(separation));
end
after=landing2d.rl.runIdentity(agent,c,file);
assert(isequaln(agent,originalAgent) && strcmp(identity.CheckpointHash,after.CheckpointHash), ...
    'landing2d:UnlinkMutation','Frozen model/checkpoint changed during diagnostics.');
summary=struct2table(vertcat(rows{:}));
study=struct('schemaVersion','action_semantic_single_edge_unlink_v2','generatedAt',datetime('now'), ...
    'options',o,'scenario',spec,'identity',identity,'taskFingerprint',landing2d.environment.taskFingerprint(c), ...
    'graph',t,'nodeNames',{names},'relationNames',{relations}, ...
    'edgePurpose',{purposes},'padHalfLength',c.padHalfLength, ...
    'normal',normal,'cases',{cases},'summary',summary,'checkpointUnchanged',true, ...
    'truthRows',{{'droneX','droneZ','droneVx','droneVz','theta','padX','padZ','padVx'}}, ...
    'interpretation',['Inference-only post-softmax single-edge message removal, no renormalization. ' ...
        'Local W0/node input remains. Intact and cut are separate closed-loop rollouts with paired exogenous noise. ' ...
        'Max separation is evaluated only at common times, with no post-termination padding. ' ...
        'This is not a retrained ablation or a generalization/performance claim.']);
if any(summary.CutDecisions==0)
    warning('landing2d:UnlinkNotApplied','Some flights ended before the cut. They are retained and labeled, not replaced.');
end
figures=landing2d.unlink.plotComparison(study,o.figureVisible);
files=struct('folder','','mat','','csv','','png',{{}},'fig',{{}});
if o.saveResults
    folder=fullfile(o.outputDir,char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
    if ~isfolder(folder), mkdir(folder); end
    files.folder=folder; files.mat=fullfile(folder,'unlink_comparison.mat');
    files.csv=fullfile(folder,'unlink_summary.csv');
    save(files.mat,'study','-v7.3'); writetable(summary,files.csv);
    for page=1:numel(figures)
        first=8*page-7; last=min(8*page,nEdges);
        stem=fullfile(folder,sprintf('unlink_edges_%02d_%02d',first,last));
        files.png{page}=[stem,'.png']; files.fig{page}=[stem,'.fig'];
        exportgraphics(figures(page),files.png{page},'Resolution',160);
        savefig(figures(page),files.fig{page});
    end
    fprintf('Unlink artifacts: %s\n',folder);
end
output=struct('study',study,'figures',figures,'files',files);
end
