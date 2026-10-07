function in = prepareEpisode(in,source)
% PREPAREEPISODE  rlSimulinkEnv ResetFcn: 매 에피소드 시작 전 다음 에피소드 준비.
%
%   env.ResetFcn = @(in) landing2d.simulink.prepareEpisode(in,source)
%
% ResetFcn은 시뮬레이션을 돌릴 프로세스(직렬은 클라이언트, 병렬은 각 워커)에서
% 실행되므로, 준비한 에피소드는 같은 프로세스의 환경 블록이 읽습니다.
% source를 생략하면 episodeServer에 등록된 공급원을 씁니다.
if nargin < 2
    landing2d.simulink.episodeServer('advance');
else
    landing2d.simulink.episodeServer('advanceFrom',source);
end
end
