function registration = verifyRegistration(d,phase)
% VERIFYREGISTRATION No training/evaluation drift after registration.
file=fullfile(d.outputDir,phase,'registration.json');
assert(isfile(file),'landing2d:CurrentSemanticsNotRegistered','Register this phase before training.');
registration=jsondecode(fileread(file));
if strcmp(phase,'development'), seeds=d.developmentSeeds; environments=d.developmentEnvironments;
else, seeds=d.confirmationSeeds; environments=d.confirmationEnvironments; end
assert(strcmp(registration.version,d.version) && strcmp(registration.phase,phase));
assert(isequal(registration.trainSeeds(:)',seeds) ...
    && isequal(registration.environmentSeeds(:)',environments) ...
    && isequal(string(registration.methods(:)),string(d.methods(:))), ...
    'landing2d:CurrentSemanticsRegistration','Registered methods or seeds differ.');
assert(strcmp(registration.configurationSha256,landing2d.util.sha256(jsonencode(d.c))), ...
    'landing2d:CurrentSemanticsRegistration','Configuration changed after registration.');
landing2d.current_semantics.verifySources(d.root,registration.sources);
if strcmp(phase,'confirmation')
    prior=fullfile(d.outputDir,'development','results.mat');
    assert(strcmp(registration.developmentEvidence.resultsSha256,landing2d.bias_diagnostics.fileHash(prior)), ...
        'landing2d:CurrentSemanticsDevelopment','Development evidence changed after confirmation registration.');
end
end
