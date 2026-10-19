function files = exportTrace(decisionTrace,folder,baseName)
% EXPORTTRACE  Write a recorded decision trace (numbers and annotations kept apart).
%   files = landing2d.trace.exportTrace(trace,folder,baseName)
%   <base>.mat             variables trace (numeric record, event table,
%                          schema, provenance, identity) and annotations
%                          (rendered Korean explanations, separate)
%   <base>_events.csv      one row per real event (landing2d.trace.buildEvents)
%   <base>_decisions.csv   per decision: o_t, KF/PnP status, alpha of the 20
%                          edges, mu, requested / interval-applied command,
%                          reward (evaluation-only columns marked _evalOnly)
%   <base>_session.json    identity, schema, provenance, cadence and the
%                          explanation facts of every decision (read-only)
%   <base>_provenance.md   checkpoint / graph hashes, source commit, command,
%                          schema, provenance and cadence report
% Everything is read from TRACE; nothing is simulated or inferred again.
if ~isfolder(folder), mkdir(folder); end
annotations = arrayfun(@(k)landing2d.trace.explainDecision(decisionTrace,k),1:numel(decisionTrace.records));
base = fullfile(folder,baseName);
files = struct('mat',[base,'.mat'],'events',[base,'_events.csv'], ...
    'decisions',[base,'_decisions.csv'],'session',[base,'_session.json'], ...
    'provenance',[base,'_provenance.md']);
save(files.mat,'decisionTrace','annotations','-v7');
writetable(decisionTrace.events,files.events,'Encoding','UTF-8');
writetable(decisionTable(decisionTrace),files.decisions,'Encoding','UTF-8');
cadence = landing2d.trace.cadenceSummary(decisionTrace);
session = struct('schemaVersion',decisionTrace.schemaVersion,'identity',decisionTrace.identity, ...
    'schema',rmfield(decisionTrace.schema,'provenanceText'),'provenance',struct( ...
        'method',decisionTrace.provenance.method,'channelNames',{decisionTrace.provenance.channelNames}, ...
        'channelToNode',decisionTrace.provenance.channelToNode, ...
        'staticNames',{decisionTrace.provenance.staticNames},'staticToNode',decisionTrace.provenance.staticToNode, ...
        'processors',{decisionTrace.provenance.processors},'channelSource',decisionTrace.provenance.channelSource), ...
    'context',decisionTrace.context,'terminal',rmfield(decisionTrace.terminal,'sensing'), ...
    'cadence',table2struct(cadence),'decisions',numel(decisionTrace.records), ...
    'explanationFacts',[annotations.facts],'banners',{{annotations.banner}}, ...
    'labelsVersion',decisionTrace.labels.version);
writeText(files.session,jsonencode(session,'PrettyPrint',true));
writeText(files.provenance,provenanceReport(decisionTrace,cadence));
end

function T = decisionTable(decisionTrace)
R = decisionTrace.records; n = numel(R);
names = decisionTrace.context.observationNames;
T = table((1:n)',[R.time]','VariableNames',{'DecisionIndex','Time_s'});
O = [R.observation];
for i = 1:numel(names), T.(['o_',names{i}]) = O(i,:)'; end
s = [R.sensing]; cam = [s.camera]; pnp = [s.pnp]; kf = [s.kf];
T.FrameCaptured = [cam.frameCaptured]'; T.MarkerCount = [cam.markerCount]';
T.PnpAttempted = [pnp.attempted]'; T.PnpValid = [pnp.valid]';
T.KfUpdate = string({kf.update})'; T.KfLastUpdate_s = [kf.lastUpdateTime]';
actor = [R.actor]; alpha = [actor.alpha]';
for e = 1:decisionTrace.schema.nEdges
    T.(sprintf('alpha_%02d_%s',e,strrep(decisionTrace.schema.edgeLabel{e},'→','_'))) = alpha(:,e);
end
mu = [actor.mu]'; u = [actor.preTanhAction]'; a = [R.command]; req = [a.requestedAcceleration]';
app = [a.appliedAccelerationIntervalMean]';
T.mu_x = mu(:,1); T.mu_z = mu(:,2); T.u_x = u(:,1); T.u_z = u(:,2);
T.RequestedAx_mps2 = req(:,1); T.RequestedAz_mps2 = req(:,2);
T.AppliedAxIntervalMean_mps2 = app(:,1); T.AppliedAzIntervalMean_mps2 = app(:,2);
critic = [R.critic]; T.CriticValue = [critic.value]';
st = [R.step]; T.Reward = [st.reward]'; T.Terminated = [st.terminated]';
ev = [R.evaluation]; T.InjectedDropout_evalOnly = [ev.injectedDropout]';
T.AimError_evalOnly_m = [ev.aimError]';
end

function report = provenanceReport(decisionTrace,cadence)
id = decisionTrace.identity; S = decisionTrace.schema; P = decisionTrace.provenance;
content = {'# 결정 추적 출처 보고 (decision trace provenance)','', ...
    sprintf('- 생성: %s, schema `%s`, labels `%s`',id.recordedAt,decisionTrace.schemaVersion,decisionTrace.labels.version), ...
    sprintf('- 모델 상태: %s',identityField(id,'modelStatus')), ...
    sprintf('- 비교군: `%s`, 학습 시드 %s, 체크포인트 `%s`',identityField(id,'methodId'), ...
        num2str(identityField(id,'trainSeed')),identityField(id,'checkpointFile')), ...
    sprintf('- 체크포인트 SHA-256: `%s`',identityField(id,'checkpointHash')), ...
    sprintf('- 학습 서명 SHA-256: `%s` (algorithmVersion `%s`)',identityField(id,'signatureHash'), ...
        identityField(id,'algorithmVersion')), ...
    sprintf('- 그래프 해시: `%s` (%s, %s, %s, %s)',S.graphHash,S.variant,S.relationOperators, ...
        S.relationParameterSharing,S.attentionMode), ...
    sprintf('- 소스 커밋: `%s` (작업 트리 변경 %s)',identityField(id,'sourceCommit'),identityField(id,'sourceDirty')), ...
    sprintf('- 사례 `%s`, 에피소드 시드 %d, 결정론적 %d, 명령 `%s`',identityField(id,'scenarioId'), ...
        id.episodeSeed,id.deterministic,identityField(id,'command')), ...
    sprintf('- 결정 %d개, 종료 `%s` at %.2f s (truncated %d)',numel(decisionTrace.records), ...
        decisionTrace.terminal.reason,decisionTrace.terminal.time,decisionTrace.terminal.truncated),'', ...
    '## 그래프 (체크포인트 encoderSpec.T)','','| # | 간선 | 관계 유형 | 연산군 |','|---|---|---|---|'};
for e = 1:S.nEdges
    content{end+1} = sprintf('| %d | %s → %s | `%s` | %s |',e,S.nodeNames{S.src(e)}, ...
        S.nodeNames{S.dst(e)},S.relationNames{S.rel(e)},S.edgeOperator{e}); %#ok<AGROW>
end
content = [content,{'','## o_t → 노드 특징 파생 (섭동으로 확인, 메시지 전달 간선 아님)','', ...
    '| 노드 | o_t 성분 | 고정 상수 |','|---|---|---|'}];
for n = 1:S.nNodes
    content{end+1} = sprintf('| %s | %s | %s |',S.nodeNames{n}, ...
        strjoin(P.channelNames(P.channelToNode(:,n)),', '), ...
        strjoin(P.staticNames(P.staticToNode(:,n)),', ')); %#ok<AGROW>
end
content = [content,{'','## 관측 주기 (데이터 시각 기준)','', ...
    '| 사건 | 개수 | 서로 다른 시각 | 평균 간격 [s] | 관측 주기 [Hz] | 명목 주기 [s] |', ...
    '|---|---|---|---|---|---|'}];
for i = 1:height(cadence)
    content{end+1} = sprintf('| %s | %d | %d | %.4f | %.2f | %.2f |',cadence.Type(i), ...
        cadence.Count(i),cadence.DistinctStamps(i),cadence.MeanInterarrival_s(i), ...
        cadence.ObservedRate_Hz(i),cadence.NominalPeriod_s(i)); %#ok<AGROW>
end
content = [content,{'','어텐션 계수와 하이라이트 경로는 기술적 진단이며 인과적 중요도나 착륙 승인이 아니다.'}];
report = strjoin(content,newline);
end

function value = identityField(s,name)
value = '';
if isfield(s,name), value = s.(name); end
if islogical(value) || isnumeric(value), value = num2str(value); end
end

function writeText(file,report)
fid = fopen(file,'w','n','UTF-8');
assert(fid > 0,'landing2d:TraceExport','Cannot write %s.',file);
cleanup = onCleanup(@()fclose(fid));
fwrite(fid,unicode2native(report,'UTF-8'));
end
