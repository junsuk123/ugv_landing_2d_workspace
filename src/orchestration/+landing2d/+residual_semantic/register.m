function registration = register(phase,evidence)
% REGISTER Write the registration of a relational_residual_v8 phase before it runs.
%   landing2d.residual_semantic.register('development',evidence)
%   landing2d.residual_semantic.register('confirmation',evidence)
% Registers the SHA-256 of every MATLAB source under src/ and of the design
% document, the seeds, environments, gate or confirmation rule, budget and
% stop rule, and EVIDENCE (pre-check reports, file hashes, the closed C1/C2
% developments, the passed development gate for the confirmation). Refuses an
% existing registration.
d = landing2d.residual_semantic.config();
assert(ismember(phase,{'development','confirmation'}));
folder = fullfile(d.outputDir,phase);
file = fullfile(folder,'registration.json');
assert(~isfile(file),'landing2d:ResidualV8Registered','Preserve the existing registration %s.',file);
if ~isfolder(folder), mkdir(folder); end
sources = dir(fullfile(d.root,'src','**','*.m'));
paths = [arrayfun(@(f)fullfile(f.folder,f.name),sources,'UniformOutput',false);{d.designDocument}];
code = cellfun(@(p)struct('path',relativePath(d.root,p), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(p))),paths);
if strcmp(phase,'development')
    seeds = d.developmentSeeds; environments = d.developmentEnvironments; rule = d.developmentGate;
else
    seeds = d.confirmationSeeds; environments = d.confirmationEnvironments; rule = d.confirmation;
end
registration = struct('version',d.version,'candidate',d.candidate,'phase',phase, ...
    'registeredAtUtc',string(datetime('now','TimeZone','UTC')), ...
    'approval',['User 2026-10-27: reopen the generalization goal (autonomy up to confirmation); after C1/C2 ' ...
    'failed, "코덱스 한도 복원되기 전까지 너가 판단해서 수정해줘" and "관계를 셔플 하면 잘 안되는게 맞아".'], ...
    'decision',['Claude as judge while Codex is unavailable (usage limit to 2026-11-02): C3 relation-typed ' ...
    'operators (qualifiesEstimate modulation, informsMotion/self additive messages), goal-node readout, ' ...
    'beta 0 in all residual arms, base 77, MLP correction 32; one confirmation.'], ...
    'algorithmVersion',landing2d.rl.algorithmVersion(d.c),'trainSeeds',seeds, ...
    'environmentSeeds',environments,'methods',{d.methods},'parameterCounts',d.parameterCounts, ...
    'evaluationProtocol',d.c.evaluation.protocolVersion,'rule',rule,'confirmationPlan',d.confirmation, ...
    'budget',['After the failed C1 (451-455) and C2 (461-465): at most C3 (471-475) and C4 (481-485, defined ' ...
    'before its training); one confirmation (431-450); no seed exclusion, retraining, relaxed criteria.'], ...
    'sources',code,'evidence',evidence,'confirmationOpened',strcmp(phase,'confirmation'),'trainingStarted',false);
fid = fopen(file,'w','n','UTF-8'); assert(fid>=0);
fwrite(fid,jsonencode(registration,'PrettyPrint',true),'char'); fclose(fid);
fprintf('[v8] registered %s: %d sources, seeds %s\n',phase,numel(code),mat2str(seeds));
end

function p = relativePath(root,file)
p = strrep(erase(string(file),string(root)+filesep),'\','/');
end
