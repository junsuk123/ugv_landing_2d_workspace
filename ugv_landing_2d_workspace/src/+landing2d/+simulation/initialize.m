function [results, states, t] = initialize(cfg)
% INITIALIZE  시나리오별 UGV 궤적, 드론 상태, 결과 배열 초기화.
nSteps = round(cfg.tEnd / cfg.dt);
t = (0:nSteps)' * cfg.dt;
nCases = size(cfg.scenarioSpeeds, 1);

for j = 1:nCases
    [r, s] = landing2d.simulation.initializeCase(cfg, j, t);
    results(j) = r; %#ok<AGROW>
    states(j) = s; %#ok<AGROW>
end


end
