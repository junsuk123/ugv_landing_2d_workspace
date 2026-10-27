% RUN Current-observation ontology study. Edit settings, then press F5.
% Current 10-D only; no policy memory or auxiliary loss. Performance unverified.
% See docs/CURRENT_SEMANTICS_ALGORITHM_KO.md and CURRENT_SEMANTICS_EXPERIMENT_KO.md.
% The complete four-arm seed plan is fixed by the registered protocol.
runSettings = struct();
runSettings.phase = 'development';    % confirmation opens only after the frozen development gate
runSettings.smoke = false;            % true is TEST ONLY, never a performance result
runSettings.autoRegister = true;      % native checks and source manifest before any full training
runSettings.runSelfTest = true;
runSettings.concurrentRuns = 1;

landingStudy = runWithSettings(runSettings);

function output = runWithSettings(settings)
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    addpath(fullfile(root,'src',name{1}));
end
settings.root = root;
output = landing2d.current_semantics.runPipeline(settings);
end
