classdef Session < handle
    % SESSION Headless, testable live diagnostic engine. Never trains/saves agents.
    properties (SetAccess=private)
        Options
        Config
        Arms = {}
        Agents = {}
        Identities = {}
        MethodIds = {}
        Unavailable = {}
        Env
        Observation
        Current = {}
        Baseline = {}
        BaselineTime = 0
        Episode = 0
        Log
        Events = struct('time',{},'acceleration',{},'duration',{},'coast',{})
        Completed = {}
        DroppedEpisodes = 0
        Manifest
        ActiveCut = 0
        CurrentCutId = 0
        InferenceTime = 0
        InferenceObservation
        CutEvents = struct('id',{},'methodId',{},'head',{},'scope',{},'target',{}, ...
            'edgeIds',{},'start',{},'plannedEnd',{},'actualEnd',{},'endReason',{}, ...
            'beforeRequest',{},'afterRequest',{},'beforeValue',{},'afterValue',{})
    end
    methods
        function obj=Session(options)
            if nargin<1, options=struct(); end
            obj.Options=landing2d.livetest.options(options);
            c=landing2d.config.primaryConfig(landing2d.orchestration.projectRoot());
            if ~isempty(obj.Options.checkpointDir), c.outputDir=obj.Options.checkpointDir; end
            obj.Config=c;
            registry=landing2d.config.methodRegistry(); ids={registry.methods.id};
            if obj.Options.includeShuffled, ids{end+1}='shuffled_rgat_ppo'; end
            for k=1:numel(ids)
                arm=landing2d.config.applyMethod(c,ids{k},obj.Options.trainSeed,obj.Options.graphSeed);
                try
                    [agent,~,file]=landing2d.rl.loadCheckpoint(arm);
                catch err
                    if ~strcmp(ids{k},'shuffled_rgat_ppo'), rethrow(err); end
                    obj.Unavailable{end+1}=sprintf('%s: %s',ids{k},err.message);
                    continue;
                end
                obj.MethodIds{end+1}=ids{k}; obj.Arms{end+1}=arm;
                obj.Agents{end+1}=agent;
                obj.Identities{end+1}=landing2d.rl.runIdentity(agent,arm,file);
            end
            assert(ismember(obj.Options.controller,obj.MethodIds),'landing2d:LiveTestController', ...
                'The requested controller has no compatible checkpoint.');
            obj.reset();
        end

        function reset(obj)
            if obj.Episode>0
                obj.finishCut('reset');
                obj.Completed{end+1}=obj.record();
                if numel(obj.Completed)>obj.Options.maxRetainedEpisodes
                    obj.Completed(1)=[]; obj.DroppedEpisodes=obj.DroppedEpisodes+1;
                end
            end
            obj.Episode=obj.Episode+1;
            o=obj.Options; c=obj.Config;
            p=landing2d.scenario.sampleParameters(c.experiment.scenario,o.seed);
            % Explicit interactive-only long CV scenario. The benchmark's
            % sampling, dynamics, termination, rewards, and signatures stay intact.
            p.v1=o.initialPadSpeed; p.v3=p.v1; p.a2=0;
            p.T1=o.duration; p.T2=0; p.T3=0; p.deadline=o.duration;
            p.L1=p.v1*p.T1; p.L2=0; p.L3=0; p.height=o.height;
            p.liveAccelerationPulses=zeros(0,3); % [start, duration, acceleration]
            p.parameterization='interactive_diagnostic';
            events=struct('dropoutStart',Inf,'dropoutEnd',-Inf,'dropoutKind','clean', ...
                'pitchStart',Inf,'pitchEnd',-Inf,'pitchRate',0);
            [obj.Env,obj.Observation]=landing2d.environment.reset(c,o.seed, ...
                struct('scenario',p,'sensorEvents',events,'sensorNoiseScale',o.sensorNoiseScale));
            obj.Manifest=landing2d.environment.exogenousManifest(obj.Env);
            obj.Events=struct('time',{},'acceleration',{},'duration',{},'coast',{});
            obj.CutEvents=obj.CutEvents([]); obj.ActiveCut=0;
            obj.refresh(); obj.captureBaseline();
            n=ceil(o.duration/c.experiment.policyDt)+3; m=numel(obj.MethodIds);
            obj.Log=struct('count',0,'time',nan(1,n),'truth',nan(8,n), ...
                'observation',nan(numel(obj.Observation),n),'visible',false(1,n), ...
                'policyObservation',nan(numel(obj.Observation),n), ...
                'visionAge',nan(1,n),'requests',nan(2,m,n),'applied',nan(2,n), ...
                'nominalRequests',nan(2,m,n),'values',nan(m,n),'nominalValues',nan(m,n), ...
                'inferenceTime',nan(1,n),'intervention',zeros(1,n), ...
                'appliedIntervention',zeros(1,n), ...
                'actor',{{}},'critic',{{}},'nodeActor',{{}},'nodeCritic',{{}}, ...
                'actorCut',{{}},'criticCut',{{}});
            for j=1:m
                obj.Log.actor{j}=nan(numel(obj.Current{j}.actorAlpha),n);
                obj.Log.critic{j}=nan(numel(obj.Current{j}.criticAlpha),n);
                obj.Log.nodeActor{j}=nan(numel(obj.Current{j}.actorNode),n);
                obj.Log.nodeCritic{j}=nan(numel(obj.Current{j}.criticNode),n);
                obj.Log.actorCut{j}=false(numel(obj.Current{j}.actorAlpha),n);
                obj.Log.criticCut{j}=false(numel(obj.Current{j}.criticAlpha),n);
            end
            obj.appendLog([NaN;NaN]);
        end

        function configure(obj,mode,controller,noiseScale)
            mode=validatestring(mode,{'hold','policy'});
            assert(ismember(controller,obj.MethodIds));
            validateattributes(noiseScale,{'numeric'},{'scalar','real','finite','nonnegative'});
            % Archive the OLD episode under its OLD settings before changing mode.
            old=obj.Options;
            if obj.Episode>0
                obj.finishCut('reconfigure');
                obj.Completed{end+1}=obj.record();
                if numel(obj.Completed)>old.maxRetainedEpisodes
                    obj.Completed(1)=[]; obj.DroppedEpisodes=obj.DroppedEpisodes+1;
                end
            end
            oldEpisode=obj.Episode; obj.Episode=0;
            obj.Options.mode=mode; obj.Options.controller=controller;
            obj.Options.sensorNoiseScale=noiseScale;
            obj.reset(); obj.Episode=oldEpisode+1;
        end

        function refresh(obj)
            if obj.ActiveCut>0 && obj.Env.time>=obj.CutEvents(obj.ActiveCut).plannedEnd-1e-9
                obj.finishCut('expired');
            end
            for m=1:numel(obj.Agents)
                intervention=[];
                if obj.ActiveCut>0
                    cut=obj.CutEvents(obj.ActiveCut);
                    if strcmp(obj.MethodIds{m},cut.methodId)
                        keep=true(obj.Agents{m}.encoderSpec.T.nEdges,1); keep(cut.edgeIds)=false;
                        intervention=struct('actorKeep',[],'criticKeep',[]);
                        if ismember(cut.head,{'actor','both'}), intervention.actorKeep=keep; end
                        if ismember(cut.head,{'critic','both'}), intervention.criticKeep=keep; end
                    end
                end
                obj.Current{m}=landing2d.livetest.infer(obj.Agents{m},obj.Arms{m}, ...
                    obj.Observation,obj.Env.observationContext,intervention);
            end
            obj.CurrentCutId=obj.ActiveCut; obj.InferenceTime=obj.Env.time;
            obj.InferenceObservation=obj.Observation;
        end

        function captureBaseline(obj)
            obj.Baseline=obj.Current; obj.BaselineTime=obj.Env.time;
        end

        function [ok,message]=cut(obj,methodId,head,scope,target,duration)
            % One temporary diagnostic at a time, isolated from stored agents.
            head=validatestring(head,{'actor','critic','both'});
            validateattributes(duration,{'numeric'},{'scalar','real','finite','>=',.1,'<=',60});
            m=find(strcmp(obj.MethodIds,methodId),1);
            assert(~isempty(m)&&~isempty(obj.Current{m}.graph), ...
                'landing2d:LiveTestCutTarget','Select a loaded graph model.');
            edges=landing2d.livetest.cutEdges(obj.Current{m}.graph,scope,target);
            ok=false;
            if obj.done(), message='에피소드 종료: 다시 시작하세요.'; return; end
            if obj.ActiveCut>0, message='이미 단절 중입니다. 자동 복구를 기다리거나 즉시 복구하세요.'; return; end
            if obj.Env.time+duration>obj.Env.scenario.deadline+1e-9
                message='남은 시간이 부족합니다. 단절 시간을 줄이거나 다시 시작하세요.'; return;
            end
            obj.captureBaseline(); before=obj.Current{m}; id=numel(obj.CutEvents)+1;
            obj.CutEvents(id)=struct('id',id,'methodId',methodId,'head',head, ...
                'scope',scope,'target',target,'edgeIds',edges,'start',obj.Env.time, ...
                'plannedEnd',obj.Env.time+duration,'actualEnd',NaN,'endReason','active', ...
                'beforeRequest',before.request,'afterRequest',[NaN;NaN], ...
                'beforeValue',before.value,'afterValue',NaN);
            obj.ActiveCut=id; obj.refresh();
            obj.CutEvents(id).afterRequest=obj.Current{m}.request;
            obj.CutEvents(id).afterValue=obj.Current{m}.value;
            obj.writeInferenceLog(obj.Log.count); % replace current decision, not duplicate time
            ok=true;
            message=sprintf('%s / %s: %d개 간선 α=0, %.1f s 후 자동 복구 (재정규화 없음).', ...
                methodId,head,numel(edges),duration);
        end

        function restoreCut(obj)
            if obj.ActiveCut==0, return; end
            obj.finishCut('manual'); obj.refresh(); obj.writeInferenceLog(obj.Log.count);
        end

        function [ok,message]=pulse(obj,acceleration,duration,coast)
            validateattributes(acceleration,{'numeric'},{'scalar','real','finite'});
            validateattributes(duration,{'numeric'},{'scalar','real','finite','positive'});
            validateattributes(coast,{'numeric'},{'scalar','real','finite','nonnegative'});
            ok=false; t=obj.Env.time; p=obj.Env.scenario;
            if obj.done(), message='에피소드 종료: 다시 시작하세요.'; return; end
            if ~isempty(p.liveAccelerationPulses) && ...
                    t<max(sum(p.liveAccelerationPulses(:,1:2),2))-1e-9
                message='이전 급가속/자동 감속이 끝난 뒤 다시 누르세요.'; return;
            end
            peak=obj.Env.pad.vx+acceleration*duration;
            if peak<0 || peak>obj.Options.maxPadSpeed
                message=sprintf('속도 범위 0–%.1f m/s를 벗어납니다. 가속도/시간을 줄이세요.',obj.Options.maxPadSpeed);
                return;
            end
            if t+2*duration+coast>=p.deadline
                message='남은 시간이 부족합니다. 다시 시작하세요.'; return;
            end
            obj.captureBaseline();
            p.liveAccelerationPulses=[p.liveAccelerationPulses; ...
                t,duration,acceleration;t+duration+coast,duration,-acceleration];
            obj.Env.scenario=p; obj.Env.config.experiment.currentScenario=p;
            obj.Env.pad=landing2d.scenario.padState(p,t);
            obj.Events(end+1)=struct('time',t,'acceleration',acceleration,'duration',duration,'coast',coast);
            ok=true;
            message=sprintf('t=%.1f s: %+.2f m/s² × %.1f s → %.1f s 유지 → 자동 감속. Δα 기준 고정.', ...
                t,acceleration,duration,coast);
        end

        function step(obj)
            if obj.done(), return; end
            appliedCut=0;
            if strcmp(obj.Options.mode,'policy')
                m=find(strcmp(obj.MethodIds,obj.Options.controller),1);
                applied=obj.Current{m}.request;
                if any(obj.Current{m}.actorCut), appliedCut=obj.CurrentCutId; end
            else
                applied=obj.holdCommand();
            end
            limits=landing2d.environment.actionLimits(obj.Config);
            [obj.Env,obj.Observation]=landing2d.environment.step(obj.Env,applied./limits);
            % No post-terminal policy action: display the last inference as frozen.
            if ~obj.done(), obj.refresh(); else, obj.finishCut('terminal'); end
            obj.appendLog(applied);
            obj.Log.appliedIntervention(obj.Log.count)=appliedCut;
        end

        function yes=done(obj)
            yes=obj.Env.episodeStatus.terminated || obj.Env.episodeStatus.truncated;
        end

        function command=holdCommand(obj)
            % Separate causal TEST DRIVER, never claimed to be the trained policy.
            O=obj.Env.commonObservation; G=obj.Env.observationContext;
            d=O.drone; u=O.ugv; ax=0; az=-2.4*d.velocityXZ(2);
            if u.estimateInitialized
                pad=u.positionXZ+G.ugv.padOffset(:);
                h=d.positionXZ(2)-pad(2);
                targetX=pad(1)+h*tan(obj.Config.experiment.sensor.cameraPitchOffset);
                ax=1.2*(targetX-d.positionXZ(1))+1.8*(u.velocityXZ(1)-d.velocityXZ(1));
                az=1.4*(obj.Options.height-h)-2.4*d.velocityXZ(2);
            end
            limits=landing2d.environment.actionLimits(obj.Config);
            command=min(max([ax;az],-limits),limits);
        end

        function r=record(obj)
            log=obj.Log; n=log.count;
            for f=["time","truth","observation","policyObservation","visible","visionAge","applied", ...
                    "values","nominalValues","inferenceTime","intervention","appliedIntervention"]
                log.(f)=log.(f)(:,1:n);
            end
            log.requests=log.requests(:,:,1:n);
            log.nominalRequests=log.nominalRequests(:,:,1:n);
            for f=["actor","critic","nodeActor","nodeCritic","actorCut","criticCut"]
                for m=1:numel(log.(f)), log.(f){m}=log.(f){m}(:,1:n); end
            end
            r=struct('episode',obj.Episode,'options',obj.Options,'log',log, ...
                'events',obj.Events,'scenario',obj.Env.scenario,'manifest',obj.Manifest, ...
                'status',obj.Env.episodeStatus,'lastInference', {obj.Current}, ...
                'baseline',{obj.Baseline},'baselineTime',obj.BaselineTime, ...
                'cuts',obj.CutEvents,'activeCut',obj.ActiveCut);
        end

        function file=save(obj)
            root=landing2d.orchestration.projectRoot(); folder=fullfile(root,'results','live_attention');
            if ~isfolder(folder), mkdir(folder); end
            file=fullfile(folder,['live_attention_',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')),'.mat']);
            output=struct('schemaVersion','live_attention_v2','identities',{obj.Identities}, ...
                'methodIds',{obj.MethodIds},'completed',{obj.Completed},'current',obj.record(), ...
                'droppedEpisodes',obj.DroppedEpisodes, ...
                'nodeMetric','mean outgoing edge alpha excluding self; not causal importance', ...
                'truthRows',{{'droneX','droneZ','droneVx','droneVz','padX','padVx','padAx','theta'}}, ...
                'interventionRule','post-softmax zero, no renormalization; local W0 path remains; inference-only', ...
                'counterfactual','nominal output at SAME current observation, not a separate unperturbed rollout', ...
                'alignment',['requests/attention/policyObservation at inferenceTime; observation at time; ' ...
                    'applied/appliedIntervention refer to previous interval; ' ...
                    'terminal inference held; cuts record button-time before/after outputs; duration uses simulation time']);
            save(file,'output','-v7.3');
        end
    end
    methods (Access=private)
        function finishCut(obj,reason)
            if obj.ActiveCut==0, return; end
            obj.CutEvents(obj.ActiveCut).actualEnd=obj.Env.time;
            obj.CutEvents(obj.ActiveCut).endReason=reason;
            obj.ActiveCut=0;
        end

        function appendLog(obj,applied)
            k=obj.Log.count+1; obj.Log.count=k; e=obj.Env; d=e.physicalState;
            obj.Log.time(k)=e.time;
            obj.Log.truth(:,k)=[d.x;d.z;d.vx;d.vz;e.pad.x;e.pad.vx;e.pad.ax;d.theta];
            obj.Log.observation(:,k)=obj.Observation;
            obj.Log.visible(k)=e.commonObservation.ugv.visionUpdated;
            obj.Log.visionAge(k)=e.commonObservation.ugv.visionAge;
            obj.Log.applied(:,k)=applied;
            obj.writeInferenceLog(k);
        end

        function writeInferenceLog(obj,k)
            obj.Log.inferenceTime(k)=obj.InferenceTime;
            obj.Log.policyObservation(:,k)=obj.InferenceObservation;
            obj.Log.intervention(k)=obj.CurrentCutId;
            for m=1:numel(obj.Current)
                q=obj.Current{m}; obj.Log.requests(:,m,k)=q.request;
                obj.Log.nominalRequests(:,m,k)=q.nominalRequest;
                obj.Log.values(m,k)=q.value; obj.Log.nominalValues(m,k)=q.nominalValue;
                obj.Log.actor{m}(:,k)=q.actorAlpha; obj.Log.critic{m}(:,k)=q.criticAlpha;
                obj.Log.nodeActor{m}(:,k)=q.actorNode; obj.Log.nodeCritic{m}(:,k)=q.criticNode;
                obj.Log.actorCut{m}(:,k)=q.actorCut; obj.Log.criticCut{m}(:,k)=q.criticCut;
            end
        end
    end
end
