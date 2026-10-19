function [decisionTrace,annotations] = loadTrace(file)
% LOADTRACE  Load a recorded decision trace for replay (no simulation, no policy call).
%   [trace,annotations] = landing2d.trace.loadTrace(file)
saved = load(file);
assert(isfield(saved,'decisionTrace') && isfield(saved.decisionTrace,'schemaVersion') ...
    && strcmp(saved.decisionTrace.schemaVersion,'decision_trace_v1'),'landing2d:TraceFile', ...
    'Not a decision_trace_v1 file: %s',file);
decisionTrace = saved.decisionTrace;
annotations = [];
if isfield(saved,'annotations'), annotations = saved.annotations; end
end
