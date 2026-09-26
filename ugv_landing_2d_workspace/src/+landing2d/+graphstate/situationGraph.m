function [S,detail] = situationGraph(s,obs,memory,c)
% SITUATIONGRAPH  현재 착륙 상황의 온톨로지 그래프 G_t = (V_t, E_t, X_t).
%
% 돌려주는 S는 노드 특징 행렬 X_t를 한 열로 편 것입니다([inDim*nNodes x 1]).
% PPO 쪽 자료 구조가 기준 모델과 같은 [stateDim x batch] 행렬이 되도록 펴 두고,
% 부호기 안에서 다시 [inDim x nNodes x batch]로 되돌립니다.
%
%   V_t : landing2d.ontology.nodeSchema의 9개 고정 노드
%   E_t : 같은 스키마의 관계형 간선 (i, r, j)
%   X_t : landing2d.graphstate.nodeFeatures가 만드는 노드 특징 행렬
%         [값; 1-값; 위험 노드 표시; 편향; 방향 부호; 노드 정체성 one-hot]
%
% 노드 값은 landing2d.graphstate.observationSemantics가 계산하며, 기준 모델의
% 관측 파이프라인이 보는 정보만 사용합니다. 환경 참값은 들어가지 않습니다.
mode = c.graphState.stateRepresentation;
schema = landing2d.graphstate.schemaFor(mode);
[sem,~,signed,context] = landing2d.graphstate.observationSemantics(s,obs,memory,c);
values = landing2d.ontology.nodeValues(sem,schema);
X = landing2d.graphstate.nodeFeatures(values,signed,schema,context);
S = X(:);
if nargout > 1
    detail = struct('X',X,'values',values,'signed',signed, ...
        'context',context, ...
        'semantics',sem,'schema',schema);
end
end
