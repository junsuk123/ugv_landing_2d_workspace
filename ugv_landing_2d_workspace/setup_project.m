function projectRoot = setup_project()
% SETUP_PROJECT  루트와 src만 MATLAB 경로에 추가. +패키지 폴더는 직접 추가하지 않음.
projectRoot = fileparts(mfilename('fullpath'));
addpath(projectRoot);
addpath(fullfile(projectRoot, 'src'));
end
