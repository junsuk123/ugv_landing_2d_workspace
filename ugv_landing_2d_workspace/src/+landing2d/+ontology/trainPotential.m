function [P,history] = trainPotential(D,onto,rs)
% TRAINPOTENTIAL  안전 착륙 결과를 정답으로 R-GAT 잠재함수를 지도학습.
% 원 저장소 training.trainRGAT과 같은 손실/분할 구성이며, Toolbox 없이
% 직접 구현한 역전파(landing2d.rgat.potentialBackward)를 사용합니다.
schema = D.schema;
T = landing2d.rgat.topology(schema);
P = landing2d.rgat.potentialInit(schema,onto,rs);
state = landing2d.util.adamInit(P);
n = D.sampleCount;
order = randperm(rs,n);
nTrain = max(1,round((1-onto.validationSplit)*n));
trainIndex = order(1:nTrain);
validationIndex = order(nTrain+1:end);
if isempty(validationIndex)
    validationIndex = trainIndex;
end
history.trainLoss = zeros(onto.epochs,1);
history.validationLoss = zeros(onto.epochs,1);
for epoch = 1:onto.epochs
    shuffled = trainIndex(randperm(rs,numel(trainIndex)));
    total = 0;
    batches = 0;
    for start = 1:onto.batchSize:numel(shuffled)
        index = shuffled(start:min(start+onto.batchSize-1,numel(shuffled)));
        [loss,grads] = landing2d.rgat.potentialLoss(P,D.X(:,:,index),D.y(index),T,onto);
        grads = landing2d.util.clipGradient(grads,onto.maxGradNorm);
        [P,state] = landing2d.util.adamUpdate(P,grads,state,onto.learnRate);
        total = total+loss;
        batches = batches+1;
    end
    history.trainLoss(epoch) = total/max(batches,1);
    prediction = landing2d.rgat.predict(P,D.X(:,:,validationIndex),T);
    history.validationLoss(epoch) = mean((prediction-D.y(validationIndex)).^2);
    landing2d.viz.liveDashboard('ontology',struct('epoch',epoch, ...
        'maxEpoch',onto.epochs,'trainLoss',history.trainLoss(epoch), ...
        'validationLoss',history.validationLoss(epoch)));
    if onto.verbose && (mod(epoch,5) == 0 || epoch == 1 || epoch == onto.epochs)
        fprintf('  R-GAT epoch %2d/%2d | train %.4f | val %.4f\n', ...
            epoch,onto.epochs,history.trainLoss(epoch),history.validationLoss(epoch));
    end
end
history.finalValidationLoss = history.validationLoss(end);
history.validationSamples = numel(validationIndex);
end
