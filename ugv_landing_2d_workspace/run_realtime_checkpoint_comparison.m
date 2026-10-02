function [comparison,cfg,fig] = run_realtime_checkpoint_comparison(options)
% RUN_REALTIME_CHECKPOINT_COMPARISON  Compatibility alias for V2 final test.
if nargin<1, options=struct(); end
[comparison,cfg,fig]=run_finalTest(options);
end
