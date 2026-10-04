function cfg = applyStateRepresentation(cfg,mode,options)
% APPLYSTATEREPRESENTATION  상태 표현만 바꾸고 나머지는 그대로 둡니다.
%
%   cfg = landing2d.graphstate.applyStateRepresentation(cfg,'ontology_rgat');
%
% 보상, 보상 계수, 행동 정의와 한계, 환경, 종료 조건, PPO 알고리즘과
% 하이퍼파라미터, 학습 반복 수, 시드는 전혀 건드리지 않습니다. 그래야 기준
% 모델과의 비교에서 실험 변수가 상태 표현 하나로 남습니다.
%
% 바뀌는 것은 두 가지뿐입니다.
%   cfg.graphState.stateRepresentation : 상태 표현 방식
%   cfg.rl.policyFile                  : 저장 파일 이름 (정책이 섞이지 않도록)
%
% options로 graphState의 다른 항목(hiddenDim, readout 등)을 함께 덮어쓸 수 있습니다.
if nargin < 3
    options = struct();
end
cfg.graphState.stateRepresentation = mode;
keys = fieldnames(options);
for i = 1:numel(keys)
    if ~isfield(cfg.graphState,keys{i})
        error('landing2d:UnknownOption', ...
            'Unknown graphState option: %s',keys{i});
    end
    cfg.graphState.(keys{i}) = options.(keys{i});
end
% node_pool에는 message passing이 없으므로 빈 가상 노드가 다른 노드의 정보를
% 모을 수 없습니다. readout 제거 실험을 명시하지 않은 경우 기존 meanmax를 씁니다.
if strcmp(mode,'node_pool') && strcmp(cfg.graphState.readout,'decision_nodes') ...
        && ~isfield(options,'readout')
    cfg.graphState.readout = 'meanmax';
end
if ismember(mode,{'context_node_pool','context_gat','context_rgat'}) ...
        && ~isfield(options,'readout')
    cfg.graphState.readout = 'raw_plus_groups';
end
if ismember(mode,{'gat','ontology_rgat'}) && ~isfield(options,'readout')
    cfg.graphState.readout = 'decision_nodes';
end
landing2d.graphstate.validateGraphStateConfig(cfg.graphState);
if strcmp(mode,'baseline')
    return;
end
if cfg.graphState.useScratchSettings
    % 옛 온톨로지 비교군과 같은 조건(모방 학습 없음, 탐색/학습량 확대).
    % 기본값은 false입니다. true로 두면 기준 모델과 학습 조건이 달라지므로
    % 상태 표현 외의 변수가 하나 더 생깁니다.
    cfg.rl = landing2d.rl.applyScratchSettings(cfg.rl);
end
if isfield(cfg,'experiment') && isfield(cfg.experiment,'enabled') ...
        && cfg.experiment.enabled ...
        && strcmp(cfg.experiment.schemaVersion,'planar_visibility_v2')
    % Canonical final-checkpoint names shared by run_all, run_finalTest,
    % run_paper, and the guarded R-GAT activation utility.
    cfg.rl.policyFile = sprintf('ppo_%s_planar_visibility_v2.mat',mode);
else
    [~,name,ext] = fileparts(cfg.graphState.policyFile);
    if isempty(ext), ext = '.mat'; end
    cfg.rl.policyFile = sprintf('%s_%s%s',name,mode,ext);
end
end
