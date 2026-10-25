function checkLearningPath(c)
% CHECKLEARNINGPATH TEST ONLY: shared relations receive the actual PPO gradient.
% No new objective, optimizer hook, data collection or bias metric is added.
if nargin<1, c = landing2d.minimal.config(); end
c = landing2d.config.applyMethod(c,'onto_rgat_ppo',251);
agent = landing2d.rl.initialAgent(c); original = agent;
x = zeros(40,4);
for k = 1:4
    [~,o] = landing2d.environment.reset(c,2000+k);
    x(:,k) = landing2d.minimal.features(o);
end
assert(isequal(agent.encoderSpec.T.rel(1:3),[1 2 2]));
g = landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,x);
mu = landing2d.rl.mlpForward(agent.policy.mean,g);
z = [.3,-.4,.2,-.1;-.2,.1,.4,-.3];
actions = mu+exp(agent.policy.logStd).*z;
oldLog = sum(-0.5*z.^2-agent.policy.logStd-0.5*log(2*pi),1);
advantage = [1,-.4,.8,-.6];
[head,batch] = landing2d.rl.policyLossGradient(agent,x,actions,oldLog,advantage,c.rl);
[headWithStats,withStats,stats] = landing2d.rl.policyLossGradient(agent,x,actions,oldLog,advantage,c.rl); %#ok<ASGLU>
assert(isequal(head,headWithStats) && isequal(batch,withStats));
average = landing2d.util.adamInit(batch); average = average.m;
for k = 1:4
    [~,one] = landing2d.rl.policyLossGradient(agent,x(:,k),actions(:,k),oldLog(k),advantage(k),c.rl);
    for name = fieldnames(batch)'
        key = name{1}; average.(key) = average.(key)+one.(key)/4;
    end
end
for name = fieldnames(batch)'
    key = name{1}; assert(max(abs(batch.(key)-average.(key)),[],'all')<1e-11, ...
        'PPO does not accumulate sample gradients into the same parameters.');
end
% Differentiate the real clipped PPO loss through every relation transform
% and every attention component, rather than an encoder-only surrogate.
step = 1e-6; maximumError = 0;
for name = {'W','a'}
    key = name{1};
    for k = 1:numel(batch.(key))
        plus = agent; minus = agent;
        plus.policy.encoder.(key)(k) = plus.policy.encoder.(key)(k)+step;
        minus.policy.encoder.(key)(k) = minus.policy.encoder.(key)(k)-step;
        [~,~,a] = landing2d.rl.policyLossGradient(plus,x,actions,oldLog,advantage,c.rl);
        [~,~,b] = landing2d.rl.policyLossGradient(minus,x,actions,oldLog,advantage,c.rl);
        maximumError = max(maximumError,abs((a.loss-b.loss)/(2*step)-batch.(key)(k)));
    end
end
assert(maximumError<2e-7,'Full PPO chain derivative error %.3g.',maximumError);
for role = {'policy','value'}
    if strcmp(role{1},'policy')
        gradient = batch;
    else
        [~,gradient] = landing2d.rl.valueLossGradient(agent,x,[.2,-.3,.4,-.1]);
    end
    params = agent.(role{1}).encoder;
    gradient = landing2d.util.clipGradient(gradient,c.rl.maxGradNorm);
    updated = landing2d.util.adamUpdate(params,gradient,landing2d.util.adamInit(params), ...
        c.graphState.encoderLearnRate);
    assert(norm(updated.W(:,:,2)-params.W(:,:,2),'fro')>1e-10 ...
        && norm(updated.a-params.a)>1e-10,'Shared W_motion or attention did not update.');
end
assert(isequaln(agent,original),'Diagnostic modified the agent.');
fprintf('    actual PPO chain: all 192 relation + 19 attention derivatives, max error %.3g\n',maximumError);
end
