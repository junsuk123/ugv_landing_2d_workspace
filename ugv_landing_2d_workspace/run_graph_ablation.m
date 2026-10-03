function [comparison,summaryTable,cfg] = run_graph_ablation(options)
% RUN_GRAPH_ABLATION Sequential representation ablation on the same task.
% Order isolates added semantic information, pooling, graph connectivity,
% and typed relations. Use executionMode='smoke' before the full run.
if nargin<1, options=struct(); end
options.modes={'context_flat','context_node_pool','context_gat','context_rgat'};
[comparison,summaryTable,cfg]=run_planar_visibility(options);
end
