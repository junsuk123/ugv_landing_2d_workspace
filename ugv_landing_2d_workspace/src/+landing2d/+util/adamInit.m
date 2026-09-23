function state = adamInit(params)
% ADAMINIT  params와 같은 구조의 1차/2차 모멘트를 0으로 준비.
state = struct('t',0,'m',zeroLike(params),'v',zeroLike(params));
end

function z = zeroLike(p)
if isnumeric(p)
    z = zeros(size(p));
elseif iscell(p)
    z = cell(size(p));
    for i = 1:numel(p)
        z{i} = zeroLike(p{i});
    end
elseif isstruct(p)
    z = struct();
    keys = fieldnames(p);
    for i = 1:numel(keys)
        z.(keys{i}) = zeroLike(p.(keys{i}));
    end
else
    error('landing2d:AdamParameter','Unsupported parameter type: %s',class(p));
end
end
