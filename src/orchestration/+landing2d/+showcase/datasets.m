function sets = datasets(root)
% DATASETS Completed four-method evaluations that the showcase ranks (and replays).
% id        short name used by run_live('showcase',struct('dataset',id,...))
% episodes  generalizationEpisodes.csv of the evaluation (stored study numbers)
% config    function of root giving the configuration whose checkpoints and
%           evaluation protocol produced those episodes (empty: ranked only)
if nargin<1, root = landing2d.orchestration.projectRoot(); end
r = @(varargin) fullfile(root,'results',varargin{:});
sets = struct('id',{},'label',{},'episodes',{},'config',{});
sets(end+1) = entry('v5_p2','v5 relational residual, protocol v2 (seeds 421-425)', ...
    r('relational_residual_v5','generalization_v2','development','s421-422-423-424-425'),@(root)landing2d.bias_diagnostics.config(root).c);
sets(end+1) = entry('v5_p1','v5 relational residual, protocol v1 (seeds 421-425)', ...
    r('relational_residual_v5','generalization_v1','development','s421-422-423-424-425'),@(root)landing2d.residual_context.config(root));
sets(end+1) = entry('c1_p2','C1 v6 soft-linear correction, protocol v2 (seeds 451-455)', ...
    r('relational_residual_v6','development'),@(root)landing2d.residual_soft.config(root).c);
sets(end+1) = entry('c2_p2','C2 v7 capacity reallocation, protocol v2 (seeds 461-465)', ...
    r('relational_residual_v7','development'),@(root)landing2d.residual_capacity.config(root).c);
sets(end+1) = entry('v4_p1','v4 relational residual, protocol v1 (seeds 381-385)', ...
    r('relational_residual_v4','generalization_v1','paired-development','s381-382-383-384-385'),@(root)landing2d.residual_base_init.config(root));
sets(end+1) = entry('v3_p1','v3 relational residual, protocol v1 (seeds 381-385)', ...
    r('relational_residual_v3','generalization_v1','development','s381-382-383-384-385'),[]);
sets(end+1) = entry('v2_p1','v2 relational residual, protocol v1 (seeds 361-365)', ...
    r('relational_residual_v2','generalization_v1','development','s361-362-363-364-365'),[]);
sets(end+1) = entry('v1_p1','v1 relational residual, protocol v1 (seeds 341-345)', ...
    r('relational_residual_v1','generalization_v1','development','s341-342-343-344-345'),[]);
sets(end+1) = entry('r1','R1 wider training acceleration (seeds 421-425)', ...
    r('acceleration_range_r1_v1'),[]);
sets = sets(arrayfun(@(s)isfile(s.episodes),sets));
end

function s = entry(id,label,folder,config)
s = struct('id',id,'label',label,'episodes',fullfile(folder,'generalizationEpisodes.csv'),'config',{config});
end
