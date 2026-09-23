function D = buildDataset(c,rs)
% BUILDDATASET  잡음을 섞은 PD 전문가 시연에서 온톨로지 그래프와 정답을 수집.
% 원 저장소 training.generateRGATDataset과 같은 구성입니다.
%
% 정답은 그 에피소드의 안전 착륙 여부를 표본 시점까지 할인한 값입니다.
%   y_k = (2*success-1) * labelGamma^(K-k)
% 잡음 세기는 로그 균등 분포로 뽑아, 성공과 실패가 모두 들어간 자료를 만듭니다.
onto = c.ontology;
schema = landing2d.ontology.nodeSchema();
nCases = size(c.scenarioSpeeds,1);
interval = c.rl.actionInterval;
dtAction = c.dt*interval;
recordEvery = interval*onto.sampleStride;
graphs = cell(onto.dataEpisodes,1);
labels = cell(onto.dataEpisodes,1);
meta = cell(onto.dataEpisodes,1);
success = false(onto.dataEpisodes,1);
severity = zeros(onto.dataEpisodes,1);
for e = 1:onto.dataEpisodes
    low = log(onto.noiseRange(1));
    high = log(onto.noiseRange(2));
    severity(e) = exp(low+(high-low)*rand(rs));
    index = mod(e-1,nCases)+1;
    [r,s] = landing2d.rl.makeEpisode(c,index,c.rl,rs,onto.heightRange);
    n = numel(r.time);
    capacity = ceil(n/recordEvery);
    X = zeros(schema.inDim,schema.nNodes,capacity);
    memory = landing2d.rl.initialMemory(r.vxUgv(1));
    count = 0;
    landed = false;
    axExecuted = 0;
    azExecuted = 0;
    for k = 1:n
        xp = r.xUgv(k);
        vp = r.vxUgv(k);
        [s,contact] = landing2d.environment.resolveContact(s,xp,vp,c);
        if contact.landed
            landed = true;
        end
        obs = landing2d.sensing.observePad(s,xp,vp,c);
        [s,ax,az] = landing2d.control.command(s,obs,c);
        if mod(k-1,interval) == 0
            [~,memory] = landing2d.rl.observation(s,obs,memory,c,dtAction);
            axExecuted = landing2d.util.saturate( ...
                ax+severity(e)*c.axMax*randn(rs),c.axMax);
            azExecuted = landing2d.util.saturate( ...
                az+severity(e)*c.azMax*randn(rs),c.azMax);
        end
        if mod(k-1,recordEvery) == 0
            truth = struct('error',xp-s.x,'rate',vp-s.vx,'speed',vp);
            sem = landing2d.ontology.semanticState(s,obs,memory,truth,c);
            values = landing2d.ontology.nodeValues(sem,schema);
            count = count+1;
            X(:,:,count) = landing2d.ontology.buildGraph(values,schema);
        end
        if k < n
            s = landing2d.dynamics.stepDrone(s,axExecuted,azExecuted,xp, ...
                r.xUgv(k+1),r.vxUgv(k+1),c);
        end
    end
    success(e) = landed;
    outcome = 2*double(landed)-1;
    sampleIndex = (1:count)';
    graphs{e} = X(:,:,1:count);
    labels{e} = outcome*onto.labelGamma.^(count-sampleIndex);
    meta{e} = [repmat(e,count,1),sampleIndex,repmat(double(landed),count,1), ...
        repmat(severity(e),count,1)];
    if onto.verbose
        fprintf('  ep %2d/%2d | scenario %d | landed %d | noise %.2f | samples %d\n', ...
            e,onto.dataEpisodes,index,landed,severity(e),count);
    end
end
D.X = cat(3,graphs{:});
D.y = vertcat(labels{:})';
D.meta = vertcat(meta{:});
D.schema = schema;
D.sampleCount = size(D.X,3);
D.successRate = mean(success);
if onto.verbose
    fprintf('데이터셋: 표본 %d개, 성공 에피소드 %d/%d, 양의 정답 %.1f%%\n', ...
        D.sampleCount,sum(success),onto.dataEpisodes,100*mean(D.y > 0));
end
end
