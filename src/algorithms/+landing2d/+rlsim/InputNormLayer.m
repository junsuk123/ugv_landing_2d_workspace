classdef InputNormLayer < nnet.layer.Layer
    % INPUTNORMLAYER  고정 MLP 입력 표준화 (landing2d.rl.mlpInput과 같은 연산).
    % Z = min(max((X-Mean)./sqrt(Var+Epsilon),-Clip),Clip). 학습 파라미터가 없으며,
    % 통계는 구조체 정책(agent.inputNorm)의 값을 그대로 씁니다. RL Toolbox 학습은
    % 통계를 갱신하지 않습니다(running 갱신은 landing2d.rl.ppoTrain 전용).
    properties
        Mean
        Var
        Epsilon
        Clip
    end

    methods
        function layer = InputNormLayer(inputNorm,name)
            layer.Name = name;
            layer.Description = 'Fixed MLP input standardization';
            layer.Mean = inputNorm.mean(:);
            layer.Var = inputNorm.var(:);
            layer.Epsilon = inputNorm.epsilon;
            layer.Clip = inputNorm.clip;
        end

        function Z = predict(layer,X)
            Z = (X-layer.Mean)./sqrt(layer.Var+layer.Epsilon);
            Z = min(max(Z,-layer.Clip),layer.Clip);
        end
    end
end
