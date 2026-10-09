function out = closedLoopRobustness(c,options)
% CLOSEDLOOPROBUSTNESS  Paired closed-loop mission robustness over noise scale.
% The same manifest seeds and the same time-indexed standard-normal sensor
% samples are reused at every scale and for every policy. This isolates policy
% response from scenario and random-noise sampling differences.
if nargin<2, options=struct(); end
registry=landing2d.config.methodRegistry();
known=[registry.methods,registry.ablations];
defaults=struct('split','validation','methods',{{registry.methods.id}}, ...
    'trainSeeds',1,'graphSeeds',1,'scales',c.consistency.noiseScales, ...
    'episodeCount',c.consistency.probe.validationEpisodeCount, ...
    'referenceMethod','ppo','bootstrapSamples',10000,'bootstrapSeed',912731);
names=fieldnames(options);
for i=1:numel(names)
    assert(isfield(defaults,names{i}),'landing2d:RobustnessOption', ...
        'Unknown option %s.',names{i});
    defaults.(names{i})=options.(names{i});
end
o=defaults;
validateattributes(o.scales,{'numeric'},{'vector','real','finite','nonnegative'});
validateattributes(o.episodeCount,{'numeric'},{'scalar','integer','positive'});
validateattributes(o.bootstrapSamples,{'numeric'},{'scalar','integer','positive'});
switch o.split
    case 'validation', manifestSeeds=c.experiment.manifest.validationSeeds;
    case 'test', manifestSeeds=c.experiment.manifest.testSeeds;
    otherwise, error('landing2d:ProbeSplit','Unknown split %s.',o.split);
end
assert(o.episodeCount<=numel(manifestSeeds),'landing2d:RobustnessCount', ...
    'Requested more episodes than the frozen manifest contains.');
seeds=manifestSeeds(1:o.episodeCount);
episodes=table(); perRun=table(); missing=strings(0,1);
for m=1:numel(o.methods)
    index=find(strcmp({known.id},o.methods{m}),1);
    assert(~isempty(index),'landing2d:RobustnessMethod', ...
        'Unknown registered method %s.',o.methods{m});
    method=known(index);
    graphSeeds=NaN;
    if ~strcmp(method.graphPerturbation,'none'), graphSeeds=o.graphSeeds; end
    for g=graphSeeds(:)'
        for trainSeed=o.trainSeeds(:)'
            arm=landing2d.config.applyMethod(c,method.id,trainSeed,g);
            [agent,~,file,ok]=landing2d.consistency.loadRun(arm);
            if ~ok
                missing(end+1,1)=string(arm.rl.policyFile); %#ok<AGROW>
                continue;
            end
            run=landing2d.rl.runIdentity(agent,arm,file);
            for scale=o.scales(:)'
                [results,~,info]=landing2d.rl.evaluateV2(agent,arm,seeds, ...
                    struct('sensorNoiseScale',scale));
                reason=string({results.terminalReason})';
                landed=reason=="SUCCESS";
                unsafe=ismember(reason,["UNSAFE_CONTACT","UNAUTHORIZED_CONTACT", ...
                    "MISSED_PAD_CONTACT","SAFETY_ENVELOPE_VIOLATION"]);
                timeout=reason=="TASK_TIMEOUT";
                returns=info.returns(:);
                n=numel(seeds);
                id=table(repmat(string(method.id),n,1),repmat(trainSeed,n,1), ...
                    repmat(g,n,1),repmat(scale,n,1),seeds(:), ...
                    'VariableNames',{'MethodId','TrainSeed','GraphSeed', ...
                    'NoiseScale','EpisodeSeed'});
                episodes=[episodes;[id,table(landed,unsafe,timeout,returns,reason, ...
                    'VariableNames',{'Landed','Unsafe','Timeout','Return', ...
                    'TerminalReason'})]]; %#ok<AGROW>
                perRun=[perRun;table(string(method.id),trainSeed,g,scale,n, ...
                    100*mean(landed),100*mean(unsafe),100*mean(timeout), ...
                    mean(returns),string(run.GraphHash), ...
                    'VariableNames',{'MethodId','TrainSeed','GraphSeed', ...
                    'NoiseScale','Episodes','LandingPct','UnsafePct', ...
                    'TimeoutPct','MeanReturn','GraphHash'})]; %#ok<AGROW>
            end
        end
    end
end
paired=pairedEvidence(episodes,o);
out=struct('schemaVersion','closed_loop_noise_robustness_v1', ...
    'split',o.split,'scales',o.scales,'seeds',seeds,'episodes',episodes, ...
    'perRun',perRun,'paired',paired,'missing',missing,'options',o);
end

function paired=pairedEvidence(E,o)
paired=table();
if isempty(E), return; end
methods=unique(E.MethodId,'stable');
assert(any(methods==string(o.referenceMethod)), ...
    'landing2d:RobustnessReference','Reference method is missing.');
rs=RandStream('threefry','Seed',o.bootstrapSeed);
for m=1:numel(methods)
    if methods(m)==string(o.referenceMethod), continue; end
    for scale=o.scales(:)'
        ref=E(E.MethodId==string(o.referenceMethod) & E.NoiseScale==scale,:);
        alt=E(E.MethodId==methods(m) & E.NoiseScale==scale,:);
        [common,ir,ia]=intersect(ref.EpisodeSeed,alt.EpisodeSeed,'stable');
        if isempty(common), continue; end
        d=double(alt.Landed(ia))-double(ref.Landed(ir));
        dr=alt.Return(ia)-ref.Return(ir);
        ci=bootstrapMean(d,o.bootstrapSamples,rs);
        returnCi=bootstrapMean(dr,o.bootstrapSamples,rs);
        altOnly=sum(d==1); refOnly=sum(d==-1);
        p=mcnemarExact(altOnly,refOnly);
        paired=[paired;table(methods(m),string(o.referenceMethod),scale, ...
            numel(common),100*mean(d),100*ci(1),100*ci(2),altOnly,refOnly,p, ...
            mean(dr),returnCi(1),returnCi(2), ...
            'VariableNames',{'MethodId','ReferenceMethod','NoiseScale', ...
            'PairedEpisodes','LandingDiffPct','LandingDiffCiLow', ...
            'LandingDiffCiHigh','MethodOnlySuccess','ReferenceOnlySuccess', ...
            'McNemarP','ReturnDiff','ReturnDiffCiLow','ReturnDiffCiHigh'})]; %#ok<AGROW>
    end
end
end

function ci=bootstrapMean(x,B,rs)
n=numel(x); means=zeros(B,1); block=1000;
for first=1:block:B
    count=min(block,B-first+1);
    index=randi(rs,n,n,count);
    means(first:first+count-1)=reshape(mean(x(index),1),[],1);
end
means=sort(means);
lo=max(1,ceil(0.025*B)); hi=min(B,ceil(0.975*B));
ci=[means(lo),means(hi)];
end

function p=mcnemarExact(a,b)
n=a+b;
if n==0, p=1; return; end
k=min(a,b); j=(0:k)';
logp=gammaln(n+1)-gammaln(j+1)-gammaln(n-j+1)-n*log(2);
p=min(1,2*sum(exp(logp)));
end
