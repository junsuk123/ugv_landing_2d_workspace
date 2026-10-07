classdef StateIndependentStdLayer < nnet.layer.Layer
    % STATEINDEPENDENTSTDLAYER  상태와 무관한 Gaussian 정책 표준편차.
    % sigma = exp(max(logStd, minimumLogStd)). landing2d.rl.ppoTrain이 갱신 뒤
    % logStd를 하한으로 자르는 것과 같은 탐색 하한입니다.
    properties (Learnable)
        LogStd
    end
    properties
        MinimumLogStd
    end

    methods
        function layer = StateIndependentStdLayer(logStd,minimumLogStd,name)
            layer.Name = name;
            layer.Description = 'State-independent Gaussian policy std';
            layer.LogStd = logStd(:);
            layer.MinimumLogStd = minimumLogStd;
        end

        function Z = predict(layer,X)
            sigma = exp(max(layer.LogStd,layer.MinimumLogStd));
            Z = repmat(sigma,1,size(X,2));
        end
    end
end
