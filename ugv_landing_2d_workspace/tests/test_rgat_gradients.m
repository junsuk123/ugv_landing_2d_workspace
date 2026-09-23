function test_rgat_gradients()
% TEST_RGAT_GRADIENTS  직접 구현한 R-GAT 역전파를 중앙 차분과 비교.
% 관계형 주의, softmax 정규화, 잔차 연결, 목표 노드 읽기를 모두 지나는 경로입니다.
schema = landing2d.ontology.nodeSchema();
onto = landing2d.ontology.defaultOntologyConfig();
onto.hiddenDim = 5;
onto.relationDim = 3;
T = landing2d.rgat.topology(schema);
rs = RandStream('threefry','Seed',3);
P = landing2d.rgat.potentialInit(schema,onto,rs);
batch = 4;
X = rand(rs,schema.inDim,schema.nNodes,batch);
y = 2*rand(rs,1,batch)-1;
[loss,grads,phi] = landing2d.rgat.potentialLoss(P,X,y,T,onto);
assert(isfinite(loss) && loss > 0);
assert(all(abs(phi) <= 1),'The potential must stay inside [-1,1].');
step = 1e-6;
names = {'W1','a1','E1','W2','a2','E2','wOut','bOut'};
for n = 1:numel(names)
    key = names{n};
    indices = unique([1,round(numel(P.(key))/2),numel(P.(key))]);
    for i = indices
        plus = P; minus = P;
        plus.(key)(i) = plus.(key)(i)+step;
        minus.(key)(i) = minus.(key)(i)-step;
        lossPlus = landing2d.rgat.potentialLoss(plus,X,y,T,onto);
        lossMinus = landing2d.rgat.potentialLoss(minus,X,y,T,onto);
        numeric = (lossPlus-lossMinus)/(2*step);
        analytic = grads.(key)(i);
        tolerance = 1e-4*max(abs(numeric),1e-6)+1e-9;
        assert(abs(numeric-analytic) <= tolerance, ...
            sprintf('R-GAT gradient mismatch at %s(%d): %.3e vs %.3e', ...
            key,i,numeric,analytic));
    end
end
end
