function [agent,info,file] = loadCheckpoint(c)
% LOADCHECKPOINT  Load a compatible saved policy without ever training.
file = fullfile(c.outputDir,c.rl.policyFile);
if ~isfile(file)
    error('landing2d:CheckpointNotFound', ...
        'Policy checkpoint not found: %s',file);
end
saved = load(file);
if ~isfield(saved,'agent') || ~isfield(saved,'signature')
    error('landing2d:InvalidCheckpoint', ...
        'Checkpoint must contain agent and signature: %s',file);
end

if ~landing2d.rl.signatureMatches(saved.signature,c)
    error('landing2d:CheckpointMismatch', ...
        ['Checkpoint is incompatible with the current reward, state, or ' ...
         'environment configuration: %s\nRun with retrain=true ' ...
         'before final evaluation.'],file);
end
agent = landing2d.rl.normalizeAgent(saved.agent,c.rl);
landing2d.rl.verifyCheckpointGraph(agent,c);
if isfield(saved,'info')
    info = saved.info;
else
    info = struct();
end
end
