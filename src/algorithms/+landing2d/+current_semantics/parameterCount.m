function n = parameterCount(agent)
% PARAMETERCOUNT Count only trainable actor, critic and Gaussian logStd.
% Configuration, schema and fixed graph arrays are deliberately excluded.
n = count(agent.policy)+count(agent.value);
end

function n = count(x)
if isnumeric(x)
    n = numel(x);
elseif iscell(x)
    n = 0;
    for j = 1:numel(x), n = n+count(x{j}); end
elseif isstruct(x)
    n = 0;
    for j = 1:numel(x)
        for name = fieldnames(x)', n = n+count(x(j).(name{1})); end
    end
else
    error('landing2d:CurrentSemanticsParameter','A trainable parameter container has nonnumeric data.');
end
end
