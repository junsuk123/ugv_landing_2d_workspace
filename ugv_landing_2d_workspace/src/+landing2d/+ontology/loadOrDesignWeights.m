function [design,info] = loadOrDesignWeights(c)
% LOADORDESIGNWEIGHTS  저장된 설계가 현재 설정과 같으면 재사용, 아니면 다시 설계.
file = fullfile(c.outputDir,c.ontology.designFile);
signature = landing2d.ontology.designSignature(c);
if ~c.ontology.redesign && isfile(file)
    saved = load(file);
    if isfield(saved,'design') && isfield(saved,'signature') ...
            && isequal(saved.signature,signature)
        design = saved.design;
        info = saved.info;
        if c.ontology.verbose
            fprintf('저장된 보상 가중치 설계를 사용합니다: %s\n',file);
            fprintf('  capture %.4f | distance %.4f (id %s)\n', ...
                design.captureWeight,design.distanceWeight,design.designId);
        end
        return;
    end
end
[design,info] = landing2d.ontology.designRewardWeights(c);
if ~exist(c.outputDir,'dir')
    [ok,message] = mkdir(c.outputDir);
    if ~ok, error('landing2d:OutputDirectory','%s',message); end
end
save(file,'design','info','signature');
if c.ontology.verbose
    fprintf('보상 가중치 설계 저장: %s\n',file);
end
end
