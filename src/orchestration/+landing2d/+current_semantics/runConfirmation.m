function out = runConfirmation(options)
% RUNCONFIRMATION Twenty fresh seeds after the frozen development gate passes.
if nargin<1, options=struct(); end
if isfield(options,'phase'), assert(strcmp(options.phase,'confirmation')); end
options.phase='confirmation';
out=landing2d.current_semantics.runPipeline(options);
end
