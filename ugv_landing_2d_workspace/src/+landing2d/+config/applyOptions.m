function cfg = applyOptions(cfg, options)
% APPLYOPTIONS  알려진 최상위 옵션만 덮어씀. 오타는 조용히 무시하지 않음.
if ~(isstruct(options) && isscalar(options))
    error('landing2d:InvalidOptions','options must be a scalar struct.');
end
names = fieldnames(options);
for i = 1:numel(names)
    key = names{i};
    if ~isfield(cfg,key)
        error('landing2d:UnknownOption','Unknown option: %s',key);
    end
    cfg.(key) = options.(key);
end
% 열벡터로 받은 구간 시각도 내부적으로 동일한 행벡터로 취급.
cfg.segmentTimes = reshape(cfg.segmentTimes,1,[]);
if isstring(cfg.outputDir) && isscalar(cfg.outputDir)
    cfg.outputDir = char(cfg.outputDir);
end
end
