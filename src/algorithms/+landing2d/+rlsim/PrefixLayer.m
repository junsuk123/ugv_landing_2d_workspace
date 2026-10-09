classdef PrefixLayer < nnet.layer.Layer
    % PREFIXLAYER  Select the common-observation prefix of a combined state.
    properties
        Count
    end
    methods
        function layer=PrefixLayer(count,name)
            layer.Name=name;
            layer.Description='Common-observation prefix';
            layer.Count=count;
        end
        function Z=predict(layer,X)
            Z=X(1:layer.Count,:);
        end
    end
end
