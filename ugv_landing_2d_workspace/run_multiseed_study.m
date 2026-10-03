function [aggregate,allRuns] = run_multiseed_study(options)
% RUN_MULTISEED_STUDY  Repeat the fair A/B/C study over independent PPO seeds.
% This is intentionally separate from run_all because five complete scratch
% runs are expensive. Test seeds remain fixed and are never used for training
% or checkpoint selection.
if nargin<1, options=struct(); end
assert(isstruct(options) && isscalar(options),'landing2d:InvalidOptions', ...
    'options must be a scalar struct.');
root=setup_project();
base=landing2d.config.primaryConfig(root);
defaults=struct('trainingSeeds',base.rl.seed+(0:4)*10000, ...
    'executionMode','full','figureVisible',false,'saveResults',true, ...
    'outputDir',fullfile(base.outputDir,'multiseed'));
keys=fieldnames(defaults);
for i=1:numel(keys)
    if ~isfield(options,keys{i}), options.(keys{i})=defaults.(keys{i}); end
end
unknown=setdiff(fieldnames(options),keys);
assert(isempty(unknown),'landing2d:UnknownOption', ...
    'Unknown run_multiseed_study option: %s',strjoin(unknown,', '));
seeds=double(options.trainingSeeds(:)');
validateattributes(seeds,{'numeric'},{'vector','integer','nonnegative','nonempty'});
assert(numel(unique(seeds))==numel(seeds), ...
    'landing2d:DuplicateTrainingSeed','Training seeds must be unique.');
allRuns=cell(1,numel(seeds));
rows=cell(1,numel(seeds));
for i=1:numel(seeds)
    seedDir=fullfile(char(options.outputDir),sprintf('seed_%d',seeds(i)));
    fprintf('\nMULTI-SEED %d/%d | PPO seed %d\n',i,numel(seeds),seeds(i));
    runOptions=struct('executionMode',char(options.executionMode), ...
        'rlRetrain',true,'rlSeed',seeds(i),'outputDir',seedDir, ...
        'figureVisible',logical(options.figureVisible),'animate',false, ...
        'makeFinalPlots',false,'showLiveDashboard',false, ...
        'saveResults',logical(options.saveResults));
    [comparison,summary,cfg]=run_planar_visibility(runOptions);
    summary.TrainingSeed=repmat(seeds(i),height(summary),1);
    rows{i}=summary;
    allRuns{i}=struct('comparison',comparison,'summary',summary,'cfg',cfg);
end
perSeed=vertcat(rows{:});
methods=unique(string(perSeed.Method),'stable');
aggregate=table('Size',[numel(methods),9], ...
    'VariableTypes',{'string','double','double','double','double','double', ...
    'double','double','double'}, ...
    'VariableNames',{'Method','Repeats','MeanSuccess','StdSuccess', ...
    'MeanUnsafe','StdUnsafe','MeanReturn','StdReturn','MeanInferenceMs'});
for i=1:numel(methods)
    mask=string(perSeed.Method)==methods(i);
    aggregate.Method(i)=methods(i);
    aggregate.Repeats(i)=sum(mask);
    aggregate.MeanSuccess(i)=mean(perSeed.SuccessRate(mask));
    aggregate.StdSuccess(i)=std(perSeed.SuccessRate(mask));
    aggregate.MeanUnsafe(i)=mean(perSeed.UnsafeRate(mask));
    aggregate.StdUnsafe(i)=std(perSeed.UnsafeRate(mask));
    aggregate.MeanReturn(i)=mean(perSeed.MeanReturn(mask));
    aggregate.StdReturn(i)=std(perSeed.MeanReturn(mask));
    aggregate.MeanInferenceMs(i)=mean(perSeed.InferenceMs(mask));
end
disp(aggregate);
if options.saveResults
    if ~exist(options.outputDir,'dir'), mkdir(options.outputDir); end
    writetable(perSeed,fullfile(options.outputDir,'per_seed_summary.csv'));
    writetable(aggregate,fullfile(options.outputDir,'aggregate_summary.csv'));
    save(fullfile(options.outputDir,'multiseed_study.mat'), ...
        'aggregate','perSeed','seeds');
end
end
