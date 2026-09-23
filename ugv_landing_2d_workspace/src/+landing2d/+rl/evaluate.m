function [results,score,info] = evaluate(agent,c)
% EVALUATE  공칭 초기 조건에서 결정론적 정책으로 모든 시나리오를 모사.
% 비교 그림과 정책 선택 점수 모두 이 함수의 결과를 사용합니다.
nCases = size(c.scenarioSpeeds,1);
options = struct('deterministic',true,'collect',true,'rs',[]);
returns = zeros(nCases,1);
captureRate = zeros(nCases,1);
landed = false(nCases,1);
landingTime = nan(nCases,1);
for j = 1:nCases
    [r,s] = landing2d.rl.makeEpisode(c,j,agent.rl,[]);
    [r,traj] = landing2d.rl.rolloutEpisode(agent,r,s,c,options);
    results(j) = r; %#ok<AGROW>
    returns(j) = traj.return;
    captureRate(j) = traj.captureRate;
    landed(j) = isfinite(r.landingTime);
    landingTime(j) = r.landingTime;
end
score = mean(returns);
info = struct('returns',returns,'captureRate',captureRate, ...
    'landed',landed,'landingTime',landingTime, ...
    'landingRate',mean(landed),'meanCaptureRate',mean(captureRate));
end
