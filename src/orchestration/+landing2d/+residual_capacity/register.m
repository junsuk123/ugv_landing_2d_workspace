function registration = register(phase,evidence)
% REGISTER Write the registration of a relational_residual_v7 phase before it runs.
%   landing2d.residual_capacity.register('development',evidence)
%   landing2d.residual_capacity.register('confirmation',evidence)
% Registers the SHA-256 of every MATLAB source under src/ and of the design
% document, the seeds, environments, gate or confirmation rule, budget and
% stop rule, and EVIDENCE (pre-check reports, file hashes, the closed C1
% development, the passed development gate for the confirmation). Refuses an
% existing registration.
d = landing2d.residual_capacity.config();
assert(ismember(phase,{'development','confirmation'}));
folder = fullfile(d.outputDir,phase);
file = fullfile(folder,'registration.json');
assert(~isfile(file),'landing2d:ResidualV7Registered','Preserve the existing registration %s.',file);
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
    'approval','User 2026-10-27: reopen the generalization goal; autonomy up to confirmation.', ...
    'decision',['Codex GO 2026-10-27 (decisionP): C1 failed development; C2 as registered - v5 with tanh, ' ...
    'residual base width 74->42, node width 8->12, Residual-MLP correction width 36->68; one confirmation.'], ...
    'algorithmVersion',landing2d.rl.algorithmVersion(d.c),'trainSeeds',seeds, ...
    'environmentSeeds',environments,'methods',{d.methods},'parameterCounts',d.parameterCounts, ...
    'evaluationProtocol',d.c.evaluation.protocolVersion,'rule',rule,'confirmationPlan',d.confirmation, ...
    'budget',['C2 is the last registered candidate after the failed C1 (451-455); one confirmation (431-450); ' ...
    'no seed exclusion, retraining, budget extension or relaxed criteria.'], ...
    'sources',code,'evidence',evidence,'confirmationOpened',strcmp(phase,'confirmation'),'trainingStarted',false);
fid = fopen(file,'w','n','UTF-8'); assert(fid>=0);
fwrite(fid,jsonencode(registration,'PrettyPrint',true),'char'); fclose(fid);
fprintf('[v7] registered %s: %d sources, seeds %s\n',phase,numel(code),mat2str(seeds));
end

function p = relativePath(root,file)
p = strrep(erase(string(file),string(root)+filesep),'\','/');
end
