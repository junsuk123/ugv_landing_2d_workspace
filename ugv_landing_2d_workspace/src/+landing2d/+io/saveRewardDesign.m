function [designTable,nodeTable] = saveRewardDesign(design,cfg)
% SAVEREWARDDESIGN  온톨로지 R-GAT가 추론한 보상 가중치와 근거를 표로 저장.
% 어떤 항이 왜 그 가중치를 받았는지, 어떤 노드가 기여했는지 함께 남깁니다.
schema = landing2d.ontology.nodeSchema();
Term = design.termNames(:);
Meaning = design.termLabels(:);
OntologyNodes = cell(numel(Term),1);
for i = 1:numel(Term)
    OntologyNodes{i} = strjoin(schema.nodeNames(schema.terms(i).nodes),' + ');
end
CounterfactualImportance = design.importance(:);
SignedEffect = design.signedEffect(:);
NormalizedShare = design.share(:);
RewardWeight = design.weights(:);
designTable = table(Term,Meaning,OntologyNodes,CounterfactualImportance, ...
    SignedEffect,NormalizedShare,RewardWeight);
if ~exist(cfg.outputDir,'dir')
    [ok,message] = mkdir(cfg.outputDir);
    if ~ok, error('landing2d:OutputDirectory','%s',message); end
end
writetable(designTable,fullfile(cfg.outputDir,'reward_design_weights.csv'));

nodeTable = table();
if isfield(design,'nodeImportance')
    keep = 1:schema.nNodes;
    keep(schema.goalNode) = [];
    Node = design.nodeImportance.nodeNames(keep)';
    Kind = repmat({'support'},numel(keep),1);
    Kind(ismember(keep,schema.riskNodes)) = {'risk'};
    RewardTerm = repmat({'-'},numel(keep),1);
    for i = 1:numel(schema.terms)
        RewardTerm(ismember(keep,schema.terms(i).nodes)) = {schema.terms(i).name};
    end
    Magnitude = design.nodeImportance.magnitude(keep)';
    Signed = design.nodeImportance.signed(keep)';
    nodeTable = table(Node,Kind,RewardTerm,Magnitude,Signed);
    nodeTable = sortrows(nodeTable,'Magnitude','descend');
    writetable(nodeTable,fullfile(cfg.outputDir,'ontology_node_importance.csv'));
end
end
