function A = analyze(newEpisodes,v5Episodes,learning,d)
% ANALYZE Paired new - v5 differences, seed-block intervals and the registered verdict.
% Episodes pair on (MethodId, TrainSeed, Factor, Shift, EpisodeSeed). Per model
% the mean over the environments of dS = 100 (S_new - S_v5), dU = 100 (U_new -
% U_v5) [%p] and dE = E_new - E_v5 [m] (aim RMS); per training seed the
% equal-weight mean of the four methods (seed block); t intervals over the
% five blocks (df = 4) at the registered confidence (risk comparisons at
% riskConfidence). LEARNING: one row per method with Reached80 and Selected80.
% Criteria L/G/K/N/H and the verdict follow config.m; checks lists every component.
keyNames = {'MethodId','TrainSeed','Factor','Shift','EpisodeSeed'};
fields = {'Success','Unsafe','AimErrorRMS_m','Duration_s','CommandRateRMS_mps3'};
newEpisodes = normalize(newEpisodes); v5Episodes = normalize(v5Episodes);
a = renamevars(newEpisodes(:,[keyNames,fields]),fields,strcat(fields,'_new'));
b = renamevars(v5Episodes(:,[keyNames,fields]),fields,strcat(fields,'_v5'));
P = innerjoin(a,b,'Keys',keyNames);
assert(height(P)==height(a) && height(P)==numel(d.methods)*numel(d.trainSeeds)* ...
    size(d.cells,1)*numel(d.environmentSeeds),'landing2d:AccelRangePairs', ...
    'Every new episode needs exactly one v5 episode (%d of %d).',height(P),height(a));
P.dS = 100*(P.Success_new-P.Success_v5);
P.dU = 100*(P.Unsafe_new-P.Unsafe_v5);
P.dE = P.AimErrorRMS_m_new-P.AimErrorRMS_m_v5;
assert(all(isfinite([P.dS;P.dU;P.dE])),'landing2d:AccelRangeFinite','Non-finite paired difference.');

modelKeys = {'MethodId','TrainSeed','Factor','Shift'};
means = setdiff(P.Properties.VariableNames,keyNames,'stable');
byModel = groupsummary(P,modelKeys,'mean',means);
byModel = renamevars(byModel,strcat('mean_',means),means);
byModel = renamevars(byModel,'GroupCount','Environments');
for v = {'Success_new','Success_v5','Unsafe_new','Unsafe_v5'}
    byModel.(v{1}) = 100*byModel.(v{1});
end
metrics = {'dS','dU','dE'};
bySeed = groupsummary(byModel,{'TrainSeed','Factor','Shift'},'mean',metrics);
assert(all(bySeed.GroupCount==numel(d.methods)),'landing2d:AccelRangePairs', ...
    'Each seed block needs all four methods.');
bySeed = renamevars(removevars(bySeed,'GroupCount'),strcat('mean_',metrics),metrics);
k = d.criteria;
cells = interval(bySeed,{'Factor','Shift'},metrics,k.confidence);
risk = interval(bySeed,{'Factor','Shift'},{'dS','dU'},k.riskConfidence);
byMethod = interval(byModel,{'MethodId','Factor','Shift'},metrics,k.confidence);
levels = groupsummary(byModel,{'Factor','Shift'},'mean',{'Success_v5','Success_new', ...
    'Unsafe_v5','Unsafe_new','AimErrorRMS_m_v5','AimErrorRMS_m_new','Duration_s_v5', ...
    'Duration_s_new','CommandRateRMS_mps3_v5','CommandRateRMS_mps3_new'});
levels = removevars(levels,'GroupCount');
levels.Properties.VariableNames = erase(levels.Properties.VariableNames,'mean_');
did = table();
for f = ["motion","dropout","noise"]
    o = sortrows(bySeed(bySeed.Factor==f & bySeed.Shift=="OOD",:),'TrainSeed');
    i = sortrows(bySeed(bySeed.Factor==f & bySeed.Shift=="ID",:),'TrainSeed');
    assert(isequal(o.TrainSeed,i.TrainSeed));
    did = [did;table(repmat(f,height(o),1),o.TrainSeed,o.dS-i.dS,o.dU-i.dU,o.dE-i.dE, ...
        'VariableNames',{'Factor','TrainSeed','dS','dU','dE'})]; %#ok<AGROW>
end
didSummary = interval(did,{'Factor'},metrics,k.confidence);
[checks,verdict,flags] = criteria(learning,cells,risk,byMethod,k);
outcomes = [newEpisodes(:,{'Factor','Shift','FailureClass'});v5Episodes(:,{'Factor','Shift','FailureClass'})];
outcomes.Model = [repmat("new",height(newEpisodes),1);repmat("v5",height(v5Episodes),1)];
failures = groupsummary(outcomes,{'Factor','Shift','Model','FailureClass'});
failures = renamevars(failures,'GroupCount','Episodes');
A = struct('pairs',P,'byModel',byModel,'bySeed',bySeed,'cells',cells,'risk',risk, ...
    'byMethod',byMethod,'levels',levels,'didBySeed',did,'did',didSummary, ...
    'learning',learning,'failures',failures,'checks',checks,'verdict',verdict,'flags',flags);
end

function T = normalize(T)
for v = {'MethodId','Factor','Shift','FailureClass'}
    T.(v{1}) = string(T.(v{1}));
end
end

function S = interval(T,groups,metrics,confidence)
% Mean, two-sided t interval at CONFIDENCE and positive count per group.
[g,S] = findgroups(T(:,groups));
for m = metrics
    x = T.(m{1});
    S.([m{1},'_mean']) = splitapply(@mean,x,g);
    S.([m{1},'_n']) = splitapply(@numel,x,g);
    hw = splitapply(@(v)halfWidth(std(v),numel(v),1-confidence),x,g);
    S.([m{1},'_low']) = S.([m{1},'_mean'])-hw;
    S.([m{1},'_high']) = S.([m{1},'_mean'])+hw;
    S.([m{1},'_positive']) = splitapply(@(v)sum(v>0),x,g);
end
end

function hw = halfWidth(sd,n,alpha)
q = betaincinv(alpha,(n-1)/2,0.5);                   % two-sided t quantile at 1 - alpha
hw = sqrt((n-1)*(1-q)/q)*sd/sqrt(n);
end

function [checks,verdict,flags] = criteria(learning,cells,risk,byMethod,k)
rows = {};
    function ok = addCheck(criterion,component,value,rule,ok)
        rows{end+1} = table(string(criterion),string(component),value,string(rule),ok, ...
            'VariableNames',{'Criterion','Component','Value','Rule','Pass'});
    end
    function out = cellStat(T,fac,sh,met,part)
        out = T.([met,'_',part])(T.Factor==fac & T.Shift==sh);
        assert(isscalar(out));
    end
lr = [];
for i = 1:height(learning)
    lr(end+1) = addCheck('L',learning.MethodId(i)+" Reached80 seeds",learning.Reached80(i), ...
        sprintf('>= %d',k.reached80),learning.Reached80(i)>=k.reached80); %#ok<AGROW>
    lr(end+1) = addCheck('L',learning.MethodId(i)+" Selected80 seeds",learning.Selected80(i), ...
        sprintf('>= %d',k.selected80),learning.Selected80(i)>=k.selected80); %#ok<AGROW>
end
L = numel(lr)==8 && all(lr);
g = [addCheck('G','motion OOD dS mean [%p]',cellStat(cells,"motion","OOD",'dS','mean'), ...
        sprintf('>= %g',k.gainS),cellStat(cells,"motion","OOD",'dS','mean')>=k.gainS), ...
     addCheck('G','motion OOD dS 95% low [%p]',cellStat(cells,"motion","OOD",'dS','low'), ...
        '> 0',cellStat(cells,"motion","OOD",'dS','low')>0)];
G = all(g);
methodIds = unique(byMethod.MethodId,'stable');
kk = false(1,numel(methodIds));
for m = 1:numel(methodIds)
    low = byMethod.dS_low(byMethod.MethodId==methodIds(m) & byMethod.Factor=="motion" & byMethod.Shift=="OOD");
    kk(m) = addCheck('K',methodIds(m)+" motion OOD dS 95% low [%p]",low,'> 0',low>0);
end
K = G && numel(kk)==4 && all(kk);
n = true;
for i = 1:height(byMethod)
    label = byMethod.MethodId(i)+" "+byMethod.Factor(i)+" "+byMethod.Shift(i);
    n = addCheck('N',label+" dS 95% low [%p]",byMethod.dS_low(i),sprintf('>= -%g',k.marginS), ...
        byMethod.dS_low(i)>=-k.marginS) && n;
    n = addCheck('N',label+" dU 95% high [%p]",byMethod.dU_high(i),sprintf('<= %g',k.marginU), ...
        byMethod.dU_high(i)<=k.marginU) && n;
end
N = n && height(byMethod)==24;
H = false;
for f = ["noise","dropout"]
    s = [addCheck('H',f+" OOD dS mean [%p]",cellStat(risk,f,"OOD",'dS','mean'),sprintf('<= -%g',k.harmS), ...
            cellStat(risk,f,"OOD",'dS','mean')<=-k.harmS), ...
         addCheck('H',f+" OOD dS 98.75% high [%p]",cellStat(risk,f,"OOD",'dS','high'),'< 0', ...
            cellStat(risk,f,"OOD",'dS','high')<0)];
    u = [addCheck('H',f+" OOD dU mean [%p]",cellStat(risk,f,"OOD",'dU','mean'),sprintf('>= %g',k.harmU), ...
            cellStat(risk,f,"OOD",'dU','mean')>=k.harmU), ...
         addCheck('H',f+" OOD dU 98.75% low [%p]",cellStat(risk,f,"OOD",'dU','low'),'> 0', ...
            cellStat(risk,f,"OOD",'dU','low')>0)];
    H = H || all(s) || all(u);
end
if ~L, verdict = "training_failure";
elseif G && H, verdict = "trade_off_supported";
elseif G && N, verdict = "improved_within_registered_margins";
elseif G, verdict = "gain_with_unresolved_risk";
else, verdict = "insufficient_evidence_of_improvement";
end
checks = vertcat(rows{:});
flags = struct('L',L,'G',G,'K',K,'N',N,'H',H,'common',L && K);
end
