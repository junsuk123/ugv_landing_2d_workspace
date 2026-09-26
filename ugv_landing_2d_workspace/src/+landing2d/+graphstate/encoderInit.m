function [params,spec] = encoderInit(gs,observationDim,rs)
% ENCODERINIT  그래프 부호기의 학습 파라미터와 고정 명세를 생성.
%
% params는 숫자 배열만 담습니다. landing2d.util.adamInit / adamUpdate /
% clipGradient가 중첩 구조체를 그대로 훑기 때문에, 여기에 문자열이나 색인표를
% 넣으면 최적화기가 깨집니다. 그래서 바뀌지 않는 정보는 전부 spec으로 뺍니다.
%
% 'baseline'에서는 params가 빈 구조체이고 부호기가 항등 사상입니다.
% 빈 구조체는 Adam에서 갱신할 항목이 없고 기울기 노름에 0을 더하므로,
% 기준 모델의 수치 결과가 이 변경 전과 완전히 같습니다.
mode = gs.stateRepresentation;
spec = struct('mode',mode,'readout',gs.readout);
if strcmp(mode,'baseline')
    params = struct();
    spec.inDim = 0;
    spec.nNodes = 0;
    spec.hiddenDim = 0;
    spec.stateDim = observationDim;
    spec.graphDim = observationDim;
    spec.schema = [];
    spec.T = [];
    return;
end
[schema,T] = landing2d.graphstate.schemaFor(mode);
dh = gs.hiddenDim;
spec.schema = schema;
spec.T = T;
spec.inDim = schema.inDim;
spec.nNodes = schema.nNodes;
spec.hiddenDim = dh;
spec.stateDim = schema.inDim*schema.nNodes;
if strcmp(mode,'semantic_flat')
    % Same semantic features as the graph arms, passed directly to the MLP.
    % This separates added-information gains from graph-structure gains.
    params = struct();
    spec.hiddenDim = 0;
    spec.graphDim = spec.stateDim;
    return;
end
scale = gs.initScale;
switch mode
    case 'node_pool'
        % 메시지 전달 없이 노드별 사영만. 간선을 전혀 쓰지 않습니다.
        params.Wn = scale*randn(rs,dh,schema.inDim);
        params.bn = zeros(dh,1);
    case {'gat','ontology_rgat'}
        % 두 층 관계형 주의. 두 번째 층에 잔차 연결이 있어 두 층의 폭이 같아야 합니다.
        R = schema.nRelations;
        relDim = gs.relationDim;
        params.W1 = scale*randn(rs,dh,schema.inDim,R);
        params.a1 = scale*randn(rs,1,2*dh+relDim,R);
        params.E1 = scale*randn(rs,relDim,R);
        params.W2 = scale*randn(rs,dh,dh,R);
        params.a2 = scale*randn(rs,1,2*dh+relDim,R);
        params.E2 = scale*randn(rs,relDim,R);
    otherwise
        error('landing2d:UnknownStateRepresentation', ...
            'encoderInit does not handle stateRepresentation %s.',mode);
end
switch gs.readout
    case 'meanmax'
        % g_t = tanh(Wg*[mean(H_t,2); max(H_t,2)]+bg)
        params.Wg = scale*randn(rs,gs.graphDim,2*dh);
        params.bg = zeros(gs.graphDim,1);
        spec.graphDim = gs.graphDim;
    case 'mean'
        % g_t = mean(H_t,2). 추가 파라미터가 없습니다.
        spec.graphDim = dh;
    otherwise
        error('landing2d:UnknownReadout','Unknown readout: %s',gs.readout);
end
end
