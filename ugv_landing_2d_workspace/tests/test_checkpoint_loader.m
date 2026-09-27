function test_checkpoint_loader()
% TEST_CHECKPOINT_LOADER  Strict loading never falls back to training.
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@()removeFolder(folder)); %#ok<NASGU>
c = landing2d.config.defaultConfig();
c.outputDir = folder;
c.rl.policyFile = 'test_policy.mat';
rs = RandStream('threefry','Seed',7);
agent = landing2d.rl.agentInit(c.rl,rs,c.graphState);
info = struct('source','unit test');
signature = landing2d.rl.trainingSignature(c);
save(fullfile(folder,c.rl.policyFile),'agent','info','signature');
[loaded,loadedInfo,file] = landing2d.rl.loadCheckpoint(c);
assert(isequal(loaded.policy.logStd,agent.policy.logStd));
assert(strcmp(loadedInfo.source,'unit test') && isfile(file));
changed = c;
changed.dt = 2*c.dt;
assertThrows(@()landing2d.rl.loadCheckpoint(changed), ...
    'landing2d:CheckpointMismatch');
end

function removeFolder(folder)
if exist(folder,'dir'), rmdir(folder,'s'); end
end

function assertThrows(fn,identifier)
threw = false;
try
    fn();
catch err
    threw = true;
    assert(strcmp(err.identifier,identifier));
end
assert(threw,sprintf('Expected %s.',identifier));
end
