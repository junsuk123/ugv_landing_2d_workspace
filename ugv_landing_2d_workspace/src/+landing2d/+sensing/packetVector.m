function x = packetVector(packet,schema)
% PACKETVECTOR  Serialize a named packet; dimensions never live as magic numbers.
if nargin < 2 || isempty(schema)
    schema = landing2d.sensing.observationSchema();
end
x = zeros(schema.dimension,1);
for i = 1:schema.dimension
    name = schema.names{i};
    assert(isfield(packet,name),'landing2d:PacketField', ...
        'Observation packet is missing %s.',name);
    value = packet.(name);
    validateattributes(value,{'numeric','logical'},{'scalar','real','finite'}, ...
        mfilename,name);
    x(i) = double(value);
end
end
