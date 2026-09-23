function [results, summaryTable, cfg] = ugv_landing_2d_demo(options)
% UGV_LANDING_2D_DEMO  기존 단일 파일 버전의 호출 방식 유지용 진입점.
% 이 파일만 분리하지 말고 전체 프로젝트 폴더를 함께 사용하세요.
if nargin < 1
    options = struct();
end
[results, summaryTable, cfg] = run_ugv_landing_2d(options);
end
