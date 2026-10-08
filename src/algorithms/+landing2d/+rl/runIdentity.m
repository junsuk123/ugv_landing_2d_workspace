function run = runIdentity(agent,c,checkpointFile)
% RUNIDENTITY  Identity of one trained or loaded policy for logs and tables.
% method_id, training/graph seeds, the typed graph actually used (hash and
% relation ids), the checkpoint file and its SHA-256 hash, and whether the
% relational path reaches the outputs (relation-path guard diagnostic).
if nargin < 3, checkpointFile = ''; end
methodId = c.graphState.stateRepresentation; label = methodId;
trainSeed = NaN; graphSeed = NaN; perturbation = 'none';
if isfield(c,'comparisonRun')
    methodId = c.comparisonRun.methodId; label = c.comparisonRun.label;
    trainSeed = c.comparisonRun.trainSeed; graphSeed = c.comparisonRun.graphSeed;
    perturbation = c.comparisonRun.graphPerturbation;
end
graphHash = ''; graphRel = '';
if isfield(agent.encoderSpec,'graph') && ~isempty(agent.encoderSpec.graph)
    graphHash = agent.encoderSpec.graph.hash;
    graphRel = mat2str(agent.encoderSpec.graph.rel);
end
checkpointHash = '';
if ~isempty(checkpointFile) && isfile(checkpointFile)
    fid = fopen(checkpointFile,'r'); bytes = fread(fid,'*uint8'); fclose(fid);
    checkpointHash = landing2d.util.sha256(bytes);
end
[active,audit] = landing2d.rl.relationalPathActive(agent);
run = struct('MethodId',methodId,'Label',label, ...
    'Representation',c.graphState.stateRepresentation, ...
    'GraphPerturbation',perturbation,'TrainSeed',trainSeed,'GraphSeed',graphSeed, ...
    'TrainingRandomSeed',c.rl.seed,'GraphHash',graphHash,'GraphRelation',graphRel, ...
    'CheckpointFile',checkpointFile,'CheckpointHash',checkpointHash, ...
    'RelationalPathRequired',audit.required,'RelationalPathActive',active);
end
