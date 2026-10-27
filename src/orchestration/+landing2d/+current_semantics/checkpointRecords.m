function records = checkpointRecords(runs)
% CHECKPOINTRECORDS Immutable policy files behind the evaluation.
records=arrayfun(@(r)struct('methodId',string(r.id),'trainSeed',r.trainSeed, ...
    'file',r.file,'sha256',string(landing2d.bias_diagnostics.fileHash(r.file))),runs);
end
