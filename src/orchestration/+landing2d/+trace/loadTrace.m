function [decisionTrace,annotations] = loadTrace(file)
% LOADTRACE  Load a recorded decision trace for replay (no simulation, no policy call).
%   [trace,annotations] = landing2d.trace.loadTrace(file)
saved = load(file);
assert(isfield(saved,'decisionTrace') && isfield(saved.decisionTrace,'schemaVersion') ...
    && strcmp(saved.decisionTrace.schemaVersion,'decision_trace_v1'),'landing2d:TraceFile', ...
    'Not a decision_trace_v1 file: %s',file);
decisionTrace = saved.decisionTrace;
% Traces recorded before relational-policy-v2.13 have no graph feature
% version; they were all tosm7_v2.
for k = 1:numel(decisionTrace.records)
    if ~isfield(decisionTrace.records(k).graph,'featureVersion')
        decisionTrace.records(k).graph.featureVersion = 'tosm7_v2';
    end
end
annotations = [];
if isfield(saved,'annotations'), annotations = saved.annotations; end
end
