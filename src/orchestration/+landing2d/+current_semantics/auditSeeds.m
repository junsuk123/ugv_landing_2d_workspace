function report = auditSeeds(d,phase)
% AUDITSEEDS Audit accessible local records, not unseen external executions.
landing2d.current_semantics.checkSeeds(d);
if strcmp(phase,'development')
    trainSeeds=d.developmentSeeds; environmentSeeds=d.developmentEnvironments;
else
    assert(strcmp(phase,'confirmation'));
    trainSeeds=d.confirmationSeeds; environmentSeeds=d.confirmationEnvironments;
end
old=landing2d.config.methodRegistry();
known=[];
for name=fieldnames(old.trainSeeds)'
    known=[known,reshape(old.trainSeeds.(name{1}),1,[])]; %#ok<AGROW>
end
assert(isempty(intersect(trainSeeds,known)),'landing2d:CurrentSemanticsSeedReuse','A seed is reserved by the archived registry.');
folder=fullfile(d.root,'results');
csv=dir(fullfile(folder,'**','*.csv'));
json=dir(fullfile(folder,'**','*registration*.json'));
models=dir(fullfile(folder,'**','*.mat'));
checkedCsv=0; checkedJson=0; checkedCheckpoints=0;
for k=1:numel(csv)
    file=fullfile(csv(k).folder,csv(k).name);
    opts=detectImportOptions(file);
    columns=intersect({'TrainSeed','EpisodeSeed'},opts.VariableNames,'stable');
    if isempty(columns), continue; end
    opts.SelectedVariableNames=columns;
    T=readtable(file,opts); checkedCsv=checkedCsv+1;
    if ismember('TrainSeed',columns)
        rejectOverlap(numbers(T.TrainSeed),trainSeeds,file,'training');
    end
    if ismember('EpisodeSeed',columns)
        rejectOverlap(numbers(T.EpisodeSeed),environmentSeeds,file,'environment');
    end
end
for k=1:numel(json)
    file=fullfile(json(k).folder,json(k).name);
    record=jsondecode(fileread(file)); checkedJson=checkedJson+1;
    % These fields identify reservations, not merely observed outcomes.
    for key={'trainSeeds','developmentSeeds','confirmationSeeds'}
        if isfield(record,key{1}), rejectOverlap(numbers(record.(key{1})),trainSeeds,file,'training'); end
    end
    for key={'environmentSeeds','episodeSeeds','developmentEnvironments','confirmationEnvironments'}
        if isfield(record,key{1}), rejectOverlap(numbers(record.(key{1})),environmentSeeds,file,'environment'); end
    end
end
for k=1:numel(models)
    token=regexp(models(k).name,'_s(\d+)(?:_|\.)','tokens','once');
    if isempty(token), continue; end
    checkedCheckpoints=checkedCheckpoints+1;
    rejectOverlap(str2double(token{1}),trainSeeds,fullfile(models(k).folder,models(k).name),'training');
end
report=struct('passed',true,'scope','Accessible local registry, result CSVs, registration JSONs, and checkpoint filenames only.', ...
    'externalHistoryVerified',false,'localResultsPresent',isfolder(folder), ...
    'csvChecked',checkedCsv,'registrationsChecked',checkedJson,'checkpointsChecked',checkedCheckpoints, ...
    'trainSeeds',trainSeeds,'environmentSeeds',environmentSeeds);
end

function x = numbers(x)
if ~isnumeric(x), x=str2double(string(x)); end
x=double(x(:)); x=x(isfinite(x));
end

function rejectOverlap(recorded,reserved,file,kind)
overlap=intersect(recorded,reserved);
assert(isempty(overlap),'landing2d:CurrentSemanticsSeedReuse', ...
    '%s seeds %s already appear in %s.',kind,mat2str(overlap'),file);
end
