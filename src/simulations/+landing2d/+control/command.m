function [s,ax,az,descending,event] = command(s,obs,c)
% COMMAND  설정된 유도/제어 법칙으로 가속도 명령을 계산하는 단일 진입점.
% 시뮬레이션, 교사 시연 수집, 온톨로지 데이터 생성이 모두 이 함수를 통합니다.
%
%   'pn' : 비례 항법 유도 (기본)
%   'pd' : 기존 PD 제어. 원본 단일 파일과의 회귀 비교 전용으로 남겨둔 경로
switch lower(c.controller)
    case 'pn'
        [s,ax,az,descending,event] = landing2d.control.pnGuidance(s,obs,c);
    case 'pd'
        [s,ax,az,descending,event] = landing2d.control.pdController(s,obs,c);
    otherwise
        error('landing2d:UnknownController', ...
            'Unknown controller: %s. Use pn or pd.',char(c.controller));
end
end
