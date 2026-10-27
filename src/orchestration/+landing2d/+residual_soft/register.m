function registration = register(phase,evidence)
% REGISTER Write the registration of a relational_residual_v6 phase before it runs.
%   landing2d.residual_soft.register('development',evidence)
%   landing2d.residual_soft.register('confirmation',evidence)
% Registers the SHA-256 of every MATLAB source under src/ and of the design
% document, the seeds, environments, gate or confirmation rule, budget and
% stop rule, and EVIDENCE (pre-check reports, file hashes, the passed
% development gate for the confirmation). Refuses an existing registration.
d = landing2d.residual_soft.config();
assert(ismember(phase,{'development','confirmation'}));
folder = fullfile(d.outputDir,phase);
file = fullfile(folder,'registration.json');
assert(~isfile(file),'landing2d:ResidualV6Registered','Preserve the existing registration %s.',file);
if ~isfolder(folder), mkdir(folder); end
sources = dir(fullfile(d.root,'src','**','*.m'));
paths = [arrayfun(@(f)fullfile(f.folder,f.name),sources,'UniformOutput',false); ...
    {fullfile(d.root,'docs','RELATIONAL_RESIDUAL_V6_KO.md')}];
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
    'decision','Codex GO 2026-10-27: C1 phi(z)=0.9 tanh(z)+0.1 z in the residual correction branch; then C2 if C1 fails development; one confirmation.', ...
    'algorithmVersion',landing2d.rl.algorithmVersion(d.c),'trainSeeds',seeds, ...
    'environmentSeeds',environments,'methods',{d.methods},'parameterCounts',d.parameterCounts, ...
    'evaluationProtocol',d.c.evaluation.protocolVersion,'rule',rule,'confirmationPlan',d.confirmation, ...
    'budget','At most C1 (451-455) and C2 (461-465) developments, one confirmation (431-450); no seed exclusion, retraining, budget extension or relaxed criteria.', ...
    'sources',code,'evidence',evidence,'confirmationOpened',strcmp(phase,'confirmation'),'trainingStarted',false);
fid = fopen(file,'w','n','UTF-8'); assert(fid>=0);
fwrite(fid,jsonencode(registration,'PrettyPrint',true),'char'); fclose(fid);
fprintf('[v6] registered %s: %d sources, seeds %s\n',phase,numel(code),mat2str(seeds));
end

function p = relativePath(root,file)
p = strrep(erase(string(file),string(root)+filesep),'\','/');
end
