function C = selectionChain(decisionTrace,k,focus,D)
% SELECTIONCHAIN  Evidence chain of a selected element at decision K.
%   C = landing2d.trace.selectionChain(trace,k,focus)
% FOCUS (string array) uses the vertex ids of landing2d.trace.dependencyGraph
% or the shorthands "source:<id>", "channel:<i>", "node:<i>" (= x:i and h:i),
% "edge:<i>"; "readout", "actor" and "action" select the Actor output (the
% full end-to-end chain). C.vertices is the structural closure (ancestors and
% descendants of the focus), C.parents / C.children the one-level upstream /
% downstream sets (Back / Forward), and C.lines the chain text with the
% numbers of decision K: per-segment time stamps and fresh/predicted labels,
% feature values, relation definitions, operator pool, alpha, message size,
% gate, embeddings and the command. Highlighting is structural reachability
% and data provenance, never a causal attribution of the action to one path.
if nargin < 4 || isempty(D), D = landing2d.trace.dependencyGraph(decisionTrace); end
focus = expandFocus(string(focus),D);
present = ismember(focus,D.ids);
assert(all(present),'landing2d:TraceSelection','Unknown trace element(s): %s', ...
    strjoin(focus(~present),', '));
f = ismember(D.ids,focus);
up = reach(D.A',f); down = reach(D.A,f);
closure = up | down | f;
parents = any(D.A(:,f),2)' & ~f;
children = any(D.A(f,:),1) & ~f;
r = decisionTrace.records(min(k,numel(decisionTrace.records))); S = decisionTrace.schema; P = decisionTrace.provenance;
L = decisionTrace.labels; status = landing2d.trace.channelStatus(decisionTrace,k);
content = {sprintf('선택: %s — 결정 #%d, t = %.2f s',strjoin(arrayfun(@(x)vertexLabel(x,S,P,L), ...
    focus,'UniformOutput',false),', '),k,r.time)};
if D.layers == 1
    hopText = ['단일 R-GAT 층은 직접 들어오는 1-홉 간선만 모은 뒤 전체 노드 임베딩을 ' ...
        '리드아웃한다(다중 홉 추론 아님).'];
else
    hopText = sprintf(['R-GAT %d개 층이 층마다 들어오는 간선을 모으므로 관계는 최대 %d홉까지 합성된다. ' ...
        '논리 추론이 아니라 층별 집계이며, 마지막 층의 7개 노드 임베딩 전체가 리드아웃된다.'],D.layers,D.layers);
end
content{end+1} = ['[구조적 도달성] 강조된 경로는 모델 구조·데이터 출처상 연결된 요소이며 수치적 인과 ' ...
    '기여나 단일 원인이 아님. ',hopText];
s = r.sensing;
for p = find(closure(1:D.nProcessors))
    content{end+1} = ['[원천] ',sourceLine(P.processors{p},s,L)]; %#ok<AGROW>
end
offset = D.nProcessors;
for i = find(closure(offset+(1:D.nChannels)))
    content{end+1} = sprintf('[o_t %2d] %s = %+.4f (%s)',i,P.channelNames{i}, ...
        r.observation(i),status.label(i)); %#ok<AGROW>
end
offset = offset+D.nChannels;
for n = find(closure(offset+(1:D.nNodes)))
    feats = L.nodes(n).features; parts = strings(1,numel(feats));
    for j = 1:numel(feats), parts(j) = sprintf('%s=%+.3f',strtok(feats{j},' '),r.graph.X(j,n)); end
    content{end+1} = sprintf('[노드 특징 X_%d] %s (%s, %s): %s',n,S.nodeNames{n}, ...
        S.nodePerspective{n},L.nodes(n).label,strjoin(parts,', ')); %#ok<AGROW>
end
A = r.actor; gateMean = mean(A.gate,1);
for l = 1:D.layers
    edgeIds = compose("e%d:%02d",l,(1:D.nEdges)');
    for e = find(arrayfun(@(id)closure(D.ids==id),edgeIds'))
        pool = S.poolNames{S.edgePool(e)};
        gateText = '';
        if S.edgePool(e) == 2
            gateText = sprintf(', 도착 노드 게이트 1+tanh(Z_mod) 평균 %.3f',gateMean(S.dst(e)));
        end
        peers = find(S.dst==S.dst(e) & S.edgePool==S.edgePool(e));
        content{end+1} = sprintf(['[간선 %02d · 층 %d] %s %s [%s]: 어텐션 점수 e = %+.3f, 어텐션 계수 α = %.3f ' ...
            '(%s 풀, 도착 노드 입력 %d개 합 1), |W h_src| = %.3f, |α W h_src| = %.3f%s — %s'], ...
            e,l,S.edgeLabel{e},S.relationNames{S.rel(e)},pool,A.attentionScoreLayers(e,l), ...
            A.alphaLayers(e,l),pool,numel(peers),A.projectedMessageNormLayers(e,l), ...
            A.weightedMessageNormLayers(e,l),gateText,S.edgePurposeKo{e}); %#ok<AGROW>
    end
    nodeIds = compose("h%d:%d",l,(1:D.nNodes)');
    for n = find(arrayfun(@(id)closure(D.ids==id),nodeIds'))
        Hl = A.layerH{l};
        readoutText = '';
        if l == D.layers
            readoutText = sprintf(', 리드아웃 사전활성 항 크기 %.3f (액터 그래프 리드아웃에 참여)',A.readoutTermNorm(n));
        end
        content{end+1} = sprintf('[노드 임베딩 H^%d_%d] %s: |H| = %.3f%s',l,n,S.nodeNames{n}, ...
            norm(Hl(:,n)),readoutText); %#ok<AGROW>
    end
end
if closure(D.ids=="readout")
    content{end+1} = sprintf('[그래프 리드아웃] 액터 그래프 임베딩 g_A (16): |g_A| = %.3f, 7개 노드 임베딩 전체 사용',norm(A.g));
end
if closure(D.ids=="actor")
    content{end+1} = sprintf('[액터 MLP] μ (tanh 이전) = [%+.4f, %+.4f]',A.mu);
end
if closure(D.ids=="action")
    content{end+1} = sprintf('[가속도 명령] 요구 a_x = %+.3f, a_z = %+.3f m/s^2 (정규화 행동 [%+.3f, %+.3f])', ...
        r.command.requestedAcceleration,A.normalizedAction);
end
if any(D.kind(f)=="e")
    content{end+1} = ['[주의] 간선의 어텐션 점수는 출발·도착 노드 특징을 함께 읽고, 계수 α는 같은 연산군 풀의 ' ...
        '다른 입력 간선과 함께 정규화된다.'];
end
C = struct('focus',focus,'vertices',D.ids(closure),'mask',closure,'parents',D.ids(parents), ...
    'children',D.ids(children),'lines',{content(:)},'decisionIndex',k,'time',r.time);
end

function focus = expandFocus(focus,D)
out = strings(1,0);
for x = focus(:)'
    parts = split(x,":");
    switch parts(1)
        case "source", out(end+1) = "src:"+parts(2); %#ok<AGROW>
        case "channel", out(end+1) = compose("ch:%02d",str2double(parts(2))); %#ok<AGROW>
        case "node", n = str2double(parts(2)); out = [out,compose("x:%d",n), ...
                compose("h%d:%d",(1:D.layers)',n)']; %#ok<AGROW>
        case "edge", out = [out,compose("e%d:%02d",(1:D.layers)',str2double(parts(2)))']; %#ok<AGROW>
        otherwise, out(end+1) = x; %#ok<AGROW>
    end
end
focus = unique(out,'stable');
assert(~isempty(focus) || isempty(D.ids),'landing2d:TraceSelection','Empty selection.');
end

function m = reach(A,start)
m = false(1,size(A,1)); frontier = start;
while any(frontier)
    next = any(A(frontier,:),1) & ~m & ~start;
    m = m | next; frontier = next;
end
end

function label = vertexLabel(x,S,P,L)
parts = split(x,":");
switch parts(1)
    case "src", label = L.sources(strcmp({L.sources.id},parts(2))).label;
    case "ch", label = "o_t "+P.channelNames{str2double(parts(2))};
    case "x", label = "노드 특징 "+S.nodeNames{str2double(parts(2))};
    otherwise
        if startsWith(parts(1),"h")
            label = "노드 임베딩(층 "+extractAfter(parts(1),1)+") "+S.nodeNames{str2double(parts(2))};
        elseif startsWith(parts(1),"e")
            e = str2double(parts(2));
            label = "간선(층 "+extractAfter(parts(1),1)+") "+S.edgeLabel{e}+" ("+S.relationNames{S.rel(e)}+")";
        elseif parts(1)=="readout", label = "액터 그래프 리드아웃 g_A";
        elseif parts(1)=="actor", label = "액터 MLP";
        else, label = "가속도 명령 [a_x, a_z]";
        end
end
label = char(label);
end

function label = sourceLine(id,s,L)
label = L.sources(strcmp({L.sources.id},id)).label;
switch id
    case 'camera'
        if s.camera.frameCaptured
            label = sprintf('%s: 프레임 획득, 측정 시각 %.2f s',label,s.camera.stamp);
        else
            label = sprintf('%s: 영상 없음',label);
        end
    case 'marker'
        if ~s.camera.frameCaptured
            label = sprintf('%s: 프레임 없음 — 검출 없음',label);
        elseif s.camera.markerCount > 0
            label = sprintf('%s: %d개 검출 (ID %s)',label,s.camera.markerCount, ...
                strjoin(string(s.camera.markerIds),', '));
        else
            label = sprintf('%s: 0개 — 마커 미검출 (유효 측정 없음)',label);
        end
    case 'pnp'
        if s.pnp.attempted && s.pnp.valid
            label = sprintf('%s: 채택 (마커 %d개, 재투영 오차 %.2f px)',label,s.pnp.markerCount, ...
                s.pnp.reprojectionRms);
        elseif s.pnp.attempted
            label = sprintf('%s: 기각 (재투영 오차 %.2f px)',label,s.pnp.reprojectionRms);
        else
            label = sprintf('%s: 미수행 (검출 코너 없음)',label);
        end
    case 'kf'
        switch s.kf.update
            case 'measurement_update', u = '측정 갱신';
            case 'initialization', u = '초기화 (첫 측정)';
            case 'time_update', u = sprintf('시간 갱신 (예측, 마지막 측정 %.2f s)',s.kf.lastUpdateTime);
            otherwise, u = '초기화 전';
        end
        label = sprintf('%s: %s, 시각 %.2f s',label,u,s.time);
    otherwise
        label = sprintf('%s: 측정 시각 %.2f s, 유효 %d, v = [%+.2f, %+.2f] m/s',label, ...
            s.navigation.stamp,s.navigation.valid,s.navigation.velocityXZ);
end
end
