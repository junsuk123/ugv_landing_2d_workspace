function out = verticalResponseProbe(runs,c)
% VERTICALRESPONSEPROBE Validation-only noise and signed response diagnostics.
% Read-only. Uses policy-independent reference trajectories, validation seeds,
% and each checkpoint's own graph features. No policy action is fed back.
% The vertical slope is positive for corrective feedback: a_z(-0.5)>a_z(+0.5).
% Neither this slope nor noise alone establishes closed-loop tracking quality.
c.experiment.manifest.testSeeds=c.experiment.manifest.validationSeeds;
P=landing2d.evaluation.buildProbeSet(c);
G=P.context; nP=numel(P.noise); R=numel(P.noise(1).O);
V=zeros(10,R,nP);
for i=1:nP
    for j=1:R, V(:,j,i)=landing2d.observation.toVector(P.noise(i).O{j},G); end
end
V0=reshape(V(:,1,:),10,nP);
names=landing2d.observation.vectorSchema(G).names;
vx=find(strcmp(names,'relative_vx')); vz=find(strcmp(names,'drone_vz'));
limits=landing2d.environment.actionLimits(c);
rows=cell(1,numel(runs));
for r=1:numel(runs)
    run=runs(r);
    a=actions(run,reshape(V,10,[]),G,limits);
    noise=reshape(var(reshape(a,2,R,nP),0,2),2,nP);
    ax=zeros(1,3); az=zeros(1,3);
    for k=1:3
        speed=k-2; Vk=V0; Vk(vx,:)=speed/(abs(speed)+G.normalization.vx);
        ak=actions(run,Vk,G,limits); ax(k)=mean(ak(1,:));
        speed=0.5*(k-2); Vk=V0; Vk(vz,:)=speed/(abs(speed)+G.normalization.vz);
        ak=actions(run,Vk,G,limits); az(k)=mean(ak(2,:));
    end
    rows{r}=table(string(run.id),run.trainSeed,mean(sum(noise,1)),mean(noise(2,:)), ...
        ax(1),ax(2),ax(3),all(diff(ax)>0),az(1),az(2),az(3),all(diff(az)<0),az(1)-az(3), ...
        'VariableNames',{'MethodId','TrainSeed','NoiseActionVar','NoiseActionVarAz', ...
        'AxAtVrelMinus1','AxAtVrel0','AxAtVrelPlus1','SignCorrect', ...
        'AzAtVzMinusHalf','AzAtVz0','AzAtVzPlusHalf','VerticalSignCorrect','VerticalSensitivity'});
end
out=struct('runs',vertcat(rows{:}),'meta',P.meta);
end

function a=actions(run,V,G,limits)
if strcmp(run.agent.encoderSpec.mode,'baseline')
    policyInput=V;
else
    policyInput=zeros(run.agent.encoderSpec.stateDim,size(V,2));
    for k=1:size(V,2)
        policyInput(:,k)=landing2d.graphstate.observationVectorGraph(V(:,k),G,run.config);
    end
end
[~,~,mu]=landing2d.rl.policyAction(run.agent,policyInput,[],true);
a=limits(:).*tanh(mu);
end
