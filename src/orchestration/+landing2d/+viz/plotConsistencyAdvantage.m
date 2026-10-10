function fig = plotConsistencyAdvantage(~,outputFile,visible)
% PLOTCONSISTENCYADVANTAGE Compatibility entry for current consistency data.
if nargin < 2, outputFile = ''; end
if nargin < 3, visible = true; end
options = struct('visible',visible);
if ~isempty(outputFile), options.outputFile = outputFile; end
[fig,~] = landing2d.viz.plotParameterMatchedConsistency(options);
end
