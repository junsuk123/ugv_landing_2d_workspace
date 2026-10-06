function output = runLive(target,options)
% RUNLIVE  Real-time lockstep test of the three final checkpoints.
%
% Every arm receives the same scenario, sensor events, and measurement noise
% stream and is stepped through landing2d.environment.step at the policy
% rate.  The drone, UGV/pad, camera FOV, and trajectories are drawn after
% every decision.  Policies act deterministically; nothing is trained.
%
%   target  'S1' | 'S2' | 'S3'  fixed paper scenario
%           integer seed       manifest seed (e.g. test seed 3001)
if nargin < 1 || isempty(target), target='S3'; end
if nargin < 2, options=struct(); end
defaults=struct('playbackSpeed',1,'checkpointDir','', ...
    'videoFile','','showFullTrajectoryAtEnd',true,'viewHalfWidth',15);
options=parseOptions(options,defaults);

projectRoot=landing2d.orchestration.projectRoot();
cfg=landing2d.config.primaryConfig(projectRoot);
if isempty(options.checkpointDir), options.checkpointDir=cfg.outputDir; end
cfg.outputDir=char(options.checkpointDir);
[seed,resetOptions,targetLabel]=resolveTarget(target,cfg);

modes={'baseline','context_flat','context_rgat'};
labels={'Low-level MLP PPO','Semantic-flat MLP PPO','Ontology R-GAT PPO'};
colors=[0.10 0.32 0.62; 0.85 0.33 0.10; 0.35 0.16 0.60];
nArm=numel(modes);
arms=cell(1,nArm); agents=cell(1,nArm); envs=cell(1,nArm);
observations=cell(1,nArm); fingerprints=strings(1,nArm);
for m=1:nArm
    arm=landing2d.graphstate.applyStateRepresentation(cfg,modes{m});
    arm.graphState.stateRepresentation=modes{m};
    arm.rl.policyFile=sprintf('ppo_%s_planar_visibility_v2.mat',modes{m});
    agents{m}=landing2d.rl.loadCheckpoint(arm);
    fingerprints(m)=string(landing2d.environment.taskFingerprint(arm));
    [envs{m},observations{m}]=landing2d.environment.reset(arm,seed,resetOptions);
    arms{m}=arm;
end
assert(all(fingerprints==fingerprints(1)),'landing2d:TaskFingerprint', ...
    'A/B/C do not share the same task contract.');

scenario=envs{1}.scenario;
events=envs{1}.sensorEvents;
policyDt=cfg.experiment.policyDt;
maxSteps=ceil(scenario.deadline/policyDt)+5;
logs=repmat(emptyLog(maxSteps+1),1,nArm);
for m=1:nArm, logs(m)=appendLog(logs(m),envs{m}); end

view=createView(labels,colors,scenario,events,cfg,targetLabel,options);
video=[];
if ~isempty(options.videoFile)
    video=VideoWriter(char(options.videoFile),'MPEG-4');
    % One frame per decision; Inf playback still records a real-time video.
    speed=options.playbackSpeed; if ~isfinite(speed), speed=1; end
    video.FrameRate=min(60,max(1,round(speed/policyDt)));
    open(video);
    cleanupVideo=onCleanup(@()close(video));
end
updateView(view,envs,logs,options);
fprintf('Live test: %s | deadline %.1f s | dropout %s\n', ...
    targetLabel,scenario.deadline,events.dropoutKind);

rs=RandStream('threefry','Seed',0); % unused: deterministic actions
wallStart=tic;
for k=1:maxSteps
    active=cellfun(@(e)~e.episodeStatus.terminated,envs);
    if ~any(active) || ~isgraphics(view.figure), break; end
    for m=find(active)
        state=policyState(observations{m},envs{m}.packet,arms{m});
        u=landing2d.rl.policyAction(agents{m},state,rs,true);
        [envs{m},observations{m}]=landing2d.environment.step(envs{m},tanh(u));
        logs(m)=appendLog(logs(m),envs{m});
        if envs{m}.episodeStatus.terminated
            fprintf('  %-22s %-26s t=%5.2f s  return %7.2f\n',labels{m}, ...
                envs{m}.episodeStatus.terminalReason,envs{m}.time,envs{m}.rewardSum);
        end
    end
    if ~isgraphics(view.figure), break; end
    updateView(view,envs,logs,options);
    if ~isempty(video), writeVideo(video,getframe(view.figure)); end
    if isfinite(options.playbackSpeed)
        simTime=max(cellfun(@(e)e.time,envs));
        pause(max(0,simTime/options.playbackSpeed-toc(wallStart)));
    end
end
if isgraphics(view.figure) && options.showFullTrajectoryAtEnd
    showFullTrajectory(view,logs,scenario);
end

summary=table(string(labels(:)),string(modes(:)), ...
    string(cellfun(@(e)e.episodeStatus.terminalReason,envs,'UniformOutput',false))', ...
    cellfun(@(e)e.time,envs)',cellfun(@(e)e.rewardSum,envs)', ...
    'VariableNames',{'Method','StateRepresentation','TerminalReason', ...
    'EndTime_s','Return'});
disp(summary);
for m=1:nArm, logs(m)=trimLog(logs(m)); end
output=struct('target',targetLabel,'seed',seed,'scenario',scenario, ...
    'sensorEvents',events,'summary',summary,'logs',logs, ...
    'labels',{labels},'modes',{modes});
if isgraphics(view.figure), output.figure=view.figure; end
end

% ------------------------------------------------------------- target setup
function [seed,resetOptions,label]=resolveTarget(target,cfg)
resetOptions=struct();
if isnumeric(target)
    validateattributes(target,{'numeric'},{'scalar','integer','nonnegative'});
    seed=double(target);
    inTest=ismember(seed,cfg.experiment.manifest.testSeeds);
    if inTest, split='test'; else, split='manifest'; end
    label=sprintf('%s seed %d',split,seed);
    return;
end
id=upper(string(target));
specs=landing2d.paper.representativeScenarios(cfg);
index=find(strcmp({specs.id},char(id)),1);
assert(~isempty(index),'landing2d:ScenarioId', ...
    'target must be S1, S2, S3, or an integer seed.');
spec=specs(index);
seed=spec.seed;
resetOptions=struct('scenario',spec.scenario,'sensorEvents',spec.sensorEvents);
label=spec.name;
end

function state=policyState(observation,packet,arm)
if strcmp(arm.graphState.stateRepresentation,'baseline')
    state=observation;
else
    state=landing2d.graphstate.contextGraph(packet,arm);
end
end

% ---------------------------------------------------------------- logging
function log=emptyLog(n)
log=struct('count',0,'time',nan(1,n),'xDrone',nan(1,n),'zDrone',nan(1,n), ...
    'vxDrone',nan(1,n),'theta',nan(1,n),'xPad',nan(1,n),'vxPad',nan(1,n), ...
    'detected',false(1,n),'supervisor',false(1,n),'terminalReason','');
end

function log=appendLog(log,env)
k=log.count+1; log.count=k;
s=env.physicalState;
log.time(k)=env.time; log.xDrone(k)=s.x; log.zDrone(k)=s.z;
log.vxDrone(k)=s.vx; log.theta(k)=s.theta;
log.xPad(k)=env.pad.x; log.vxPad(k)=env.pad.vx;
log.detected(k)=env.measurement.detected;
log.supervisor(k)=env.episodeStatus.supervisorDuration>0;
log.terminalReason=env.episodeStatus.terminalReason;
end

function log=trimLog(log)
n=log.count;
keys={'time','xDrone','zDrone','vxDrone','theta','xPad','vxPad', ...
    'detected','supervisor'};
for i=1:numel(keys), log.(keys{i})=log.(keys{i})(1:n); end
end

% ---------------------------------------------------------------- drawing
function view=createView(labels,colors,scenario,events,cfg,targetLabel,options)
padH=scenario.padHeight;
zTop=padH+scenario.height+2;
view.figure=figure('Name','UGV landing live test','Color','w', ...
    'NumberTitle','off','Position',[60 60 1500 860]);
layout=tiledlayout(view.figure,3,3,'TileSpacing','compact','Padding','compact');
title(layout,sprintf('%s  |  v_1=%.2f m/s, a_2=%.2f m/s^2, T_{CA}=[%.2f, %.2f] s', ...
    targetLabel,scenario.v1,scenario.a2,scenario.T1,scenario.T1+scenario.T2), ...
    'FontWeight','bold');
view.labels=labels; view.colors=colors; view.padH=padH;
view.fov=cfg.experiment.sensor.fov; view.zTop=zTop;
view.halfWidth=options.viewHalfWidth;
for m=1:numel(labels)
    ax=nexttile(layout,[1 2]); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    axis(ax,'equal'); ylim(ax,[0 zTop]);
    xlabel(ax,'x [m]'); ylabel(ax,'z [m]');
    plot(ax,[-1e4 1e4],[0 0],'Color',[0.35 0.35 0.35],'LineWidth',1.5);
    h.fov=patch(ax,nan,nan,[0.2 0.75 0.3],'FaceAlpha',0.15,'EdgeColor','none');
    h.padTrail=plot(ax,nan,nan,':','Color',[0.2 0.2 0.2],'LineWidth',1.2);
    h.droneTrail=plot(ax,nan,nan,'-','Color',colors(m,:),'LineWidth',1.6);
    h.ugvBody=patch(ax,nan,nan,[0.45 0.45 0.45],'EdgeColor','k');
    h.wheels=plot(ax,nan,nan,'o','MarkerSize',7,'MarkerFaceColor','k', ...
        'MarkerEdgeColor','k');
    h.pad=plot(ax,nan,nan,'-','Color',[0.95 0.75 0.10],'LineWidth',5);
    h.droneBody=plot(ax,nan,nan,'-','Color',colors(m,:),'LineWidth',4);
    h.rotors=plot(ax,nan,nan,'o','MarkerSize',6,'MarkerFaceColor', ...
        colors(m,:),'MarkerEdgeColor','k');
    h.ax=ax;
    view.track(m)=h;
end
view.series=gobjects(1,3);
names={'수평 오차 x_{drone}-x_{pad} [m]','패드 상대 고도 [m]','수평 속도 [m/s]'};
for i=1:3
    ax=nexttile(layout,3*i); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    ylabel(ax,names{i}); xlim(ax,[0 scenario.deadline]);
    shadeEvents(ax,scenario,events);
    view.series(i)=ax;
end
xlabel(view.series(3),'t [s]');
view.ugvSpeed=plot(view.series(3),nan,nan,'k--','LineWidth',1.4,'DisplayName','UGV');
for m=1:numel(labels)
    view.err(m)=plot(view.series(1),nan,nan,'Color',colors(m,:),'LineWidth',1.4);
    view.alt(m)=plot(view.series(2),nan,nan,'Color',colors(m,:),'LineWidth',1.4);
    view.vel(m)=plot(view.series(3),nan,nan,'Color',colors(m,:),'LineWidth',1.4, ...
        'DisplayName',labels{m});
end
legend(view.series(3),'Location','northwest','FontSize',7);
end

function shadeEvents(ax,scenario,events)
% Orange: UGV constant-acceleration phase. Red: sensor dropout.
xregion(ax,scenario.T1,scenario.T1+scenario.T2,'FaceColor',[0.96 0.61 0.22], ...
    'FaceAlpha',0.15,'HandleVisibility','off');
if isfinite(events.dropoutStart)
    xregion(ax,events.dropoutStart,events.dropoutEnd,'FaceColor',[0.8 0.1 0.1], ...
        'FaceAlpha',0.15,'HandleVisibility','off');
end
if isfinite(events.pitchStart)
    xline(ax,events.pitchStart,':','Color',[0.4 0.1 0.6], ...
        'HandleVisibility','off');
end
end

function updateView(view,envs,logs,options)
xPad=envs{1}.pad.x;
for m=1:numel(envs)
    env=envs{m}; h=view.track(m); log=logs(m); n=log.count;
    s=env.physicalState;
    set(h.droneTrail,'XData',log.xDrone(1:n),'YData',log.zDrone(1:n));
    set(h.padTrail,'XData',log.xPad(1:n),'YData',view.padH*ones(1,n));
    drawUgv(h,env.pad.x,view.padH);
    right=[cos(s.theta),-sin(s.theta)]*0.35;
    body=[s.x-right(1),s.x+right(1);s.z-right(2),s.z+right(2)];
    set(h.droneBody,'XData',body(1,:),'YData',body(2,:));
    set(h.rotors,'XData',body(1,:),'YData',body(2,:)+0.06);
    drawFov(h.fov,s,view.padH,view.fov,env.measurement.detected, ...
        env.episodeStatus.terminated);
    xlim(h.ax,xPad+[-1 1]*view.halfWidth);
    title(h.ax,statusText(view.labels{m},env),'Color',statusColor(env), ...
        'FontSize',9,'Interpreter','tex');
    t=log.time(1:n);
    set(view.err(m),'XData',t,'YData',log.xDrone(1:n)-log.xPad(1:n));
    set(view.alt(m),'XData',t,'YData',log.zDrone(1:n)-view.padH);
    set(view.vel(m),'XData',t,'YData',log.vxDrone(1:n));
end
[~,longest]=max([logs.count]);
n=logs(longest).count;
set(view.ugvSpeed,'XData',logs(longest).time(1:n),'YData',logs(longest).vxPad(1:n));
if isfinite(options.playbackSpeed), drawnow; else, drawnow limitrate; end
end

function drawUgv(h,x,padH)
bodyX=x+[-0.8 0.8 0.8 -0.8]; bodyZ=[0.18 0.18 padH-0.05 padH-0.05];
set(h.ugvBody,'XData',bodyX,'YData',bodyZ);
set(h.wheels,'XData',x+[-0.55 0.55],'YData',[0.12 0.12]);
set(h.pad,'XData',x+[-0.5 0.5],'YData',[padH padH]);
end

function drawFov(p,s,padH,fov,detected,terminated)
h=s.z-padH;
if terminated || h<=0.05
    set(p,'XData',nan,'YData',nan); return;
end
boresight=atan2(-cos(s.theta),-sin(s.theta)); % camera axis [-sin,-cos] in (x,z)
xs=s.x; zs=s.z;
for sgn=[-1 1]
    a=boresight+sgn*fov/2;
    d=[cos(a);sin(a)];
    if d(2)<-1e-3, reach=min(h/-d(2),60); else, reach=60; end
    xs(end+1)=s.x+reach*d(1); zs(end+1)=s.z+reach*d(2); %#ok<AGROW>
end
if detected, c=[0.2 0.75 0.3]; else, c=[0.85 0.15 0.15]; end
set(p,'XData',xs,'YData',zs,'FaceColor',c);
end

function text=statusText(label,env)
st=env.episodeStatus; s=env.physicalState;
if st.terminated
    state=strrep(st.terminalReason,'_','\_');
elseif st.abortRequested
    state='RECOVERY';
elseif ~env.measurement.detected
    state='PAD LOST';
else
    state='TRACKING';
end
text=sprintf('%s  |  t=%5.1f s  h=%5.2f m  e_x=%+5.2f m  |  %s',label, ...
    env.time,s.z-env.pad.z,s.x-env.pad.x,state);
end

function c=statusColor(env)
st=env.episodeStatus;
if ~st.terminated, c=[0 0 0]; return; end
switch st.terminalReason
    case 'SUCCESS', c=[0.05 0.55 0.15];
    case {'SAFE_ABORT','TASK_TIMEOUT'}, c=[0.85 0.45 0.0];
    otherwise, c=[0.8 0.05 0.05];
end
end

function showFullTrajectory(view,logs,scenario)
xAll=[logs.xDrone,logs.xPad]; xAll=xAll(isfinite(xAll));
lim=[min(xAll)-2,max(xAll)+2];
for m=1:numel(view.track)
    axis(view.track(m).ax,'normal');
    xlim(view.track(m).ax,lim); ylim(view.track(m).ax,[0 view.zTop]);
end
endTime=min(scenario.deadline,max([logs.time])+0.5);
for i=1:3, xlim(view.series(i),[0 endTime]); end
drawnow;
end

function options=parseOptions(options,defaults)
assert(isstruct(options) && isscalar(options), ...
    'landing2d:InvalidOptions','options must be a scalar struct.');
unknown=setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption', ...
    'Unknown live option: %s',strjoin(unknown,', '));
keys=fieldnames(defaults);
for i=1:numel(keys)
    if ~isfield(options,keys{i}), options.(keys{i})=defaults.(keys{i}); end
end
validateattributes(options.playbackSpeed,{'numeric'},{'scalar','positive'});
validateattributes(options.viewHalfWidth,{'numeric'},{'scalar','positive'});
options.showFullTrajectoryAtEnd=logical(options.showFullTrajectoryAtEnd);
end
