function D = weightSweepDataset(c,rs)
% WEIGHTSWEEPDATASET  보상 가중치를 바꿔가며 학습/실행한 결과를 모읍니다.
%
% 상태만 있는 그래프로는 "이 가중치가 착륙에 도움이 되는가"를 계산할 수 없습니다.
% 가중치가 그래프 안에 없기 때문입니다. 그래서 가중치를 노드로 넣고,
% 여러 배분에 대해 실제로 정책을 학습시켜 그 결과(착륙 성공 여부)를 정답으로 씁니다.
% R-GAT은 여기서 "어떤 배분이 안전 착륙으로 이어지는가"를 직접 배웁니다.
onto = c.ontology;
schema = landing2d.ontology.nodeSchema('design');
nCases = size(c.scenarioSpeeds,1);
interval = c.rl.actionInterval;
dtAction = c.dt*interval;
recordEvery = interval*onto.sampleStride;
shares = linspace(onto.sweepShareRange(1),onto.sweepShareRange(2),onto.sweepPoints);
nShares = numel(shares);
shareGraphs = cell(1,nShares);
shareLabels = cell(1,nShares);
shareValue = cell(1,nShares);
shareMeta = cell(1,nShares);
landingRate = zeros(1,nShares);
% 배분마다 독립된 학습이므로 배분 단위로 나눕니다. 학습 난수는 rl.seed로 정해지고
% 그래프 수집은 공칭 초기 조건만 쓰므로, 병렬 실행이 결과를 바꾸지 않습니다.
% 안쪽 에피소드 병렬화는 끕니다(중첩 parfor 불가).
parWorkers = 0;
if c.rl.parallelEpisodes
    poolConfig = c.rl;
    poolConfig.parallelWorkers = max(1,min(feature('numcores'),nShares));
    poolConfig.episodesPerIteration = nShares;
    poolConfig = landing2d.rl.ensurePool(poolConfig);
    if poolConfig.parallelEpisodes
        parWorkers = poolConfig.parallelWorkers;
    end
end
parfor (k = 1:nShares, parWorkers)
    trial = c;
    trial.rl.captureWeight = onto.anchorWeight*shares(k)/(1-shares(k));
    trial.rl.distanceWeight = onto.anchorWeight;
    if onto.sweepFromScratch
        % 라벨이 제안 모델의 학습 조건을 그대로 반영해야 합니다.
        trial.rl = landing2d.rl.applyScratchSettings(trial.rl);
    end
    trial.rl.ppoIterations = onto.sweepIterations;
    trial.rl.evaluateEvery = max(1,round(onto.sweepIterations/2));
    trial.rl.verbose = false;
    trial.rl.parallelEpisodes = false;
    agent = landing2d.rl.trainAgent(trial);
    landed = false(1,nCases);
    caseGraphs = cell(1,nCases);
    caseLabels = cell(1,nCases);
    caseValue = cell(1,nCases);
    caseMeta = cell(1,nCases);
    for j = 1:nCases
        [r,s] = landing2d.rl.makeEpisode(trial,j,trial.rl,[]);
        memory = landing2d.rl.initialMemory(r.vxUgv(1));
        n = numel(r.time);
        X = zeros(schema.inDim,schema.nNodes,ceil(n/recordEvery));
        values = zeros(1,size(X,3));
        count = 0;
        ax = 0; az = 0;
        for step = 1:n
            xp = r.xUgv(step); vp = r.vxUgv(step);
            [s,contact] = landing2d.environment.resolveContact(s,xp,vp,c);
            if contact.landed, landed(j) = true; end
            obs = landing2d.sensing.observePad(s,xp,vp,c);
            s = landing2d.control.trackingMode(s,obs,c);
            if mod(step-1,interval) == 0
                [o,memory] = landing2d.rl.observation(s,obs,memory,c,dtAction);
                u = landing2d.rl.policyAction(agent,o,[],true);
                [ax,az] = landing2d.rl.actionFromCommand(u,c);
                if s.mode >= 3, ax = 0; az = 0; end
                if mod(step-1,recordEvery) == 0
                    truth = struct('error',xp-s.x,'rate',vp-s.vx,'speed',vp);
                    sem = landing2d.ontology.semanticState(s,obs,memory,truth,c);
                    extra = struct('CaptureWeight',shares(k), ...
                        'DistanceWeight',1-shares(k),'PolicyValue',0);
                    count = count+1;
                    nodes = landing2d.ontology.nodeValues(sem,schema,extra);
                    X(:,:,count) = landing2d.ontology.buildGraph(nodes,schema);
                    values(count) = landing2d.rgat.predictValue(agent,o);
                end
            end
            if step < n
                s = landing2d.dynamics.stepDrone(s,ax,az,xp, ...
                    r.xUgv(step+1),r.vxUgv(step+1),c);
            end
        end
        outcome = 2*double(landed(j))-1;
        index = (1:count)';
        caseGraphs{j} = X(:,:,1:count);
        caseLabels{j} = outcome*onto.labelGamma.^(count-index);
        caseValue{j} = values(1:count)';
        caseMeta{j} = repmat([k,shares(k),j,double(landed(j))],count,1);
    end
    shareGraphs{k} = cat(3,caseGraphs{:});
    shareLabels{k} = vertcat(caseLabels{:});
    shareValue{k} = vertcat(caseValue{:});
    shareMeta{k} = vertcat(caseMeta{:});
    landingRate(k) = mean(landed);
    if onto.verbose
        fprintf('  배분 %4.2f | capture %.3f / distance %.3f | 착륙 %3.0f%%\n', ...
            shares(k),trial.rl.captureWeight,trial.rl.distanceWeight,100*landingRate(k));
    end
end
D.X = cat(3,shareGraphs{:});
D.y = vertcat(shareLabels{:})';
D.meta = vertcat(shareMeta{:});
D.schema = schema;
D.shares = shares;
D.landingRate = landingRate;
D.sampleCount = size(D.X,3);
D.successRate = mean(landingRate);
% 강화학습 가치 노드는 자료 전체 기준으로 [0,1]로 정규화합니다.
raw = vertcat(shareValue{:});
low = prctile(raw,5); high = prctile(raw,95);
normalized = min(max((raw-low)/max(high-low,eps),0),1);
D.X(1,schema.valueNode,:) = reshape(normalized,1,1,[]);
D.X(2,schema.valueNode,:) = 1-reshape(normalized,1,1,[]);
if onto.verbose
    fprintf('가중치 탐색 자료: 표본 %d개, 배분 %d개, 평균 착륙률 %.0f%%\n', ...
        D.sampleCount,numel(shares),100*D.successRate);
end
end
