function runs = restoreTraining(d,seeds,folder)
% RESTORETRAINING Resume evaluation only; never call an optimizer or trainer.
file=fullfile(folder,'training_complete.mat'); sealFile=fullfile(folder,'training_manifest.json');
assert(isfile(file) && isfile(sealFile),'landing2d:CurrentSemanticsResume', ...
    'Completed, sealed training is missing. Mid-training recovery is not automatic.');
seal=jsondecode(fileread(sealFile));
assert(strcmp(seal.fileSha256,landing2d.bias_diagnostics.fileHash(file)), ...
    'landing2d:CurrentSemanticsResume','The saved training bundle changed.');
assert(isequal(seal.trainSeeds(:)',seeds) && isequal(string(seal.methods(:)),string(d.methods(:))));
saved=load(file,'runs','d'); runs=saved.runs;
assert(isequaln(saved.d.c,d.c) && numel(runs)==4*numel(seeds), ...
    'landing2d:CurrentSemanticsResume','The saved training configuration or run count differs.');
assert(numel(seal.checkpoints)==numel(runs));
for seed=seeds
    arms=landing2d.config.comparisonArms(d.c,struct('methods',{d.methods},'trainSeed',seed));
    for k=1:numel(arms)
        index=find(strcmp({runs.id},arms(k).id) & [runs.trainSeed]==seed);
        assert(numel(index)==1,'landing2d:CurrentSemanticsResume','A registered run is missing or duplicated.');
        r=runs(index);
        assert(isequaln(r.config,arms(k).config), ...
            'landing2d:CurrentSemanticsResume','The recorded run configuration differs from its registered arm.');
        expectedFile=fullfile(d.c.outputDir,arms(k).config.rl.policyFile);
        assert(strcmp(r.file,expectedFile) && isfile(expectedFile));
        stored=seal.checkpoints(index);
        assert(strcmp(stored.methodId,r.id) && stored.trainSeed==seed ...
            && strcmp(stored.file,expectedFile) ...
            && strcmp(stored.sha256,landing2d.bias_diagnostics.fileHash(expectedFile)), ...
            'landing2d:CurrentSemanticsResume','Checkpoint identity or checksum changed.');
        checkpoint=load(expectedFile,'agent','signature','info');
        assert(landing2d.rl.signatureMatches(checkpoint.signature,arms(k).config) ...
            && isequaln(checkpoint.agent,r.agent) && isequaln(checkpoint.info.history,r.history), ...
            'landing2d:CurrentSemanticsResume','Checkpoint signature, policy or selected validation history changed.');
        landing2d.rl.verifyCheckpointGraph(checkpoint.agent,arms(k).config);
    end
end
end
