function report = checkEncoder()
% CHECKENCODER Structural/derivative checks; TEST ONLY, not performance.
rs = RandStream('threefry','Seed',74119);
policyInput = .7*randn(rs,10,3); dZ = randn(rs,16,3);
maxParameterError = zeros(2,1); maxInputError = zeros(2,1); counts = zeros(2,1);
types = {'graph','mlp'};
for t = 1:2
    gs = struct('correctionType',types{t});
    [params,spec] = landing2d.residual.encoderInit(gs,10,RandStream('threefry','Seed',74120));
    [z,cache] = landing2d.residual.encoderForward(params,spec,policyInput);
    [grad,dx] = landing2d.residual.encoderBackward(params,spec,cache,dZ);
    for b = 1:3
        columnZ = landing2d.residual.encoderForward(params,spec,policyInput(:,b));
        assert(max(abs(columnZ-z(:,b)))<2e-14,'Batch/single forward mismatch.');
    end
    step = 1e-6;
    for name = fieldnames(params)'
        key = name{1}; counts(t) = counts(t)+numel(params.(key));
        for j = 1:numel(params.(key))
            plusParams = params; minusParams = params;
            plusParams.(key)(j) = plusParams.(key)(j)+step;
            minusParams.(key)(j) = minusParams.(key)(j)-step;
            zp = landing2d.residual.encoderForward(plusParams,spec,policyInput);
            zm = landing2d.residual.encoderForward(minusParams,spec,policyInput);
            numerical = sum((zp-zm).*dZ,'all')/(2*step);
            maxParameterError(t) = max(maxParameterError(t),abs(numerical-grad.(key)(j)));
        end
    end
    for j = 1:numel(policyInput)
        plusInput = policyInput; minusInput = policyInput;
        plusInput(j) = plusInput(j)+step; minusInput(j) = minusInput(j)-step;
        zp = landing2d.residual.encoderForward(params,spec,plusInput);
        zm = landing2d.residual.encoderForward(params,spec,minusInput);
        numerical = sum((zp-zm).*dZ,'all')/(2*step);
        maxInputError(t) = max(maxInputError(t),abs(numerical-dx(j)));
    end
    assert(maxParameterError(t)<2e-7 && maxInputError(t)<2e-7,'Residual derivative failed.');
end
assert(isequal(counts,[1132;1143]));
gs = struct('correctionType','graph');
[params,spec] = landing2d.residual.encoderInit(gs,10,RandStream('threefry','Seed',74120));
for seed = 341:345
    gs.relationPerturbation = struct('type','edge_relation_shuffle', ...
        'graphSeed',seed,'minChangedFraction',2/3);
    [shuffled,ss] = landing2d.residual.encoderInit(gs,10,RandStream('threefry','Seed',74120));
    assert(isequal(params,shuffled));
    assert(isequal(spec.T.src,ss.T.src) && isequal(spec.T.dst,ss.T.dst));
    assert(sum(spec.T.rel~=ss.T.rel)==2 && isequal(sort(spec.T.rel),sort(ss.T.rel)));
    % Repeated informsMotion edges share a matrix in TOSM; shuffle changes
    % the pair sharing a matrix. This is not a global relabeling.
    assert(~isequal(spec.T.rel(1:3)'==spec.T.rel(1:3),ss.T.rel(1:3)'==ss.T.rel(1:3)));
    [z,cache] = landing2d.residual.encoderForward(params,spec,policyInput);
    [zs,cs] = landing2d.residual.encoderForward(shuffled,ss,policyInput);
    assert(isequal(z,zs),'Initial graph functions should match.');
    grad = landing2d.residual.encoderBackward(params,spec,cache,dZ);
    sg = landing2d.residual.encoderBackward(shuffled,ss,cs,dZ);
    assert(norm(grad.W(:)-sg.W(:))>1e-6,'Shuffle must change shared gradients.');
    for i = 1:4
        assert(norm(grad.P(:,spec.schema.observationIndices{i}),'fro')>1e-8, ...
            'Every declared node must have a learning path.');
    end
    changed = params; changed.W(:,:,1) = changed.W(:,:,1)+.1;
    changedZ = landing2d.residual.encoderForward(changed,spec,policyInput);
    changedS = landing2d.residual.encoderForward(changed,ss,policyInput);
    assert(norm(changedZ-changedS,'fro')>1e-7,'Relations must affect learned functions.');
end
% A zero correction leaves a functional raw-observation path.
params.R(:) = 0; params.br(:) = 0;
z = landing2d.residual.encoderForward(params,spec,policyInput);
assert(norm(z(:,1)-z(:,2))>1e-3);
report = table(string(types(:)),counts,maxParameterError,maxInputError, ...
    'VariableNames',{'Correction','Parameters','MaxParameterError','MaxInputError'});
disp(report);
fprintf('Residual encoder checks PASS (TEST ONLY).\n');
end
