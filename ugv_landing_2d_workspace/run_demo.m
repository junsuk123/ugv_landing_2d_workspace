% RUN_DEMO  이 파일을 MATLAB 편집기에서 열어 Run을 누르면 실행.
% MATLAB Current Folder를 이 파일이 있는 프로젝트 루트로 지정하세요.
% 별도 Toolbox와 Simulink를 사용하지 않습니다.
% 세 비교군(PN 유도 / 강화학습 / 온톨로지 가중치)을 모두 실행하려면 run_all을 쓰세요.

options = struct();
options.playbackSpeed = 4;       % 데모 표시 4배속. 계산 dt는 바뀌지 않음.
options.segmentAlpha = 0.16;     % 0=투명, 1=불투명
options.makeDetailPlots = false;  % true면 위치/속도 4패널 등 상세 그림도 생성

% 필요할 때 아래 주석을 해제해 수정하세요.
% options.animate = false;       % 실시간 표시 없이 계산
% options.scenarioSpeeds = [1,4,1.5; 1.5,5.5,2; 2,7,2.5];
% options.segmentTimes = [8,15];
% options.segmentColors = [0.27,0.56,0.88; 0.96,0.61,0.22; 0.32,0.72,0.54];

[results, summaryTable, cfg] = run_ugv_landing_2d(options);
