function grads = clipGradient(grads,maxNorm)
% CLIPGRADIENT  중첩 구조체/셀 기울기의 전체 L2 노름을 maxNorm 이하로 제한.
total = sqrt(squaredNorm(grads));
if ~isfinite(total) || total <= maxNorm || total == 0
    return;
end
grads = scale(grads,maxNorm/total);
end

function value = squaredNorm(g)
value = 0;
if isnumeric(g)
    value = sum(g(:).^2);
elseif iscell(g)
    for i = 1:numel(g)
        value = value+squaredNorm(g{i});
    end
else
    keys = fieldnames(g);
    for i = 1:numel(keys)
        value = value+squaredNorm(g.(keys{i}));
    end
end
end

function g = scale(g,factor)
if isnumeric(g)
    g = factor*g;
elseif iscell(g)
    for i = 1:numel(g)
        g{i} = scale(g{i},factor);
    end
else
    keys = fieldnames(g);
    for i = 1:numel(keys)
        g.(keys{i}) = scale(g.(keys{i}),factor);
    end
end
end
