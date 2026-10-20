function cfg = defaultConfig(projectRoot)
% DEFAULTCONFIG  Base configuration; landing2d.config.primaryConfig adds the experiment.
if nargin < 1
    projectRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end
cfg.padHalfLength = 0.5;   % pad half length along the motion direction [m]
cfg.axMax = 2.5;           % horizontal acceleration limit [m/s^2]
cfg.azMax = 2.0;           % vertical acceleration limit [m/s^2]
cfg.vxMax = 10.0;          % horizontal speed normalization scale [m/s]
cfg.vzMax = 1.5;           % vertical speed normalization scale [m/s]
cfg.outputDir = fullfile(projectRoot,'results');
cfg.figureVisible = true;
cfg.rl = landing2d.rl.defaultRlConfig();
cfg.graphState = landing2d.graphstate.defaultGraphStateConfig();
cfg.experiment = struct('schemaVersion','none','enabled',false);
end
