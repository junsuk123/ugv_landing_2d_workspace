function memory = initialMemory()
% INITIALMEMORY  에피소드 시작 시의 공통 관측 기억 (UGV 상태추정기 + 직전 운동 기록).
%   filter    등속 칼만 필터: 초기화 전에는 상태 없음(참값으로 만들지 않음)
%   previous  직전 결정 시점의 UGV·드론 위치·속도와 기록 유효 (H_t)
% 기록에는 운동 상태만 저장하며, 이전 관측 전체나 이전 기록을 다시 넣지 않습니다.
% 에피소드가 바뀌면 이 함수로 추정기와 기록을 모두 초기화합니다.
filter = struct('initialized',false,'time',NaN,'state',zeros(4,1), ...
    'covariance',zeros(4),'lastUpdateTime',NaN,'updated',false);
previous = struct('ugvPositionXZ',zeros(2,1),'ugvVelocityXZ',zeros(2,1), ...
    'dronePositionXZ',zeros(2,1),'droneVelocityXZ',zeros(2,1), ...
    'ugvInitialized',false,'valid',false);
memory = struct('filter',filter,'previous',previous);
end
