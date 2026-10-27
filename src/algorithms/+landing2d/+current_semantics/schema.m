function [s,T,graph] = schema(mode)
% SCHEMA Current-observation motion -> condition -> landing-context graph.
% All edges are additive. Layers are computational hops, not time steps.
% The untyped control merges the four semantic types; self stays separate.
if nargin < 1, mode = 'rgat'; end
assert(ismember(mode,{'rgat','untyped'}),'landing2d:CurrentSemanticsMode', ...
    'The graph mode must be rgat or untyped.');
s = struct();
s.variant = ['current_semantics_v1_',mode];
s.nodeNames = {'ObservationQuality','RelativeGeometry','MotionState', ...
    'AttitudeState','ApproachSituation','ContactCondition','LandingContext'};
s.nodeSymbols = {'Q','R','V','A','P','C','L'};
s.nNodes = 7; s.inDim = 6; s.goalNode = 7;
s.relationNames = {'qualifiesEstimate','informsApproach','conditionsContact','informsLanding','self'};
s.src = [1 1 2 3 2 3 4 5 6 1:7];
s.dst = [5 6 5 5 6 6 6 7 7 1:7];
s.rel = [1 1 2 2 3 3 3 4 4 repmat(5,1,7)];
if strcmp(mode,'untyped')
    s.relationNames = {'semantic','self'};
    s.rel = [ones(1,9),2*ones(1,7)];
end
s.nRelations = numel(s.relationNames);
s.relationOperators = repmat({'propagate'},1,s.nRelations);
s.semanticEdges = 1:9; s.selfEdges = 10:16;
s.edgeTable = cell(9,3);
for e = 1:9
    s.edgeTable(e,:) = {s.nodeNames{s.src(e)},s.nodeNames{s.dst(e)},s.relationNames{s.rel(e)}};
end
s.activeChannels = {1:2,1:2,1:4,1:3,1:3,1:5,[]};
s.activeLinearIndices = [1 2 7 8 13 14 15 16 19 20 21 25 26 27 31 32 33 34 35];
s.phiNames = {'visionUpdated','visionAge','relativeX','relativeHeight', ...
    'relativeVx','ugvVx','droneVx','droneVz','sinPitch','cosPitch','pitchRate', ...
    'approachError','approachErrorRate','approachErrorGrowth', ...
    'contactXRatio','contactRelativeVxRatio','contactVzRatio', ...
    'contactPitchRatio','contactPitchRateRatio'};
s.phiDim = numel(s.phiNames);
if nargout > 1, T = landing2d.rgat.topology(s); end
if nargout > 2
    % This helper records a canonical graph hash without changing the graph.
    [s,T,graph] = landing2d.rgat.applyRelationPerturbation(s,T,struct());
end
end
