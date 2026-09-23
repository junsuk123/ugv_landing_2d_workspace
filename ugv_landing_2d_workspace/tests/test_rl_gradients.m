function test_rl_gradients()
% TEST_RL_GRADIENTS  직접 구현한 역전파를 중앙 차분과 비교.
rs = RandStream('threefry','Seed',7);
net = landing2d.rl.mlpInit([4,6,3],1.0,rs);
X = randn(rs,4,5);
target = randn(rs,3,5);
[y,cache] = landing2d.rl.mlpForward(net,X);
grads = landing2d.rl.mlpBackward(net,cache,2*(y-target));
step = 1e-5;
for l = 1:numel(net.W)
    indices = unique([1,numel(net.W{l})]);
    for i = indices
        numeric = centralDifference(net,X,target,l,'W',i,step);
        assert(abs(numeric-grads.W{l}(i)) <= 1e-5*max(1,abs(numeric)), ...
            sprintf('W gradient mismatch at layer %d',l));
    end
    numeric = centralDifference(net,X,target,l,'b',1,step);
    assert(abs(numeric-grads.b{l}(1)) <= 1e-5*max(1,abs(numeric)), ...
        sprintf('b gradient mismatch at layer %d',l));
end
end

function value = centralDifference(net,X,target,layer,field,index,step)
plus = net; minus = net;
plus.(field){layer}(index) = plus.(field){layer}(index)+step;
minus.(field){layer}(index) = minus.(field){layer}(index)-step;
value = (lossOf(plus,X,target)-lossOf(minus,X,target))/(2*step);
end

function loss = lossOf(net,X,target)
y = landing2d.rl.mlpForward(net,X);
residual = y-target;
loss = sum(residual(:).^2);
end
