function report = inspectPipeline(agent,s,obs,memory,c,verbose)
% INSPECTPIPELINE  상태 표현 경로를 한 시점에 대해 펼쳐 보는 디버깅 도구.
%
%   o_t  ->  G_t = (V_t, E_t, X_t)  ->  H_t  ->  g_t  ->  a_t
%
% 노드 이름과 관계 유형, 현재 노드 값과 그 값이 어느 관측에서 왔는지까지 함께
% 출력합니다. 정보경계 점검(요구사항 20번 Test 4)과 그래프 구조 점검(Test 5)에
% 쓰는 표를 그대로 돌려줍니다.
%
% H_t의 각 성분에는 의미를 붙이지 않습니다. 학습으로 얻은 잠재 표현이라
% 개별 차원이 특정 물리량을 뜻하지 않습니다. 크기(노름)만 요약해 보여 줍니다.
%
%   report = landing2d.graphstate.inspectPipeline(agent,s,obs,memory,c);
if nargin < 6 || isempty(verbose)
    verbose = true;
end
dtAction = c.dt*c.rl.actionInterval;
[o,memoryAfter] = landing2d.rl.observation(s,obs,memory,c,dtAction);
spec = agent.encoderSpec;
report = struct('observation',o,'mode',spec.mode);

if strcmp(spec.mode,'baseline')
    state = o;
    report.graph = [];
else
    [state,detail] = landing2d.graphstate.situationGraph(s,obs,memoryAfter,c);
    [~,sources] = landing2d.graphstate.observationSemantics(s,obs,memoryAfter,c);
    schema = detail.schema;
    nodeNames = schema.nodeNames(:);
    value = detail.values(:);
    isRisk = ismember((1:schema.nNodes)',schema.riskNodes);
    source = cell(schema.nNodes,1);
    for i = 1:schema.nNodes
        if isfield(sources,nodeNames{i})
            source{i} = sources.(nodeNames{i});
        else
            source{i} = '(not an observation channel)';
        end
    end
    report.graph = struct('schema',schema,'X',detail.X,'values',detail.values, ...
        'semantics',detail.semantics, ...
        'nodeTable',table(nodeNames,value,isRisk,source, ...
            'VariableNames',{'Node','Value','IsRisk','Source'}), ...
        'edgeTable',edgeTable(schema));
end
report.state = state;

% 부호기를 지나며 H_t와 g_t를 함께 꺼냅니다.
[g,cache] = landing2d.graphstate.encoderForward(agent.policy.encoder,spec,state);
report.g = g;
if isfield(cache,'H')
    report.H = cache.H;
else
    report.H = [];
end
[u,~,mu] = landing2d.rl.policyAction(agent,state,[],true);
[ax,az] = landing2d.rl.actionFromCommand(u,c);
report.command = u;
report.mu = mu;
report.action = [ax;az];
report.value = landing2d.rl.valueForward(agent,state);

if ~verbose
    return;
end
fprintf('\n=== 상태 표현 경로 (%s) ===\n',spec.mode);
fprintf('o_t  : %d차원 관측 벡터\n',numel(o));
fprintf('  %s\n',mat2str(o(:)',4));
if isempty(report.graph)
    fprintf('G_t  : 사용하지 않음 (기준 모델은 o_t를 그대로 정책에 넣습니다)\n');
else
    schema = report.graph.schema;
    fprintf('G_t  : 노드 %d개, 간선 %d개, 관계 유형 %d개, 노드 특징 %d차원\n', ...
        schema.nNodes,numel(schema.src),schema.nRelations,schema.inDim);
    fprintf('       관계: %s\n',strjoin(schema.relationNames,', '));
    disp(report.graph.nodeTable);
    fprintf('H_t  : [%d x %d] 노드 임베딩 (개별 성분에 의미를 붙이지 않음)\n', ...
        size(report.H,1),size(report.H,2));
    fprintf('       노드별 노름: %s\n', ...
        mat2str(sqrt(sum(report.H(:,:,1).^2,1)),3));
end
fprintf('g_t  : %d차원 그래프 수준 표현, 노름 %.4f\n',numel(g),norm(g));
fprintf('a_t  : ax %.4f m/s^2, az %.4f m/s^2  (제한 전 명령 %s)\n', ...
    ax,az,mat2str(u(:)',4));
fprintf('V    : %.4f\n',report.value);
end

function t = edgeTable(schema)
% 간선 (i, r, j) 목록. 관계 유형을 유지한 채로 보여 줍니다.
source = schema.nodeNames(schema.src)';
relation = schema.relationNames(schema.rel)';
destination = schema.nodeNames(schema.dst)';
t = table(source,relation,destination, ...
    'VariableNames',{'Source','Relation','Destination'});
end
