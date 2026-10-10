classdef FactorizedRelationalContextLayer < nnet.layer.Layer
    % FACTORIZEDRELATIONALCONTEXTLAYER R-GAT with channel/node readout factors.
    properties (Learnable)
        W1
        a1
        E1
        W0
        b0
        Wc
        Wn
        bg
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
        function layer = FactorizedRelationalContextLayer(params,spec,name)
            layer.Name=name;
            layer.Description='Ontology R-GAT with factorized grouped readout';
            T=spec.T;
            layer.InDim=spec.inDim;
            layer.NumNodes=spec.nNodes;
            layer.HiddenDim=spec.hiddenDim;
            layer.NumRelations=size(params.W1,3);
            layer.IdxSrc=T.idxSrc(:);
            layer.IdxDst=T.idxDst(:);
            layer.ColIdx=T.colIdx(:)';
            layer.Rel=T.rel(:);
            layer.Dst=T.dst(:);
            layer.Msel=T.Msel;
            layer.GroupMatrix=spec.groupMatrix;
            layer.W1=params.W1;
            layer.a1=params.a1;
            layer.E1=params.E1;
            layer.W0=params.W0;
            layer.b0=params.b0;
            layer.Wc=params.Wc;
            layer.Wn=params.Wn;
            layer.bg=params.bg;
        end

        function Z = predict(layer,X)
            din=layer.InDim; N=layer.NumNodes; dh=layer.HiddenDim;
            R=layer.NumRelations; B=size(X,2);
            Xf=reshape(X,din,N*B);
            HW=cell(1,R); an=cell(R,1); bn=cell(R,1); sc=cell(R,1);
            for r=1:R
                HWr=layer.W1(:,:,r)*Xf;
                HW{r}=reshape(HWr,dh,N,B);
                an{r}=layer.a1(1,1:dh,r)*HWr;
                bn{r}=layer.a1(1,dh+1:2*dh,r)*HWr;
                sc{r}=layer.a1(1,2*dh+1:end,r)*layer.E1(:,r);
            end
            src=reshape(cat(1,an{:}),R*N,B);
            dst=reshape(cat(1,bn{:}),R*N,B);
            bias=cat(1,sc{:});
            raw=src(layer.IdxSrc,:)+dst(layer.IdxDst,:)+bias(layer.Rel);
            score=0.6*raw+0.4*abs(raw);
            expScore=exp(score);
            denominator=layer.Msel*expScore+1e-9;
            alpha=expScore./denominator(layer.Dst,:);
            messages=cat(2,HW{:});
            messages=messages(:,layer.ColIdx,:);
            weighted=messages.*reshape(alpha,1,[],B);
            aggregated=pagemtimes(weighted,layer.Msel.');
            local=reshape(layer.W0*Xf+layer.b0,dh,N,B);
            H=tanh(aggregated+local);
            grouped=pagemtimes(H,layer.GroupMatrix.');
            channel=pagemtimes(layer.Wc,grouped);
            Z=tanh(reshape(sum(channel.*layer.Wn,2),size(layer.Wc,1),B)+layer.bg);
        end
    end
end
