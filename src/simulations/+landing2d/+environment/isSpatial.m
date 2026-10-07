function tf = isSpatial(c)
% ISSPATIAL  true면 3차원(측방 y축·roll 포함) 실험 계약.
% 2차원 기본 계약에는 experiment.spatial 항목이 없습니다.
tf = isstruct(c) && isfield(c,'experiment') && isfield(c.experiment,'spatial') ...
    && c.experiment.spatial.dimension == 3;
end
