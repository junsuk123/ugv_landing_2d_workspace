function [agent,info,file,c,note] = loadLatestCheckpoint(c)
% LOADLATESTCHECKPOINT  Most recent validated policy of one run, never training.
%   [agent,info,file,c,note] = landing2d.rl.loadLatestCheckpoint(c)
% Used for a method that run.m marks as not trained (landing2d.orchestration.trainRuns,
% option trainMethods). A checkpoint holds the policy that PPO selected on the
% validation split, so the newest usable checkpoint is the most recent
% validated model. Candidates are c.outputDir/<rl.policyFile> and the same file
% in every c.outputDir/archive/*/ folder. A candidate is usable when
%   - its training signature matches C (landing2d.rl.signatureMatches; plain PPO
%     ignores R-GAT-only changes, landing2d.rl.baselineVersion), or
%   - it is a graph-arm checkpoint of a version listed in sameEncoderVersions
%     whose rl, experiment and action constants equal C: it is returned with
%     the graph settings it was trained with (its saved graphState), so its
%     policy input is built as during training. NOTE says so.
% A checkpoint trained on another task contract (rl, experiment, actions) is
% never used. The newest usable candidate by file date wins; none is an error.
% Versions whose R-GAT computation is the current code with only the graph
% features (graphState.observationFeatures) differing:
sameEncoderVersions = {'relational-policy-v2.12','relational-policy-v2.13', ...
    'relational-policy-v2.14'};
candidates = {fullfile(c.outputDir,c.rl.policyFile)};
archives = dir(fullfile(c.outputDir,'archive'));
for k = 1:numel(archives)
    if archives(k).isdir && ~startsWith(archives(k).name,'.')
        candidates{end+1} = fullfile(c.outputDir,'archive',archives(k).name,c.rl.policyFile); %#ok<AGROW>
    end
end
best = ''; bestTime = -Inf; bestGraphState = []; note = '';
for k = 1:numel(candidates)
    if ~isfile(candidates{k}), continue; end
    saved = load(candidates{k},'signature');
    if ~isfield(saved,'signature'), continue; end
    [usable,graphState,why] = usableSignature(saved.signature,c,sameEncoderVersions);
    listing = dir(candidates{k}); stamp = listing.datenum;
    if usable && stamp > bestTime
        best = candidates{k}; bestTime = stamp; bestGraphState = graphState; note = why;
    end
end
if isempty(best)
    error('landing2d:NoValidatedCheckpoint', ['No usable validated checkpoint for %s ' ...
        '(searched %s and %s). Set it to be trained in run.m or train it first.'], ...
        c.rl.policyFile,candidates{1},fullfile(c.outputDir,'archive','*'));
end
saved = load(best);
assert(isfield(saved,'agent'),'landing2d:InvalidCheckpoint', ...
    'Checkpoint must contain agent and signature: %s',best);
c.graphState = bestGraphState;
agent = saved.agent;
landing2d.rl.verifyCheckpointGraph(agent,c);
info = struct(); if isfield(saved,'info'), info = saved.info; end
file = best;
end

function [usable,graphState,why] = usableSignature(saved,c,sameEncoderVersions)
graphState = c.graphState; why = '';
usable = landing2d.rl.signatureMatches(saved,c);
if usable || strcmp(c.graphState.stateRepresentation,'baseline'), return; end
current = landing2d.rl.trainingSignature(c);
if ~isfield(saved,'algorithmVersion') || ~ismember(saved.algorithmVersion,sameEncoderVersions) ...
        || ~isfield(saved,'graphState') ...
        || ~strcmp(saved.graphState.stateRepresentation,c.graphState.stateRepresentation)
    return;
end
usable = isequal(taskContract(saved),taskContract(current));
if usable
    graphState = saved.graphState;
    graphState.policyFile = c.graphState.policyFile;
    why = sprintf('%s checkpoint, graph features %s (current code %s)', ...
        saved.algorithmVersion,graphState.observationFeatures,current.algorithmVersion);
end
end

function s = taskContract(s)
% Everything but the R-GAT version and its graph settings; execution-only rl
% fields are ignored as in landing2d.rl.signatureMatches.
s = rmfield(s,intersect(fieldnames(s),{'algorithmVersion','graphState'}));
s.rl = rmfield(s.rl,intersect(fieldnames(s.rl),{'parallelWorkers','parallelEpisodes'}));
end
