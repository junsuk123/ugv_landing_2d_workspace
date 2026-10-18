function [agent,info,file] = loadOrTrainAgent(c,trainer)
% LOADORTRAINAGENT  Reuse a checkpoint with a matching training signature, else train and save.
%   [agent,info,file] = landing2d.rl.loadOrTrainAgent(c)
% c.rl.retrain = true always trains. The checkpoint stores agent (with the
% typed graph actually used: src/dst/rel and graph hash), info (training
% history), the training signature and the run identity (method, seeds, graph).
if nargin < 2 || isempty(trainer), trainer = @landing2d.rl.ppoTrain; end
file = fullfile(c.outputDir,c.rl.policyFile);
signature = landing2d.rl.trainingSignature(c);
if ~c.rl.retrain && isfile(file)
    saved = load(file);
    if isfield(saved,'agent') && isfield(saved,'signature') ...
            && landing2d.rl.signatureMatches(saved.signature,c)
        agent = saved.agent;
        landing2d.rl.verifyCheckpointGraph(agent,c);
        info = saved.info;
        fprintf('  reusing checkpoint %s\n',file);
        return;
    end
    fprintf('  checkpoint %s does not match the current configuration: retraining\n',file);
end
[agent,info] = landing2d.rl.trainAgent(c,trainer);
folder = fileparts(file);
if ~exist(folder,'dir')
    [ok,message] = mkdir(folder);
    if ~ok, error('landing2d:OutputDirectory','%s',message); end
end
run = landing2d.rl.runIdentity(agent,c); %#ok<NASGU>
save(file,'agent','info','signature','run');
fprintf('  saved checkpoint %s\n',file);
end
