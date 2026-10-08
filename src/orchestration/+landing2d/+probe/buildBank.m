function bank = buildBank(c,split,options)
% BUILDBANK  고정 probe 은행: 같은 도달 가능 상태와 같은 인과적 측정 이력을 모든 정책에 제공.
% 1) 분할(validation/test)의 manifest 시드마다 비교군과 무관한 인과적 구동기로 실제 평면
%    환경을 비행해 기준 궤적을 기록합니다(landing2d.probe.recordReference).
% 2) 관측오차 배율마다 같은 궤적에서 측정 단계부터 다시 계산합니다
%    (landing2d.probe.replaySensing: 마커 검출·융합 측위 -> PnP·KF -> o_t -> 결정 문맥).
%    명목 배율 1의 재생은 환경이 실제로 만든 관측과 비트 단위로 같아야 하며, 아니면
%    오류입니다(재생 경로 = 환경 인지 경로).
% 3) stride 간격의 결정 시점마다 probe를 만들고 정책 입력(12차원 벡터, 같은 o_t의 그래프
%    특징)과 문맥 플래그를 저장합니다. 그래프 노드 특징은 관계 배치와 무관하므로 두 RGAT
%    비교군이 같은 입력을 받습니다.
% 4) 기준 배율(0) 대비 관측 신뢰도(영상 보정·PnP 채택·검출 수·경과시간 등) 또는 안전
%    판단 경계(착륙 금지·복구 요청·최종 하강)가 달라진 probe를 동일 문맥과 구분합니다.
% 정책 입력(policyInput)과 평가 전용 참값(truth)·문맥(context)·외생 manifest를 나눠
% 저장합니다. 평가 정책 행동은 기준 궤적에 되먹이지 않습니다(landing2d.rl.probeActions).
% test 분할은 임계값·체크포인트·대표 사례 선택에 쓰지 않습니다.
% OPTIONS: count, seeds, scales, stride, driverNoise, verbose.
if nargin < 3, options = struct(); end
assert(isfield(c.experiment,'commonObservation') && ~landing2d.environment.isSpatial(c), ...
    'landing2d:ProbePlanarOnly','Fixed probes require the planar common observation.');
cc = c.consistency;
split = char(split);
switch split
    case 'validation'
        pool = c.experiment.manifest.validationSeeds; count = cc.probe.validationEpisodeCount;
    case 'test'
        pool = c.experiment.manifest.testSeeds; count = cc.probe.testEpisodeCount;
    otherwise
        error('landing2d:ProbeSplit','Fixed probes use the validation or test split, not %s.',split);
end
defaults = struct('count',count,'seeds',[],'scales',cc.noiseScales, ...
    'stride',cc.probe.stride,'driverNoise',cc.probe.driverNoise,'verbose',false);
names = fieldnames(options);
for i = 1:numel(names)
    assert(isfield(defaults,names{i}),'landing2d:ProbeOption','Unknown option %s.',names{i});
    defaults.(names{i}) = options.(names{i});
end
options = defaults;
seeds = options.seeds;
if isempty(seeds), seeds = pool(1:options.count); end
assert(all(ismember(seeds,pool)),'landing2d:ProbeSplit', ...
    'Probe seeds must come from the %s split.',split);
scales = options.scales;
reference = find(scales == cc.referenceScale,1);
nominal = find(scales == cc.nominalScale,1);
assert(~isempty(reference) && ~isempty(nominal),'landing2d:ProbeScales', ...
    'Probe scales must contain the reference (%g) and nominal (%g) scales.', ...
    cc.referenceScale,cc.nominalScale);
graphConfig = landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
graphSchema = landing2d.graphstate.contextSchema('context_rgat',2,'commonObservation');
[~,configHash] = landing2d.util.resolvedConfig(c);
nS = numel(scales);
vectorCells = cell(numel(seeds),1); graphCells = cell(numel(seeds),1);
probeCells = cell(numel(seeds),1); contextCells = cell(numel(seeds),1);
truthCells = cell(numel(seeds),1);
episodes = struct('seed',num2cell(seeds(:)'),'manifestHash','','decisions',0, ...
    'terminalReason','','probeDecisions',[]);
for e = 1:numel(seeds)
    record = landing2d.probe.recordReference(c,seeds(e),struct('driverNoise',options.driverNoise));
    n = record.decisions;
    columns = 1:options.stride:n;        % decisions k = 0..n-1 where a policy acts
    P = numel(columns);
    G = [];
    V = zeros(size(record.observation,1),P,nS);
    S = zeros(graphSchema.inDim*graphSchema.nNodes,P,nS);
    flagCells = cell(1,nS);
    positionError = NaN(2,P,nS); velocityError = NaN(2,P,nS);
    for s = 1:nS
        rep = landing2d.probe.replaySensing(record,c,scales(s));
        if s == nominal
            assert(isequal(rep.observation,record.observation) ...
                && isequal(rep.flags.landingInhibited,record.landingInhibited) ...
                && isequal(rep.flags.abortRequested,record.abortRequested) ...
                && isequal(rep.flags.finalDescentActive,record.finalDescentActive), ...
                'landing2d:ProbeReplay', ...
                'Nominal sensing replay differs from the environment (seed %d).',seeds(e));
        end
        G = rep.context;
        V(:,:,s) = rep.observation(:,columns);
        for p = 1:P
            S(:,p,s) = landing2d.graphstate.observationGraph(rep.O{columns(p)},G,graphConfig);
        end
        flagCells{s} = selectFlags(rep.flags,columns);
        positionError(:,:,s) = rep.perceptionError.position(:,columns);
        velocityError(:,:,s) = rep.perceptionError.velocity(:,columns);
    end
    vectorCells{e} = V; graphCells{e} = S;
    probeCells{e} = struct('episode',e*ones(1,P),'seed',seeds(e)*ones(1,P), ...
        'decision',columns-1,'time',record.time(columns));
    contextCells{e} = compareContexts(flagCells,reference);
    truthCells{e} = struct('drone',record.state(:,columns),'pad',record.pad(:,columns), ...
        'perceptionPositionError',positionError,'perceptionVelocityError',velocityError, ...
        'driverAcceleration',landing2d.environment.actionLimits(c).*record.driverAction(:,columns), ...
        'driverMeanAcceleration',landing2d.environment.actionLimits(c).*record.driverMeanAction(:,columns));
    episodes(e).manifestHash = record.manifest.hash;
    episodes(e).decisions = n;
    episodes(e).terminalReason = record.terminalReason;
    episodes(e).probeDecisions = columns-1;
    if options.verbose
        fprintf('  probe bank %s seed %d: %d decisions, %d probes, %s\n',split, ...
            seeds(e),n,P,record.terminalReason);
    end
end
schema = c.experiment.observationSchema;
meta = struct('split',split,'seeds',seeds(:)','scales',scales(:)', ...
    'referenceScale',cc.referenceScale,'nominalScale',cc.nominalScale, ...
    'stride',options.stride,'driver',cc.probe.driver,'driverNoise',options.driverNoise, ...
    'observationNames',{schema.names},'observationVersion',schema.version, ...
    'graphVariant',graphSchema.variant,'graphNodeNames',{graphSchema.nodeNames}, ...
    'graphFeatureNames',{graphSchema.featureNames},'graphInDim',graphSchema.inDim, ...
    'actionLimits',landing2d.environment.actionLimits(c)', ...
    'configHash',configHash,'taskFingerprint',landing2d.environment.taskFingerprint(c), ...
    'created',char(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ss')), ...
    'matlabVersion',version);
bank = struct('schemaVersion','fixed_probe_bank_v1','meta',meta,'episodes',episodes, ...
    'probe',catStruct(probeCells,2), ...
    'policyInput',struct('vector',cat(2,vectorCells{:}),'graph',cat(2,graphCells{:})), ...
    'context',catStruct(contextCells,1), ...
    'truth',catStruct(truthCells,2));
bank.meta.probeCount = numel(bank.probe.time);
end

function f = selectFlags(flags,columns)
names = fieldnames(flags);
for i = 1:numel(names), f.(names{i}) = flags.(names{i})(columns); end
end

function context = compareContexts(flagCells,reference)
% Per probe x scale: flags (probe rows), and whether the observation
% confidence or the safety decision boundary differs from the reference scale.
nS = numel(flagCells);
names = fieldnames(flagCells{1});
for i = 1:numel(names)
    context.(names{i}) = cell2mat(cellfun(@(f)f.(names{i})(:),flagCells,'UniformOutput',false));
end
confidence = {'visionUpdated','estimateInitialized','poseValid','detectedCount', ...
    'navigationValid','historyValid'};
safety = {'landingInhibited','abortRequested','finalDescentActive'};
P = size(context.visionUpdated,1);
sameConfidence = true(P,nS); sameSafety = true(P,nS);
for i = 1:numel(confidence)
    v = context.(confidence{i});
    sameConfidence = sameConfidence & v == v(:,reference);
end
age = context.visionAge; ageRef = age(:,reference);
sameAge = (isinf(age) & isinf(ageRef)) | abs(age-ageRef) <= 1e-9;
sameConfidence = sameConfidence & sameAge;
for i = 1:numel(safety)
    v = context.(safety{i});
    sameSafety = sameSafety & v == v(:,reference);
end
context.sameConfidence = sameConfidence;
context.sameSafety = sameSafety;
context.sameContext = sameConfidence & sameSafety;
end

function out = catStruct(cells,dim)
% Concatenate same-shaped structs field by field along DIM (probe axis).
names = fieldnames(cells{1});
for i = 1:numel(names)
    values = cellfun(@(s)s.(names{i}),cells,'UniformOutput',false);
    out.(names{i}) = cat(dim,values{:});
end
end
