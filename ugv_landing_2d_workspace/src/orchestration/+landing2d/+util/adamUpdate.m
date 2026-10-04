function [params,state] = adamUpdate(params,grads,state,learnRate)
% ADAMUPDATE  중첩 구조체/셀 파라미터에 대한 Adam 한 단계. 기울기는 하강 방향.
beta1 = 0.9; beta2 = 0.999; epsilon = 1e-8;
state.t = state.t+1;
correction1 = 1-beta1^state.t;
correction2 = 1-beta2^state.t;
step = learnRate*sqrt(correction2)/correction1;
[params,state.m,state.v] = descend(params,grads,state.m,state.v, ...
    beta1,beta2,epsilon,step);
end

function [p,m,v] = descend(p,g,m,v,beta1,beta2,epsilon,step)
if isnumeric(p)
    m = beta1*m+(1-beta1)*g;
    v = beta2*v+(1-beta2)*(g.^2);
    p = p-step*m./(sqrt(v)+epsilon);
elseif iscell(p)
    for i = 1:numel(p)
        [p{i},m{i},v{i}] = descend(p{i},g{i},m{i},v{i},beta1,beta2,epsilon,step);
    end
else
    keys = fieldnames(p);
    for i = 1:numel(keys)
        [p.(keys{i}),m.(keys{i}),v.(keys{i})] = descend(p.(keys{i}),g.(keys{i}), ...
            m.(keys{i}),v.(keys{i}),beta1,beta2,epsilon,step);
    end
end
end
