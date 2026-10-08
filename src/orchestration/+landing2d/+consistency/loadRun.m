function [agent,info,file,ok] = loadRun(arm)
% LOADRUN  Trained policy of one comparison run, if its checkpoint is compatible.
% ARM from landing2d.config.applyMethod. ok is false when the checkpoint
% (<outputDir>/<rl.policyFile>) is missing or its training signature does not
% match ARM (not trained or stale); the typed graph is verified on load.
agent = []; info = struct(); ok = false;
file = fullfile(arm.outputDir,arm.rl.policyFile);
if ~isfile(file), return; end
saved = load(file);
if ~isfield(saved,'signature') || ~landing2d.rl.signatureMatches(saved.signature,arm)
    return;
end
agent = landing2d.rl.normalizeAgent(saved.agent,arm.rl);
landing2d.rl.verifyCheckpointGraph(agent,arm);
info = saved.info;
ok = true;
end
