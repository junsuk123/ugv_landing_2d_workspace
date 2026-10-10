function [fig,summary] = plotOntologyEvidence(options)
% PLOTONTOLOGYEVIDENCE Compatibility entry for the current matched result.
% The former review plot consumed superseded consistency artifacts. Keep the
% public function name, but route it to the single current evidence source.
if nargin < 1, options = struct(); end
[fig,summary] = landing2d.viz.plotParameterMatchedEvidence(options);
end
