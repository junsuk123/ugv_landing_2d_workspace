function summaryTable = makeSummary(results, c)
n = numel(results);
Scenario = cell(n,1); Status = cell(n,1);
FirstLoss_s = nan(n,1); FirstReacquire_s = nan(n,1);
Landing_s = nan(n,1); PeakHeightAbovePad_m = nan(n,1);
for j = 1:n
    r = results(j);
    Scenario{j} = r.name; Status{j} = r.status;
    if ~isempty(r.lossTimes), FirstLoss_s(j) = r.lossTimes(1); end
    if ~isempty(r.reacquireTimes), FirstReacquire_s(j) = r.reacquireTimes(1); end
    Landing_s(j) = r.landingTime;
    PeakHeightAbovePad_m(j) = max(r.zDrone) - c.padHeight;
end
summaryTable = table(Scenario,FirstLoss_s,FirstReacquire_s, ...
    Landing_s,PeakHeightAbovePad_m,Status);
end
