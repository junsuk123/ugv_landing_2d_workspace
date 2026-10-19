function X = explainDecision(decisionTrace,k)
% EXPLAINDECISION  Korean situation explanation of decision K of a trace.
%   X = landing2d.trace.explainDecision(trace,k)
% A deterministic, auditable text built only from the recorded observation,
% estimates, node features, public thresholds, relation metadata, R-GAT
% numbers and the action of that decision. It is a rule-based diagnostic
% explanation, not OWL/SWRL inference, not an R-GAT output, not a causal
% attribution and not a landing approval. Missing values are printed as
% 알 수 없음 (UNKNOWN), never invented. Qualifiers keep the evidence classes
% apart: [관측] observed, [추정] estimated, [예측] predicted from estimates,
% [착륙 조건] current-state ratios, [R-GAT 계산] numeric facts of the forward
% pass, [해석] interpretation, [주의] caution.
%   X.banner    one-paragraph summary (dashboard banner)
%   X.sections  8 x 1 cell of {title, lines} (full evidence chain view)
%   X.facts     the numbers used (JSON export)
r = decisionTrace.records(k); s = r.sensing; S = decisionTrace.schema; L = decisionTrace.labels;
ctx = decisionTrace.context; est = r.graph.estimate; ev = r.graph.semanticEvidence;
A = r.actor; q = L.qualifiers;
t = r.time;
% 1. observation sources ----------------------------------------------------
sec1 = {};
if s.camera.frameCaptured
    sec1{end+1} = sprintf('%s 마커 카메라 프레임 획득, 측정 시각 %.2f s (결정 시각과 같은 시뮬레이션 시각).', ...
        q.observed,s.camera.stamp);
    if s.camera.markerCount > 0
        sec1{end+1} = sprintf('%s ArUco 마커 %d개 검출 (ID %s).',q.observed, ...
            s.camera.markerCount,strjoin(string(s.camera.markerIds),', '));
    else
        sec1{end+1} = sprintf('%s 프레임은 있으나 등록 ArUco 마커가 검출되지 않음 (0개).',q.observed);
    end
else
    sec1{end+1} = sprintf('%s 이 시각에 사용할 카메라 영상 없음.',q.observed);
end
if r.evaluation.injectedDropout
    sec1{end+1} = sprintf(['%s 이 시각은 평가 설정의 외부 주입 마커 누락 구간 ' ...
        '(정책은 이 일정을 받지 않음).'],q.evaluationOnly);
end
nav = s.navigation;
if nav.valid
    sec1{end+1} = sprintf('%s UAV 자체 항법 추정: 측정 시각 %.2f s, 유효, 항법 경과 %.2f s.', ...
        q.observed,nav.stamp,est.navigationAge);
else
    sec1{end+1} = sprintf('%s UAV 자체 항법 추정 무효.',q.observed);
end
sec1{end+1} = sprintf('%s 마지막 영상 측정 갱신 후 경과: %s.',q.observed, ...
    secondsText(est.visionAge));
% 2. state estimation -------------------------------------------------------
sec2 = {};
if s.pnp.attempted && s.pnp.valid
    sec2{end+1} = sprintf('%s PnP 포즈 채택: 마커 %d개, 재투영 오차 %.2f px.', ...
        q.estimated,s.pnp.markerCount,s.pnp.reprojectionRms);
elseif s.pnp.attempted
    sec2{end+1} = sprintf('%s PnP 포즈 기각 (재투영 오차 %s px, 채택 상한 초과 또는 퇴화).', ...
        q.estimated,numberText(s.pnp.reprojectionRms,'%.2f'));
else
    sec2{end+1} = sprintf('%s PnP 미수행 (검출 코너 없음) — 유효 PnP 측정 없음.',q.estimated);
end
switch s.kf.update
    case 'measurement_update'
        sec2{end+1} = sprintf('%s UGV 칼만 필터 측정 갱신 (채택된 PnP 측정 반영).',q.estimated);
    case 'initialization'
        sec2{end+1} = sprintf('%s UGV 칼만 필터 초기화 (첫 유효 측정, 속도 초기값 = UAV 항법 속도).',q.estimated);
    case 'time_update'
        sec2{end+1} = sprintf(['%s UGV 칼만 필터 시간 갱신 (예측, Δt %.2f s) — 아래 UGV 값은 새 직접 ' ...
            '측정이 아니라 마지막 측정 갱신(%.2f s) 이후 등속 모델 예측값.'],q.estimated, ...
            s.kf.predictionDt,s.kf.lastUpdateTime);
    otherwise
        sec2{end+1} = sprintf(['%s UGV 칼만 필터 초기화 전 — UGV 추정 없음. 상대 상태 입력은 ' ...
            '정규화 입력 0으로 채워지며 0 측정이 아님.'],q.estimated);
end
sec2{end+1} = sprintf('%s UGV 속도 %s, 상대 위치 e_x %s, 고도 h %s, 상대 속도 v_r %s.', ...
    q.estimated,unitText(est.ugvVx,'m/s'),unitText(est.relativeX,'m'), ...
    unitText(est.height,'m'),unitText(est.relativeVx,'m/s'));
sec2{end+1} = sprintf('%s UAV 수직 속도 %s, 피치 %s, 피치 각속도 %s (UAV 자체 항법 추정).', ...
    q.estimated,unitText(est.droneVz,'m/s'),unitText(rad2deg(est.theta),'deg'), ...
    unitText(rad2deg(est.pitchRate),'deg/s'));
% 3. explicit features --------------------------------------------------------
Xt = r.graph.X; sec3 = {};
for n = 1:5
    sec3{end+1} = sprintf('%s %s (%s): %s',q.computed,S.nodeNames{n}, ...
        L.perspectives.Explicit,featureText(L.nodes(n).features,Xt(:,n))); %#ok<AGROW>
end
sec3{end+1} = ['[해석 주의] normalizedCrossTrack은 정규화 좌표에서 계산한 값이며 미터 단위 ' ...
    '카메라 광축 aim error가 아니고 광축 위에서 0이 보장되지 않음.'];
% 4. implicit features --------------------------------------------------------
sec4 = {};
sec4{end+1} = sprintf(['%s ViewMargin (%s): 시야 여유 %.3f, 정규화 방위 %.3f (β = %.1f deg, ' ...
    'FOV/2 = %.1f deg). 추정값 기반 예측이며 실제 검출 보장이 아님.'],q.predicted, ...
    L.perspectives.Implicit,ev.fovMargin,Xt(2,6),rad2deg(ev.bearing),rad2deg(ctx.fov/2));
if s.camera.markerCount > 0
    sec4{end+1} = sprintf('%s 같은 시각 실제 마커 검출: 있음 (예측 시야 여유와 별개의 관측).',q.observed);
else
    sec4{end+1} = sprintf('%s 같은 시각 실제 마커 검출: 없음 (예측 시야 여유와 별개의 관측).',q.observed);
end
[conditionLines,exceeded] = landingLines(ev,est,ctx,L);
sec4 = [sec4,conditionLines];
% 5. declared relations -------------------------------------------------------
sec5 = {};
for rel = 1:numel(S.relationNames)-1
    edges = find(S.rel==rel);
    names = strjoin(S.edgeLabel(edges),', ');
    sec5{end+1} = sprintf('%s %s [%s]: %s — %s',q.relation,L.relations(rel).label, ...
        operatorText(S.relationOperatorNames{rel}),names,L.relations(rel).meaning); %#ok<AGROW>
end
sec5{end+1} = sprintf(['%s 자기 루프 7개 [전파]. 관계 구조는 고정이며 매 시점 바뀌는 것은 노드 특징뿐. ' ...
    '선언된 관계는 상태 표현의 구조적 사전지식이지 논리 추론(OWL/SWRL)이 아님.'],q.relation);
% 6. learned graph operation --------------------------------------------------
sec6 = {sprintf(['%s 단일 R-GAT 층 (%s, %s): 각 도착 노드는 직접 들어오는 1-홉 간선의 메시지만 ' ...
    '모은 뒤 7개 노드 임베딩 전체가 그래프 리드아웃으로 들어감.'],q.computed, ...
    S.relationOperators,S.attentionMode)};
gateMean = mean(A.gate,1);
for j = 1:S.nNodes
    incoming = find(S.dst==j);
    parts = strings(1,numel(incoming));
    for m = 1:numel(incoming)
        e = incoming(m);
        parts(m) = sprintf('%s %s α=%.3f |αWx|=%.3f',S.edgeLabel{e}, ...
            ternary(S.edgePool(e)==2,'조절','전파'),A.alpha(e),A.weightedMessageNorm(e));
    end
    sec6{end+1} = sprintf('%s → %s: %s; 게이트 1+tanh(Z_mod) 평균 %.3f [%.3f, %.3f]; |H| = %.3f', ...
        q.computed,S.nodeNames{j},strjoin(parts,'; '),gateMean(j),min(A.gate(:,j)), ...
        max(A.gate(:,j)),norm(A.H(:,j))); %#ok<AGROW>
end
sec6{end+1} = sprintf(['%s 액터 그래프 임베딩 g_A (16차원) |g_A| = %.3f; 노드별 리드아웃 사전활성 항 크기 ' ...
    '%s (행동 기여도 아님).'],q.computed,norm(A.g),mat2str(round(A.readoutTermNorm,3)));
sec6{end+1} = ['[해석 주의] 어텐션 계수 α는 연산군 풀(전파+자기 루프 / 조절) 안에서 도착 노드 기준 ' ...
    '합이 1인 집계 가중치이며 인과적 중요도·신뢰 확률이 아님. 조절 게이트는 α가 아님.'];
% 7. action -------------------------------------------------------------------
a = r.command.requestedAcceleration;
sec7 = {sprintf('%s 액터 평균 μ (tanh 이전) = [%+.4f, %+.4f].',q.action,A.mu)};
if A.sampled
    sec7{end+1} = sprintf(['%s 확률적 표본 u = [%+.4f, %+.4f] → 요구 가속도에 사용; ' ...
        '평균 기반 미리보기 limits·tanh(μ) = [%+.3f, %+.3f] m/s^2 (사용 안 함).'],q.action, ...
        A.preTanhAction,ctx.actionLimits(:).*A.deterministicPreview);
else
    sec7{end+1} = sprintf('%s 결정론적 평가: 표본 = 평균 μ.',q.action);
end
sec7{end+1} = sprintf('%s 정규화 행동 tanh(u) = [%+.4f, %+.4f], 요구 가속도 a_x = %+.3f, a_z = %+.3f m/s^2 (한계 %.1f / %.1f).', ...
    q.action,A.normalizedAction,a,ctx.actionLimits);
sec7{end+1} = sprintf(['%s 결정 구간 평균 적용 명령 [%+.3f, %+.3f] m/s^2 (direct_policy_v1: 감독기 ' ...
    '없음, 요구값 그대로).'],q.action,r.command.appliedAccelerationIntervalMean);
sec7{end+1} = sprintf('%s 결정 구간 평균 실제 기체 가속도 [%+.3f, %+.3f] m/s^2 (지연 동역학 참값, 정책 입력 아님).', ...
    q.evaluationOnly,r.evaluation.realizedAccelerationMean);
% 8. situation summary --------------------------------------------------------
sec8 = {};
if s.camera.frameCaptured && s.camera.markerCount > 0 && s.pnp.valid
    sec8{end+1} = sprintf('%s 마커가 검출되어 %s PnP 측정으로 UGV 칼만 필터가 측정 갱신됨.', ...
        q.observed,q.estimated);
elseif s.camera.frameCaptured
    sec8{end+1} = sprintf(['%s 프레임은 있으나 유효 마커 측정이 없어 %s UGV 상태는 마지막 측정 ' ...
        '갱신 후 %s 동안의 예측값 (새 직접 측정 아님).'],q.observed,q.estimated, ...
        secondsText(est.visionAge));
end
if ev.fovMargin > 0
    sec8{end+1} = sprintf('%s 추정 상대 위치·자세로 보면 패드는 시야 안 (여유 %.2f).',q.predicted,ev.fovMargin);
else
    sec8{end+1} = sprintf('%s 추정 상대 위치·자세로 보면 패드는 시야 밖 (여유 %.2f).',q.predicted,ev.fovMargin);
end
if isempty(exceeded)
    sec8{end+1} = sprintf('%s 다섯 접지 한계비가 모두 한계 이내 (현재 추정 상태 기준; 착륙 승인 아님).',q.condition);
else
    sec8{end+1} = sprintf('%s 한계 초과 요소: %s (현재 추정 상태 기준; 접촉 예측 아님).', ...
        q.condition,strjoin(exceeded,', '));
end
sec8{end+1} = sprintf('%s 액터 요구 가속도 a_x = %+.2f, a_z = %+.2f m/s^2.',q.action,a);
if isfinite(est.visionAge) && est.visionAge >= 0.5
    sec8{end+1} = sprintf('%s 영상 측정 갱신 없이 %.2f s 경과 — 예측 기반 UGV 추적, 실제 UGV 가속은 관측되지 않았을 수 있음.', ...
        q.caution,est.visionAge);
end
if ~est.estimateInitialized
    sec8{end+1} = sprintf('%s UGV 추정이 아직 없음.',q.caution);
end
sec8{end+1} = sprintf(['%s 규칙 기반 진단 설명이며 R-GAT가 원인을 증명하거나 착륙을 승인한 것이 아님. ' ...
    'LandingCondition은 현재 상태 수치일 뿐 액터에 내려진 기호적 결정이 아님.'],q.caution);
sections = {'1. 관측 원천 사실',sec1; '2. 상태 추정 사실',sec2; ...
    '3. 명시적 TOSM 특징 (Explicit)',sec3; '4. 암묵적 TOSM 특징 (Implicit)',sec4; ...
    '5. 선언된 의미 관계',sec5; '6. 실제 학습된 그래프 연산 (수치)',sec6; ...
    '7. 정책 행동',sec7; '8. 상황 요약 (한정어 포함)',sec8};
markerText = '마커 미검출';
if s.camera.markerCount > 0, markerText = sprintf('마커 %d개 검출',s.camera.markerCount); end
if ~s.camera.frameCaptured, markerText = '영상 없음'; end
banner = sprintf(['[t = %.2f s, 결정 #%d] %s %s, 최근 유효 마커 갱신 후 %s. %s UGV 속도 %s, ' ...
    '상대 위치 %s, 상대 속도 %s (%s). %s 시야 여유 %.2f (추정값 기반, 검출 보장 아님). ' ...
    '%s 한계비 r/(1+r) = %s (0.5 = 한계값). %s a_x = %+.2f, a_z = %+.2f m/s^2. ' ...
    '%s 진단 설명이며 인과 증명·착륙 승인이 아님.'], ...
    t,k,q.observed,markerText,secondsText(est.visionAge),q.estimated, ...
    unitText(est.ugvVx,'m/s'),unitText(est.relativeX,'m'),unitText(est.relativeVx,'m/s'), ...
    kfText(s.kf.update),q.predicted,ev.fovMargin,q.condition, ...
    mat2str(round(ev.landingCondition,2)),q.action,a,q.caution);
facts = struct('time',t,'decisionIndex',k,'frameCaptured',s.camera.frameCaptured, ...
    'markerIds',s.camera.markerIds,'pnpAttempted',s.pnp.attempted,'pnpValid',s.pnp.valid, ...
    'kfUpdate',s.kf.update,'visionAge',est.visionAge,'navigationStamp',nav.stamp, ...
    'estimate',est,'fovMargin',ev.fovMargin,'touchdownLimitRatio',ev.touchdownLimitRatio, ...
    'landingCondition',ev.landingCondition,'alpha',A.alpha','gateMean',gateMean, ...
    'mu',A.mu','requestedAcceleration',a','injectedDropout_evalOnly',r.evaluation.injectedDropout);
X = struct('banner',banner,'sections',{sections},'facts',facts);
end

function [content,exceeded] = landingLines(ev,est,ctx,L)
td = ctx.touchdown;
raw = [abs(est.relativeX),abs(est.relativeVx),abs(est.droneVz),abs(rad2deg(est.theta)), ...
    abs(rad2deg(est.pitchRate))];
limitValue = [td.position,td.speedX,td.speedZ,rad2deg(td.pitch),rad2deg(td.pitchRate)];
units = {'m','m/s','m/s','deg','deg/s'};
content = {sprintf(['[착륙 조건] LandingCondition (Implicit): 현재 추정 상태의 접지 한계비 r = |값|/한계, ' ...
    '특징 r/(1+r) (0.5 = 한계값, 1에 가까울수록 초과). 착륙 승인·안전 보장·미래 접촉 예측·PPO 행동이 아님.'])};
exceeded = {};
if ~est.estimateInitialized
    content{end+1} = ['  UGV 추정 없음: 위치·상대 속도 비율은 0으로 채운 정규화 입력에서 계산된 값이며 ' ...
        '실제 0 오차가 아님.'];
end
for i = 1:5
    content{end+1} = sprintf('  %s: |값| %s / 한계 %.2f %s → r = %.2f, r/(1+r) = %.3f%s', ...
        L.landingCondition{i},numberText(raw(i),'%.3f'),limitValue(i),units{i}, ...
        ev.touchdownLimitRatio(i),ev.landingCondition(i), ...
        ternary(ev.touchdownLimitRatio(i)>1,' (한계 초과)','')); %#ok<AGROW>
    if ev.touchdownLimitRatio(i) > 1, exceeded{end+1} = L.landingCondition{i}; end %#ok<AGROW>
end
end

function label = featureText(names,featureValues)
parts = strings(1,numel(names));
for i = 1:numel(names)
    name = strtok(names{i},' ');
    parts(i) = sprintf('%s = %+.3f',name,featureValues(i));
end
label = strjoin(parts,', ');
end

function label = operatorText(op)
if strcmp(op,'modulate'), label = '조절, 곱셈 게이트'; else, label = '전파, 덧셈 메시지'; end
end

function label = kfText(update)
switch update
    case 'measurement_update', label = 'KF 측정 갱신';
    case 'initialization', label = 'KF 초기화';
    case 'time_update', label = 'KF 시간 갱신 예측값';
    otherwise, label = 'KF 초기화 전';
end
end

function label = secondsText(x)
if ~isfinite(x), label = '알 수 없음 (갱신 이력 없음)'; else, label = sprintf('%.2f s',x); end
end

function label = unitText(x,unit)
if ~isfinite(x), label = '알 수 없음 (UNKNOWN)'; else, label = sprintf('%+.2f %s',x,unit); end
end

function label = numberText(x,format)
if ~isfinite(x), label = '알 수 없음'; else, label = sprintf(format,x); end
end

function out = ternary(condition,a,b)
if condition, out = a; else, out = b; end
end
