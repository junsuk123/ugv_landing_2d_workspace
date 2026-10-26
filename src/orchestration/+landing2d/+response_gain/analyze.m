function A = analyze(P0,P1,B0,B1,link,d)
% ANALYZE Paired R1 - v5 response diagnostics (config.m fixes metrics and rules).
% P0/P1: probe rows (v5/R1, landing2d.bias_diagnostics.probeResponses);
% B0/B1: branch rows; LINK: R1 byModel.csv (motion OOD dS per model).
keys = {'MethodId','TrainSeed','Family'};
M0 = perModel(P0,d); M1 = perModel(P1,d);
metrics = setdiff(M0.Properties.VariableNames,[keys,{'States','StaleStates'}],'stable');
a = renamevars(M0,metrics,strcat(metrics,'_v5')); b = renamevars(M1,metrics,strcat(metrics,'_r1'));
a = renamevars(a,{'States','StaleStates'},{'States_v5','StaleStates_v5'});
b = renamevars(b,{'States','StaleStates'},{'States_r1','StaleStates_r1'});
byModel = innerjoin(a,b,'Keys',keys);
assert(height(byModel)==height(M0) && height(M0)==height(M1) && isequal(byModel.States_v5,byModel.States_r1), ...
    'landing2d:ResponseGainPairs','Models and states must pair one to one.');
for m = metrics
    byModel.(['d',m{1}]) = byModel.([m{1},'_r1'])-byModel.([m{1},'_v5']);
end
deltas = strcat('d',metrics);
bySeed = groupsummary(byModel,{'TrainSeed','Family'},'mean',deltas);
assert(all(bySeed.GroupCount==numel(d.methods)));
bySeed = renamevars(removevars(bySeed,'GroupCount'),strcat('mean_',deltas),deltas);
summary = interval(bySeed,{'Family'},deltas,d.confidence);
direction = interval(bySeed(bySeed.Family==d.primaryFamily,:),{'Family'},strcat('d',d.primary),d.directionConfidence);
labels = strings(numel(d.primary),1); rows = cell(numel(d.primary),1);
for k = 1:numel(d.primary)
    m = ['d',d.primary{k}];
    low = direction.([m,'_low']); high = direction.([m,'_high']);
    if low>0, labels(k) = "increase in the reference direction";
    elseif high<0, labels(k) = "decrease in the reference direction";
    else, labels(k) = "no change detected";
    end
    rows{k} = table(string(d.primary{k}),direction.([m,'_mean']),low,high,labels(k), ...
        'VariableNames',{'Metric','Mean','BonferroniLow','BonferroniHigh','Label'});
end
verdicts = vertcat(rows{:});
levels = groupsummary(byModel,{'MethodId','Family'},'mean',[strcat(metrics,'_v5'),strcat(metrics,'_r1')]);
levels.Properties.VariableNames = erase(levels.Properties.VariableNames,'mean_');
byMethod = interval(byModel,{'MethodId','Family'},deltas,d.confidence);
[branchModel,branchCommon,branchCounts] = branches(B0,B1);
branchSeed = groupsummary(branchCommon,{'TrainSeed','Point'},'mean',{'dPolicyBestReturn','dAdvantagePlus'});
branchSeed = renamevars(branchSeed,{'mean_dPolicyBestReturn','mean_dAdvantagePlus'},{'dPolicyBestReturn','dAdvantagePlus'});
branchSummary = interval(branchSeed,{'Point'},{'dPolicyBestReturn','dAdvantagePlus'},d.confidence);
L = link(link.Factor=="motion" & link.Shift=="OOD",{'MethodId','TrainSeed','dS'});
L.MethodId = string(L.MethodId);
J = innerjoin(byModel(byModel.Family==d.primaryFamily,{'MethodId','TrainSeed','dRugvX','dRposX','dRdroneXNeg'}),L, ...
    'Keys',{'MethodId','TrainSeed'});
assert(height(J)==numel(d.methods)*numel(d.trainSeeds));
correlation = table(["dRugvX";"dRposX";"dRdroneXNeg"], ...
    [landing2d.bias_diagnostics.spearman(J.dRugvX,J.dS);landing2d.bias_diagnostics.spearman(J.dRposX,J.dS); ...
    landing2d.bias_diagnostics.spearman(J.dRdroneXNeg,J.dS)],repmat(height(J),3,1), ...
    'VariableNames',{'Response','SpearmanWithMotionOODdS','Models'});
A = struct('byModel',byModel,'bySeed',bySeed,'summary',summary,'direction',direction, ...
    'verdicts',verdicts,'levels',levels,'byMethod',byMethod,'branchModel',branchModel, ...
    'branchCommon',branchCommon,'branchCounts',branchCounts,'branchSeed',branchSeed, ...
    'branchSummary',branchSummary,'link',J,'correlation',correlation);
end

function T = perModel(P,d)
% State means per model and family (same reduction as the Q2 by_seed table).
P.MethodId = string(P.MethodId); P.Family = string(P.Family);
P.RdroneXNeg = -P.RdroneX;
names = d.secondary;
[g,T] = findgroups(P(:,{'MethodId','TrainSeed','Family'}));
for m = names, T.(m{1}) = splitapply(@(x)mean(x,'omitnan'),double(P.(m{1})),g); end
T.States = splitapply(@numel,P.RugvX,g);
T.StaleStates = splitapply(@(x)sum(~isnan(x)),P.StaleDeltaX,g);
ratio = {'RugvX','ReferenceRugvX';'RposX','ReferenceRposX';'RdroneX','ReferenceRdroneX';'StaleDeltaX','ReferenceStaleDeltaX'};
for k = 1:size(ratio,1)
    den = T.(ratio{k,2}); r = T.(ratio{k,1})./den; r(den==0) = NaN;
    T.([ratio{k,1},'ToReference']) = r;
end
end

function [model,common,counts] = branches(B0,B1)
% Per key (method, seed, environment, point): PolicyBestReturn (ties count),
% AdvantagePlus/Minus and outcomes; model means over all reached keys and
% paired R1 - v5 means over the keys reached by both.
K0 = keyTable(B0); K1 = keyTable(B1);
keys = {'MethodId','TrainSeed','EnvironmentSeed','Point'};
vals = {'PolicyBestReturn','AdvantagePlus','AdvantageMinus','SuccessPolicy','SuccessPlus'};
model = [summarizeKeys(K0,"v5",vals);summarizeKeys(K1,"r1",vals)];
J = innerjoin(renamevars(K0,vals,strcat(vals,'_v5')),renamevars(K1,vals,strcat(vals,'_r1')),'Keys',keys);
for v = vals, J.(['d',v{1}]) = J.([v{1},'_r1'])-J.([v{1},'_v5']); end
[g,common] = findgroups(J(:,{'MethodId','TrainSeed','Point'}));
for v = strcat('d',vals), common.(v{1}) = splitapply(@mean,J.(v{1}),g); end
common.CommonKeys = splitapply(@numel,J.dPolicyBestReturn,g);
[g0,c0] = findgroups(K0(:,{'MethodId','TrainSeed','Point'})); c0.Reached_v5 = splitapply(@numel,K0.PolicyBestReturn,g0);
[g1,c1] = findgroups(K1(:,{'MethodId','TrainSeed','Point'})); c1.Reached_r1 = splitapply(@numel,K1.PolicyBestReturn,g1);
counts = outerjoin(c0,c1,'Keys',{'MethodId','TrainSeed','Point'},'MergeKeys',true);
counts = outerjoin(counts,common(:,{'MethodId','TrainSeed','Point','CommonKeys'}), ...
    'Keys',{'MethodId','TrainSeed','Point'},'MergeKeys',true);
end

function K = keyTable(B)
B.MethodId = string(B.MethodId); B.Point = string(B.Point);
[g,K] = findgroups(B(:,{'MethodId','TrainSeed','EnvironmentSeed','Point'}));
value = @(field,delta)splitapply(@(dl,v)pick(dl,v,delta),B.Delta,B.(field),g);
R0 = value('ReturnToGo',0); Rm = value('ReturnToGo',-0.25); Rp = value('ReturnToGo',0.25);
K.PolicyBestReturn = double(R0>=max(Rm,Rp)); K.AdvantagePlus = Rp-R0; K.AdvantageMinus = Rm-R0;
K.SuccessPolicy = value('Success',0); K.SuccessPlus = value('Success',0.25);
end

function T = summarizeKeys(K,label,vals)
[g,T] = findgroups(K(:,{'MethodId','TrainSeed','Point'}));
for v = vals, T.(v{1}) = splitapply(@mean,K.(v{1}),g); end
T.Reached = splitapply(@numel,K.PolicyBestReturn,g);
T.Model = repmat(label,height(T),1);
end

function v = pick(deltas,values,delta)
k = find(abs(deltas-delta)<1e-12); assert(isscalar(k)); v = values(k);
end

function S = interval(T,groups,metrics,confidence)
[g,S] = findgroups(T(:,groups));
for m = metrics
    x = T.(m{1});
    S.([m{1},'_mean']) = splitapply(@(v)mean(v,'omitnan'),x,g);
    S.([m{1},'_n']) = splitapply(@(v)sum(isfinite(v)),x,g);
    hw = splitapply(@(v)halfWidth(std(v,'omitnan'),sum(isfinite(v)),1-confidence),x,g);
    S.([m{1},'_low']) = S.([m{1},'_mean'])-hw;
    S.([m{1},'_high']) = S.([m{1},'_mean'])+hw;
end
end

function hw = halfWidth(sd,n,alpha)
hw = NaN;
if n>=2
    q = betaincinv(alpha,(n-1)/2,0.5);
    hw = sqrt((n-1)*(1-q)/q)*sd/sqrt(n);
end
end
