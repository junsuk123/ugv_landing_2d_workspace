function features = termFeatures(D,rl)
% TERMFEATURES  데이터셋의 각 표본에서 두 보상항의 값을 계산.
%
% 보상항은 온톨로지 노드 값으로 그대로 표현됩니다. 이 대응이 있어야
% "온톨로지가 보상 가중치를 설계한다"는 말이 성립합니다.
%
%   포착 항  = 1 - 2*FovMargin              (중앙 +1, 시야 가장자리 -1)
%   접근 항  = 1 - RelativeDistance^지수     (착륙 지점 +1, 먼 곳 -1)
%
% landing2d.rl.rolloutEpisode가 쓰는 식과 같아야 합니다. 한쪽만 바꾸면
% 설계한 가중치가 실제 보상과 다른 것을 가리키게 됩니다.
assert(strcmp(rl.distanceMode,'proximity'), ...
    'landing2d:DistanceModeMismatch', ...
    ['termFeatures needs rl.distanceMode = proximity. The rate form is a ' ...
     'change between two states and cannot be read from one graph snapshot; ' ...
     'use weightObjective counterfactual or weightGraph instead.']);
schema = D.schema;
values = squeeze(D.X(1,:,:));
fovMargin = values(nodeIndex(schema,'FovMargin'),:);
relativeDistance = values(nodeIndex(schema,'RelativeDistance'),:);
capture = 1-2*min(fovMargin,1);
proximity = 1-relativeDistance.^rl.distanceExponent;
features = [capture;landing2d.util.saturate(proximity,1)];
end

function index = nodeIndex(schema,name)
index = find(strcmp(schema.nodeNames,name),1);
assert(~isempty(index),'landing2d:MissingNode', ...
    'The ontology needs a %s node to express the reward terms.',name);
end
