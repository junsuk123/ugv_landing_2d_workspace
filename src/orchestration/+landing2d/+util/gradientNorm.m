function value = gradientNorm(grads)
% GRADIENTNORM  Total L2 norm of a nested struct/cell gradient (0 for an empty struct).
% Diagnostic only; landing2d.util.clipGradient applies the clipping.
value = sqrt(squaredNorm(grads));
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
