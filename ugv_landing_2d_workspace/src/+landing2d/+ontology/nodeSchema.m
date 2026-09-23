function schema = nodeSchema(variant)
% NODESCHEMA  축소형 2차원 착륙 시나리오용 최소 온톨로지 스키마 (9노드).
%
% 원 저장소(OntoReward-RL)의 13노드 스키마는 바람, 자세, 배터리, 마커/GNSS를
% 전제로 합니다. 이 프로젝트의 축소 모형에는 그 물리량이 없으므로, 같은 설계
% 원칙(도메인 의미를 가진 고정 노드 + 관계형 간선)을 유지하면서 다시 구성했습니다.
%
% 11노드에서 시작해 노드별 반사실 기여도를 측정하며 줄였습니다.
% 제거한 것은 Alignment와 TrackingStability로, 둘 다 PositionError의 단조 변환이라
% 같은 정보를 두 번 넣는 셈이었습니다(기여도 0.013, 0.0003).
% 두 값은 TouchdownSafety를 만드는 내부 항으로는 그대로 남아 있습니다.
% 근거와 측정표는 docs/ONTOLOGY_RGAT_KO.md에 있습니다.
%
% PadMotion은 이 시나리오의 핵심 원인 노드입니다. UGV가 속도를 바꾸면 패드가
% 시야 밖으로 밀려나므로 FovMargin으로 가는 간선을 갖습니다. 이 연결이 있어야
% "패드 이동 -> 포착 실패"라는 인과가 온톨로지에 표현되고, 포착 항의 반사실
% 중요도에 반영됩니다.
%
% variant
%   'core'   (기본) 상태만으로 이루어진 9노드. 가중치 비율을 추론할 때 씁니다.
%   'design' 여기에 보상 가중치 노드 2개와 강화학습 가치 노드 1개를 더한 12노드.
%            가중치를 바꿔가며 모은 자료에서 "그 가중치가 착륙에 도움이 되는가"를
%            직접 계산하기 위한 그래프입니다.
if nargin < 1 || isempty(variant)
    variant = 'core';
end
schema.nodeNames = {'PositionError','DescentSpeed','PadMotion','FovMargin', ...
    'SearchDuration','PadVisibility','RelativeDistance','TouchdownSafety','SafeLanding'};
schema.nNodes = numel(schema.nodeNames);
schema.goalNode = 9;

% 값이 클수록 나쁜 노드. 나머지는 값이 클수록 좋은 노드입니다.
schema.riskNodes = [1,2,3,4,5,7];

% 반사실 분석에서 각 노드를 "무해한 값"으로 바꿀 때 쓰는 기준값.
schema.neutralValue = ones(1,schema.nNodes);
schema.neutralValue(schema.riskNodes) = 0;

% 관계 1=degrades, 2=supports, 3=contributes, 4=self  (원 저장소와 동일)
schema.relationNames = {'degrades','supports','contributes','self'};
%      위험 -> 착륙 안전도        패드 이동/탐색 -> 시야   가시성 -> 안전도/목표
src = [1 2 3 4 7    3 4 5      6  7 5 6 8];
dst = [8 8 8 8 8    4 6 6      8  9 9 9 9];
rel = [1 1 1 1 1    1 1 1      2  1 1 3 3];
for i = 1:schema.nNodes
    src(end+1) = i; dst(end+1) = i; rel(end+1) = 4; %#ok<AGROW>
end
schema.src = src;
schema.dst = dst;
schema.rel = rel;
schema.nRelations = numel(schema.relationNames);

% 노드 특징: [값; 1-값; 위험 표시; 편향] + 노드 정체성 one-hot
schema.inDim = 4+schema.nNodes;

% 1단계에서 설계한 두 보상항과 온톨로지 노드의 대응.
% 반사실 민감도는 이 묶음 단위로 계산하고, 그 결과가 보상 가중치가 됩니다.
schema.terms = struct( ...
    'name',{'capture','distance'}, ...
    'label',{'착륙 패드 포착','착륙 지점 접근'}, ...
    'nodes',{[4,5,6],[1,7]}, ...
    'weightField',{'captureWeight','distanceWeight'});
schema.variant = 'core';
schema.weightNodes = [];
schema.valueNode = [];
if strcmp(variant,'design')
    schema = addDesignNodes(schema);
end
end

function schema = addDesignNodes(schema)
% 설계용 확장: 보상 가중치 두 개와 강화학습 가치 함수를 노드로 추가합니다.
%
% 가중치를 노드로 넣으면, 가중치를 바꿔가며 모은 자료에서 R-GAT이
% "어떤 배분이 안전 착륙으로 이어지는가"를 직접 학습합니다. 그러면 가중치 노드의
% 값을 바꿔보는 것만으로 그 배분이 착륙에 미치는 영향을 계산할 수 있습니다.
% 상태만 있는 core 그래프로는 이 계산이 불가능합니다. 가중치가 그래프에 없으니까요.
goal = schema.goalNode;
schema.nodeNames = [schema.nodeNames(1:goal-1), ...
    {'CaptureWeight','DistanceWeight','PolicyValue'},schema.nodeNames(goal)];
schema.nNodes = numel(schema.nodeNames);
schema.goalNode = schema.nNodes;
capture = goal; distance = goal+1; policy = goal+2;
schema.weightNodes = [capture,distance];
schema.valueNode = policy;
% 가중치와 가치는 클수록 좋은 쪽으로 해석하므로 위험 노드가 아닙니다.
schema.neutralValue = [schema.neutralValue(1:goal-1),0.5,0.5,0.5, ...
    schema.neutralValue(goal)];
% 기존 간선에서 목표 노드 번호만 새 위치로 옮깁니다.
schema.src(schema.src == goal) = schema.goalNode;
schema.dst(schema.dst == goal) = schema.goalNode;
selfMask = schema.rel == schema.nRelations;
schema.src(selfMask & schema.src == schema.goalNode) = schema.goalNode;
% 새 간선: 가중치 -> 그 가중치가 키우는 상태 -> 목표, 그리고 가치 -> 목표
newSrc = [capture capture distance distance policy 6 7];
newDst = [6       schema.goalNode distance*0+8 schema.goalNode schema.goalNode policy policy];
newRel = [2       3       2       3       3       2  1];
newDst(3) = 8;   % DistanceWeight -supports-> TouchdownSafety
schema.src = [schema.src(~selfMask),newSrc];
schema.dst = [schema.dst(~selfMask),newDst];
schema.rel = [schema.rel(~selfMask),newRel];
for i = 1:schema.nNodes
    schema.src(end+1) = i; schema.dst(end+1) = i; schema.rel(end+1) = schema.nRelations;
end
schema.inDim = 4+schema.nNodes;
schema.variant = 'design';
end
