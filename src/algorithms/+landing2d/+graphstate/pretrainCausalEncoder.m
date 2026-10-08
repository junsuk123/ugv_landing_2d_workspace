function [params,info] = pretrainCausalEncoder(params,spec,c,rs)
% PRETRAINCAUSALENCODER Masked same-time node reconstruction on train seeds.
% No action, reward, terminal outcome, future packet, teacher command, or
% hidden simulator state is a feature or target. Random actions only visit
% online-reachable states and are discarded before optimization.
p = c.graphState.pretrain;
trainSeeds = c.experiment.manifest.trainSeeds;
count = min(p.episodes,numel(trainSeeds));
assert(count>0,'landing2d:PretrainSeeds','Pretraining needs train seeds.');
seeds = trainSeeds(1:count);
assert(isempty(intersect(seeds,c.experiment.manifest.validationSeeds)) ...
    && isempty(intersect(seeds,c.experiment.manifest.testSeeds)), ...
    'landing2d:PretrainSplitLeakage','Pretraining seeds overlap evaluation.');
capacity = count*p.maxDecisions;
% Dynamic node channels; the last three (remainingTime or visionAge, bias,
% typeId) are static context and never reconstructed. 9 planar, 11 in 3D.
nDynamic = spec.inDim-3;
actionCount = numel(landing2d.environment.actionLimits(c));
states = zeros(spec.stateDim,capacity); n = 0;
visitRs = RandStream('threefry','Seed',c.rl.seed+p.seedOffset);
for i = 1:count
    [env,~,~] = landing2d.environment.reset(c,seeds(i));
    for k = 1:p.maxDecisions
        if env.episodeStatus.terminated, break; end
        n = n+1;
        states(:,n) = landing2d.graphstate.environmentGraph(env,c);
        action = tanh(0.5*randn(visitRs,actionCount,1));
        [env,~,~,~,~,~] = landing2d.environment.step(env,action);
    end
end
states = states(:,1:n);
decoder.W = 0.1*randn(rs,nDynamic,spec.hiddenDim);
decoder.b = zeros(nDynamic,1);
encoderState = landing2d.util.adamInit(params);
decoderState = landing2d.util.adamInit(decoder);
lossHistory = nan(1,p.epochs);
for epoch = 1:p.epochs
    order = randperm(rs,n);
    epochLoss = 0; batches = 0;
    for first = 1:p.batchSize:n
        idx = order(first:min(first+p.batchSize-1,n));
        B = numel(idx);
        target = reshape(states(:,idx),spec.inDim,spec.nNodes,B);
        mask = rand(rs,nDynamic,spec.nNodes,B)<p.maskProbability;
        for b = 1:B
            if ~any(mask(:,:,b),'all'), mask(1,1,b)=true; end
        end
        input = target;
        dynamic = input(1:nDynamic,:,:);
        dynamic(mask) = 0;
        input(1:nDynamic,:,:) = dynamic;
        [~,cache] = landing2d.graphstate.encoderForward(params,spec, ...
            reshape(input,spec.stateDim,B),'policy');
        H = cache.H;
        Hflat = reshape(H,spec.hiddenDim,spec.nNodes*B);
        prediction = reshape(decoder.W*Hflat+decoder.b,nDynamic,spec.nNodes,B);
        residual = (prediction-target(1:nDynamic,:,:)).*mask;
        denominator = max(nnz(mask),1);
        dPrediction = 2*residual/denominator;
        dFlat = reshape(dPrediction,nDynamic,spec.nNodes*B);
        decoderGrad.W = dFlat*Hflat';
        decoderGrad.b = sum(dFlat,2);
        dH = reshape(decoder.W'*dFlat,spec.hiddenDim,spec.nNodes,B);
        [backboneGrad,~] = landing2d.graphstate.encoderNodeBackward( ...
            params,spec,cache,dH);
        encoderGrad = zeroParameters(params);
        names = fieldnames(backboneGrad);
        for j = 1:numel(names)
            encoderGrad.(names{j}) = backboneGrad.(names{j});
        end
        encoderGrad = landing2d.util.clipGradient(encoderGrad,c.rl.maxGradNorm);
        decoderGrad = landing2d.util.clipGradient(decoderGrad,c.rl.maxGradNorm);
        [params,encoderState] = landing2d.util.adamUpdate(params,encoderGrad, ...
            encoderState,p.learnRate);
        [decoder,decoderState] = landing2d.util.adamUpdate(decoder,decoderGrad, ...
            decoderState,p.learnRate);
        epochLoss = epochLoss+sum(residual(:).^2)/denominator;
        batches = batches+1;
    end
    lossHistory(epoch) = epochLoss/max(batches,1);
end
info = struct('enabled',true,'sampleCount',n,'finalLoss',lossHistory(end), ...
    'lossHistory',lossHistory,'usesActions',false,'usesRewards',false, ...
    'usesOutcomes',false,'usesFuture',false,'seedSplit','train', ...
    'seedCount',count,'objective','masked_same_time_node_reconstruction');
end

function z = zeroParameters(p)
z = p;
names = fieldnames(z);
for i = 1:numel(names), z.(names{i})(:) = 0; end
end
