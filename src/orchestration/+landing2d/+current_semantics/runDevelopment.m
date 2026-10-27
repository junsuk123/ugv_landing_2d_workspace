function out = runDevelopment(options)
% RUNDEVELOPMENT Five fixed seeds, four methods; never starts confirmation.
if nargin<1, options=struct(); end
if isfield(options,'phase'), assert(strcmp(options.phase,'development')); end
options.phase='development';
out=landing2d.current_semantics.runPipeline(options);
end
