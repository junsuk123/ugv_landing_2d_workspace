function verify_trajmc_selected(output)
% Focused regression checks for the selected-case Monte Carlo entry.
q=struct('time',[0 1],'x',[10 10],'z',[2 0], ...
    'xPad',[5 5],'terminalReason','SUCCESS');
r=q; r.time=[0 2]; r.x=[12 12]; r.terminalReason='TASK_TIMEOUT';
p=linspace(0,1,401);
[s,m]=landing2d.metrics.trajectorySpatialStatistics({q,r},p);
assert(all(abs(s.meanX-11)<1e-12));
assert(all(abs(s.normalVariance-2)<1e-12));
assert(s.meanPadEndX==5 && m.SuccessRate==0.5 && m.TimeoutRate==0.5);
assert(abs(m.TerminalSpatialNormalVariance_m2-2)<1e-12);
[s,~]=landing2d.metrics.trajectorySpatialStatistics({q,q},p);
assert(all(s.normalVariance==0));
assert(isequal(string({output.scenarios.id}),["C1","C2","C3"]));
assert(all(output.trainSeeds==1));
assert(all(cellfun(@(q)q.verified && q.pairedAcrossMethods,output.variationContracts)));
for i=1:3
    for j=1:2
        s=output.plotStatistics{i,j};
        row=output.summary(2*(i-1)+j,:);
        assert(size(s.sampleX,1)==output.numRuns);
        assert(numel(s.terminalReasons)==output.numRuns);
        assert(abs(mean(s.normalVariance)-row.SpatialNormalVariance_m2)<1e-12);
        assert(abs(mean(s.normalVariance(p>=.8))-row.TerminalSpatialNormalVariance_m2)<1e-12);
        assert(all(isfinite(s.meanX)) && all(isfinite(s.meanZ)));
        assert(all(s.normalVariance>=0));
    end
end
assert(numel(findall(output.figure,'Type','axes'))==4); % 3 panels + C2 inset
fprintf('Selected trajectory regression: PASS (all-run statistics, pairing, 3 panels + inset).\n');
end
