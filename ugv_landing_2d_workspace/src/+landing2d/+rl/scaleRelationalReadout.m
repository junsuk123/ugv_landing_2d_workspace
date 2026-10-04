function agent = scaleRelationalReadout(agent,scale)
% SCALERELATIONALREADOUT  Scale only the graph-to-context projection.
validateattributes(scale,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
for head = {'policy','value'}
    name = head{1};
    encoder = agent.(name).encoder;
    assert(isfield(encoder,'Wg') && isfield(encoder,'bg'), ...
        'landing2d:MissingRelationalReadout', ...
        '%s encoder does not contain Wg/bg.',name);
    encoder.Wg = scale*encoder.Wg;
    encoder.bg = scale*encoder.bg;
    agent.(name).encoder = encoder;
end
agent.relationalCalibrationScale = scale;
end
