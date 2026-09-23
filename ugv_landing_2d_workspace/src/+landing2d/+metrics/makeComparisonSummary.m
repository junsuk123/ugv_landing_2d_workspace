function summaryTable = makeComparisonSummary(runs,c)
% MAKECOMPARISONSUMMARY  제어기별/시나리오별 비교 요약.
% 포착률은 비행 구간에서 패드를 보고 있거나 착륙 상태였던 시간 비율입니다.
runs = landing2d.viz.normalizeRuns(runs);
rows = numel(runs)*numel(runs(1).results);
Controller = cell(rows,1);
Scenario = cell(rows,1);
Status = cell(rows,1);
FirstLoss_s = nan(rows,1);
FirstReacquire_s = nan(rows,1);
Landing_s = nan(rows,1);
PeakHeightAbovePad_m = nan(rows,1);
PadCaptureRate = nan(rows,1);
ReacquireDelay_s = nan(rows,1);
ClimbAfterLoss_m = nan(rows,1);
row = 0;
for i = 1:numel(runs)
    for j = 1:numel(runs(i).results)
        r = runs(i).results(j);
        row = row+1;
        Controller{row} = runs(i).label;
        Scenario{row} = r.name;
        Status{row} = r.status;
        if ~isempty(r.lossTimes), FirstLoss_s(row) = r.lossTimes(1); end
        if ~isempty(r.reacquireTimes), FirstReacquire_s(row) = r.reacquireTimes(1); end
        Landing_s(row) = r.landingTime;
        PeakHeightAbovePad_m(row) = max(r.zDrone)-c.padHeight;
        % 재포착에 걸린 시간과, 그동안 올라간 고도.
        % 교사 유도 법칙이 재포착을 위해 넣어 둔 상승 동작의 크기를 재는 값입니다.
        if ~isempty(r.lossTimes)
            lossIndex = find(r.time >= r.lossTimes(1),1);
            after = r.zDrone(lossIndex:end);
            ClimbAfterLoss_m(row) = max(after)-r.zDrone(lossIndex);
            if ~isempty(r.reacquireTimes)
                ReacquireDelay_s(row) = r.reacquireTimes(1)-r.lossTimes(1);
            end
        else
            ClimbAfterLoss_m(row) = 0;
        end
        last = find(r.time <= landing2d.viz.flightEndTime(r)+1e-10,1,'last');
        captured = r.visible(1:last) | r.mode(1:last) == 3;
        PadCaptureRate(row) = mean(captured);

    end
end
summaryTable = table(Controller,Scenario,FirstLoss_s,ReacquireDelay_s, ...
    ClimbAfterLoss_m,Landing_s,PeakHeightAbovePad_m,PadCaptureRate,Status);
end
