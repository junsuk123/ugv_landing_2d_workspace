classdef RelationalContextLayer < nnet.layer.Layer
    % RELATIONALCONTEXTLAYER  온톨로지 R-GAT 1층 + 그룹 readout -> 관계 문맥 c_t.
    %
    % landing2d.graphstate.encoderForward('context_rgat','raw_plus_groups')의
    % 관계 경로와 같은 계산입니다.
    %   z_i^r = W_r x_i,  e_ij^r = LeakyReLU_0.2(a_r'[z_i^r; z_j^r; rho_r])
    %   alpha = 도착 노드의 모든 수신 간선에 대한 공동 softmax (분모 + 1e-9)
    %   h_j = tanh(sum alpha W_r x_i + W_0 x_j + b_0)
    %   c_t = tanh(W_c [그룹 평균 h] + b_c)
    % 입력은 펴 놓은 노드 특징 s_t(108 x B), 출력은 c_t(4 x B)입니다.
    % raw semantic 경로는 이 층 밖의 MLP가 맡습니다.
    properties (Learnable)
        W1   % [dh x din x R] 관계별 사영 W_r
        a1   % [1 x (2dh+relDim) x R] attention 벡터 a_r
        E1   % [relDim x R] 관계 임베딩 rho_r (학습률 0으로 고정)
        W0   % [dh x din] 자기 노드 경로 (고정)
        b0   % [dh x 1] (고정)
        Wg   % [K x dh*K] 그룹 readout W_c
        bg   % [K x 1] b_c
    end
    properties
        InDim
        NumNodes
        HiddenDim
        NumRelations
        IdxSrc
        IdxDst
        ColIdx
        Rel
        Dst
        Msel
        GroupMatrix
    end

    methods
        function layer = RelationalContextLayer(params,spec,name)
            layer.Name = name;
            layer.Description = 'Ontology R-GAT relation context (grouped readout)';
            T = spec.T;
            layer.InDim = spec.inDim;
            layer.NumNodes = spec.nNodes;
            layer.HiddenDim = spec.hiddenDim;
            layer.NumRelations = size(params.W1,3);
            layer.IdxSrc = T.idxSrc(:);
            layer.IdxDst = T.idxDst(:);
            layer.ColIdx = T.colIdx(:)';
            layer.Rel = T.rel(:);
            layer.Dst = T.dst(:);
            layer.Msel = T.Msel;
            layer.GroupMatrix = spec.groupMatrix;
            layer.W1 = params.W1;
            layer.a1 = params.a1;
            layer.E1 = params.E1;
            layer.W0 = params.W0;
            layer.b0 = params.b0;
            layer.Wg = params.Wg;
            layer.bg = params.bg;
        end

        function Z = predict(layer,X)
            din = layer.InDim;
            N = layer.NumNodes;
            dh = layer.HiddenDim;
            R = layer.NumRelations;
            B = size(X,2);
            Xf = reshape(X,din,N*B);
            HW = cell(1,R);
            an = cell(R,1);
            bn = cell(R,1);
            sc = cell(R,1);
            for r = 1:R
                HWr = layer.W1(:,:,r)*Xf;
                HW{r} = reshape(HWr,dh,N,B);
                an{r} = layer.a1(1,1:dh,r)*HWr;
                bn{r} = layer.a1(1,dh+1:2*dh,r)*HWr;
                sc{r} = layer.a1(1,2*dh+1:end,r)*layer.E1(:,r);
            end
            src = reshape(cat(1,an{:}),R*N,B);
            dst = reshape(cat(1,bn{:}),R*N,B);
            bias = cat(1,sc{:});
            raw = src(layer.IdxSrc,:)+dst(layer.IdxDst,:)+bias(layer.Rel);
            score = 0.6*raw+0.4*abs(raw);
            expScore = exp(score);
            denominator = layer.Msel*expScore+1e-9;
            alpha = expScore./denominator(layer.Dst,:);
            messages = cat(2,HW{:});
            messages = messages(:,layer.ColIdx,:);
            weighted = messages.*reshape(alpha,1,[],B);
            aggregated = pagemtimes(weighted,layer.Msel.');
            local = reshape(layer.W0*Xf+layer.b0,dh,N,B);
            H = tanh(aggregated+local);
            grouped = pagemtimes(H,layer.GroupMatrix.');
            readout = reshape(grouped,[],B);
            Z = tanh(layer.Wg*readout+layer.bg);
        end
    end
end
