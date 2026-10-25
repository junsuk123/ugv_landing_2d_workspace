function options = options(options,defaults)
% OPTIONS Reject misspellings rather than silently ignoring study settings.
assert(isstruct(options) && isscalar(options),'landing2d:InvalidOptions', ...
    'Options must be a scalar struct.');
unknown = setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption','Unknown option: %s',strjoin(unknown,', '));
for name = fieldnames(defaults)'
    if ~isfield(options,name{1}), options.(name{1}) = defaults.(name{1}); end
end
end
