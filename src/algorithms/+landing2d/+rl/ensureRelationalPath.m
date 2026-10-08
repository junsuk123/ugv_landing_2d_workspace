function [agent,info] = ensureRelationalPath(agent,c,options)
% ENSURERELATIONALPATH  Activate R-GAT residuals without degrading the
% selected flat-equivalent checkpoint on the fixed validation split.
if nargin < 3, options=struct(); end
% trainer: 관계 전용 PPO를 돌릴 학습 함수. 비우면 landing2d.rl.ppoTrain입니다.
defaults=struct('iterations',25,'episodesPerIteration',6,'ppoEpochs',4, ...
    'trainingValidationEpisodes',20,'seedOffset',8100000, ...
    'guardOptions',struct(),'trainer',[]);
options=parseOptions(options,defaults);
[alreadyActive,beforeAudit]=landing2d.rl.relationalPathActive(agent);
required=beforeAudit.required;
info=struct('required',required,'attempted',false,'changed',false, ...
    'accepted',alreadyActive,'alreadyActive',alreadyActive, ...
    'beforeAudit',beforeAudit,'afterAudit',beforeAudit, ...
    'trainingHistory',[],'guard',struct());
if ~required || alreadyActive, return; end

info.attempted=true;
anchor=agent;
originalRl=agent.rl;
repairRl=originalRl;
repairRl.ppoIterations=options.iterations;
repairRl.episodesPerIteration=options.episodesPerIteration;
repairRl.ppoEpochs=options.ppoEpochs;
repairRl.evaluateEvery=options.iterations;
repairRl.valueWarmup=0;
repairRl.earlyStopPatience=0;
repairRl.curriculumMode='scheduled';
repairRl.curriculumFraction=0;
repairRl.abortCurriculumFraction=0;
repairRl.motionCurriculumFraction=0;
repairRl.curriculumEasyReplayFraction=0;
repairRl.curriculumBridgeReplayFraction=0;
repairRl.verbose=logical(originalRl.verbose);
repairAgent=anchor;
repairAgent.rl=repairRl;
repairCfg=c;
repairCfg.rl=repairRl;
repairCfg.graphState.graphAdaptationWarmupFraction=0;
repairCfg.graphState.preserveRawPolicyDuringGraphAdaptation=true;
repairCfg.showLiveDashboard=false;
repairCfg.figureVisible=false;
repairCfg.experiment.validationEpisodeCount=min( ...
    options.trainingValidationEpisodes, ...
    numel(repairCfg.experiment.manifest.validationSeeds));
rs=RandStream('threefry','Seed',originalRl.seed+options.seedOffset);
if originalRl.verbose
    fprintf(['R-GAT 관계 경로 복구: raw 정책 고정, 관계 전용 PPO %d반복, ' ...
        '검증 성능 가드 적용\n'],options.iterations);
end
trainer=options.trainer;
if isempty(trainer), trainer=@landing2d.rl.ppoTrain; end
[~,history,candidate]=trainer(repairAgent,repairCfg,rs);
candidate.rl=originalRl;
assertRawPolicyPreserved(anchor,candidate);
[selected,guard]=landing2d.rl.guardRelationalCandidate( ...
    anchor,candidate,c,options.guardOptions);
selected.rl=originalRl;
agent=selected;
[afterActive,afterAudit]=landing2d.rl.relationalPathActive(agent);
info.changed=guard.accepted;
info.accepted=guard.accepted && afterActive;
info.afterAudit=afterAudit;
info.trainingHistory=history;
info.guard=guard;
if originalRl.verbose
    if info.accepted
        fprintf(['  관계 경로 활성화 승인: scale %.4g | Wg %.4g / %.4g | ' ...
            'residual norm %.4g\n'],guard.selectedScale, ...
            afterAudit.policyReadoutNorm,afterAudit.valueReadoutNorm, ...
            norm(guard.selectedInfo.meanAbsRelationResidual));
    else
        fprintf('  관계 경로 활성화 보류: 검증 성능 가드 미통과\n');
    end
end
end

function assertRawPolicyPreserved(anchor,candidate)
assert(isequal(anchor.policy.mean,candidate.policy.mean) ...
    && isequal(anchor.policy.logStd,candidate.policy.logStd) ...
    && isequal(anchor.value.net,candidate.value.net) ...
    && isequal(inputNormOf(anchor),inputNormOf(candidate)), ...
    'landing2d:RawPolicyChanged', ...
    'Relation-only adaptation changed the protected raw policy/value path.');
end

function n=inputNormOf(agent)
n=[];
if isfield(agent,'inputNorm'), n=agent.inputNorm; end
end

function options=parseOptions(options,defaults)
assert(isstruct(options) && isscalar(options), ...
    'landing2d:InvalidOptions','options must be a scalar struct.');
unknown=setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption', ...
    'Unknown relation activation option: %s',strjoin(unknown,', '));
names=fieldnames(defaults);
for i=1:numel(names)
    if ~isfield(options,names{i}), options.(names{i})=defaults.(names{i}); end
end
for name={'iterations','episodesPerIteration','ppoEpochs', ...
        'trainingValidationEpisodes','seedOffset'}
    validateattributes(options.(name{1}),{'numeric'}, ...
        {'scalar','real','finite','positive','integer'},mfilename,name{1});
end
assert(isstruct(options.guardOptions) && isscalar(options.guardOptions), ...
    'landing2d:InvalidGuardOptions','guardOptions must be a scalar struct.');
assert(isempty(options.trainer) || isa(options.trainer,'function_handle'), ...
    'landing2d:InvalidTrainer','trainer must be a function handle.');
end
