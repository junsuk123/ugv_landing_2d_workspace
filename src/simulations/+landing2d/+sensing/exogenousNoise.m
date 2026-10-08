function noise = exogenousNoise(c,base,deadline,scale)
% EXOGENOUSNOISE  한 에피소드의 시간 기준 표준정규 센서 잡음표 (평면 공통 관측 계약).
% reset에서 전용 난수열로 한 번 만들고, 결정 시점 k(0 = reset)와 결정 구간 안의 물리
% 스텝 j로 색인합니다. 같은 시각의 잡음 실현값은 검출된 마커, 정책, 조기 종료와
% 무관하므로 비교군·폐루프 쌍·고정 probe가 같은 외생 잡음을 공유합니다.
%   tracker     2 x J x (K+1)      평면 tracker [상대 x; bearing], 열 k+1의 j번째 물리 스텝
%   marker      2 x 4 x M x (K+1)  마커 코너 [u; v] x 코너 x 등록 슬롯, 결정 시점마다
%   navigation  3 x (K+1)          융합 측위 [pitch; 기체 vx; 기체 vz], 결정 시점마다
% 표 값은 표준정규 표본에 SCALE(관측오차 표준편차 배율)을 곱한 값이고, 센서 모델이
% 자기 표준편차를 곱해 씁니다(공분산 = SCALE^2 x 기본 공분산). 배율이 달라도 같은
% 표준정규 표본을 쓰므로 배율 간 잡음이 짝지어집니다. 검출 여부·dropout 일정은
% 바꾸지 않습니다. BASE = scenario.baseSeed + seed, DEADLINE = scenario.deadline.
if nargin < 4 || isempty(scale), scale = 1; end
validateattributes(scale,{'numeric'},{'scalar','real','finite','nonnegative'}, ...
    mfilename,'scale');
e = c.experiment;
co = e.commonObservation;
streams = co.randomStreams;
assert(strcmp(streams.indexing,'time_indexed_v1'),'landing2d:NoiseIndexing', ...
    'Unknown sensor-noise indexing %s.',streams.indexing);
K = ceil(deadline/e.policyDt-1e-9)+1;           % 마지막 결정 시점 이후 여유 1열
J = round(e.policyDt/e.physicsDt)+2;            % 결정 구간 물리 스텝 + 반올림 여유
M = numel(co.pad.markerIds);
seeds = struct('tracker',base+streams.trackerOffset, ...
    'marker',base+streams.markerOffset,'navigation',base+streams.navigationOffset);
tracker = randn(RandStream('threefry','Seed',seeds.tracker),2,J,K+1);
marker = randn(RandStream('threefry','Seed',seeds.marker),2,4,M,K+1);
navigation = randn(RandStream('threefry','Seed',seeds.navigation),3,K+1);
noise = struct('indexing',streams.indexing,'scale',double(scale),'seeds',seeds, ...
    'tracker',scale*tracker,'marker',scale*marker,'navigation',scale*navigation);
end
