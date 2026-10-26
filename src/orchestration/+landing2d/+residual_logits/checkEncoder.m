function report = checkEncoder()
% CHECKENCODER TEST ONLY: every parameter/input derivative and base/shuffle contracts.
rs = RandStream('threefry','Seed',74191);
x = .6*randn(rs,10,3); dMu = randn(rs,2,3); step = 1e-6;
types = {'graph','mlp'}; reports = cell(1,2);
for t = 1:2
    gs = struct('correctionType',types{t});
    [p,spec] = landing2d.residual_logits.encoderInit(gs, ...
        RandStream('threefry','Seed',74192),RandStream('threefry','Seed',74193));
    [mu,cache] = landing2d.residual_logits.encoderForward(p,spec,x);
    [grad,dx] = landing2d.residual_logits.encoderBackward(p,spec,cache,dMu);
    maximumError = 0; count = 0;
    for field = fieldnames(p)'
        key = field{1}; count = count+numel(p.(key));
        for j = 1:numel(p.(key))
            a = p; b = p; a.(key)(j) = a.(key)(j)+step; b.(key)(j) = b.(key)(j)-step;
            yp = landing2d.residual_logits.encoderForward(a,spec,x);
            ym = landing2d.residual_logits.encoderForward(b,spec,x);
            numerical = sum((yp-ym).*dMu,'all')/(2*step);
            maximumError = max(maximumError,abs(numerical-grad.(key)(j)));
        end
    end
    inputError = 0;
    for j = 1:numel(x)
        a = x; b = x; a(j) = a(j)+step; b(j) = b(j)-step;
        yp = landing2d.residual_logits.encoderForward(p,spec,a);
        ym = landing2d.residual_logits.encoderForward(p,spec,b);
        inputError = max(inputError,abs(sum((yp-ym).*dMu,'all')/(2*step)-dx(j)));
    end
    assert(maximumError<2e-7 && inputError<2e-7);
    expected = [1426 1435]; assert(count==expected(t));
    for j = 1:3
        one = landing2d.residual_logits.encoderForward(p,spec,x(:,j));
        assert(max(abs(one-mu(:,j)))<2e-14);
    end
    base = struct('W',{{p.B1;p.B2}},'b',{{p.b1;p.b2}});
    [baseMu,baseCache] = landing2d.rl.mlpForward(base,x);
    baseGrad = landing2d.rl.mlpBackward(base,baseCache,dMu);
    assert(isequal(grad.B1,baseGrad.W{1}) && isequal(grad.B2,baseGrad.W{2}) ...
        && isequal(grad.b1,baseGrad.b{1}) && isequal(grad.b2,baseGrad.b{2}));
    zero = p; zero.R(:) = 0; zero.br(:) = 0;
    assert(isequal(landing2d.residual_logits.encoderForward(zero,spec,x),baseMu));
    assert(all(abs(mu-baseMu)<=cache.mix+eps,'all'));
    if t==1
        shuffledGs = gs;
        shuffledGs.relationPerturbation = struct('type','edge_relation_shuffle', ...
            'graphSeed',361,'minChangedFraction',2/3);
        [q,shuffledSpec] = landing2d.residual_logits.encoderInit(shuffledGs, ...
            RandStream('threefry','Seed',74192),RandStream('threefry','Seed',74193));
        assert(isequal(p,q) && sum(spec.T.rel~=shuffledSpec.T.rel)==2);
        [shuffledMu,shuffledCache] = landing2d.residual_logits.encoderForward(q,shuffledSpec,x);
        assert(isequal(mu,shuffledMu));
        shuffledGrad = landing2d.residual_logits.encoderBackward(q,shuffledSpec,shuffledCache,dMu);
        assert(norm(grad.W(:)-shuffledGrad.W(:))>1e-8);
        for j = 1:4, assert(norm(grad.P(:,spec.schema.observationIndices{j}),'fro')>1e-9); end
    end
    reports{t} = struct('Correction',string(types{t}),'ActorParameters',count, ...
        'TotalWithCommonCriticAndLogStd',count+661+2,'MaximumParameterError',maximumError, ...
        'MaximumInputError',inputError,'BaseDerivativePreserved',true);
end
report = struct('testOnly',true,'countsAndDerivatives',struct2table([reports{:}]),'passed',true);
disp(report.countsAndDerivatives);
end
