function T = topology(schema)
% TOPOLOGY  관계형 주의 계층이 쓰는 간선 색인표. 스키마가 고정이라 한 번만 계산.
% 색인 규칙은 원 저장소 rgat.topology와 같고, 역전파용 분산 행렬을 추가했습니다.
persistent cachedKey cachedValue
src = double(schema.src(:)');
dst = double(schema.dst(:)');
rel = double(schema.rel(:)');
N = schema.nNodes;
R = schema.nRelations;
key = [N,R,src,dst,rel];
if ~isempty(cachedKey) && isequal(cachedKey,key)
    T = cachedValue;
    return;
end
nEdges = numel(src);
T = struct();
T.src = src; T.dst = dst; T.rel = rel;
T.nNodes = N; T.nRelations = R; T.nEdges = nEdges;
T.goalNode = schema.goalNode;
% [R x N] 관계별 노드 평면으로 들어가는 색인
T.idxSrc = rel+R*(src-1);
T.idxDst = rel+R*(dst-1);
% [dout x N*R] 관계 사영 스택에서 출발 노드 열
T.colIdx = src+N*(rel-1);
% 도착 노드 인접 행렬 (순전파의 합산과 softmax 분모에 사용)
T.Msel = scatterMatrix(dst,N,nEdges);
% 역전파에서 간선 기울기를 노드/관계 축으로 되돌리는 행렬
T.Mcol = scatterMatrix(T.colIdx,N*R,nEdges);
T.Msrc = scatterMatrix(T.idxSrc,R*N,nEdges);
T.Mdst = scatterMatrix(T.idxDst,R*N,nEdges);
T.Mrel = scatterMatrix(rel,R,nEdges);
cachedKey = key;
cachedValue = T;
end

function M = scatterMatrix(index,rows,nEdges)
% 같은 행에 여러 간선이 모이는 경우를 더해서 처리.
M = zeros(rows,nEdges);
for e = 1:nEdges
    M(index(e),e) = M(index(e),e)+1;
end
end
