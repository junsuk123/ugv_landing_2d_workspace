function frozen = calibrateValidity(bank,grid,c,file)
% CALIBRATEVALIDITY  Freeze the validity horizon and tolerance on the validation split.
% Method-agnostic rule (no comparison-method output is used). For each
% candidate horizon H and task tolerance kappa (c.consistency.validity):
%   applicable      share of probes with some safe grid command (supervisor not
%                   overriding the policy)
%   driverValid     share of applicable probes where the noise-free commands of the
%                   causal reference driver that flew the bank (bank.truth
%                   .driverMeanAcceleration) are valid; a judge that rejects a
%                   competent controller's commands is too strict
%   discrimination  mean share of grid commands that are not admissible
% Among (H, kappa) with applicable >= minimumApplicable and driverValid >=
% minimumDriverValid, take the largest discrimination (ties: shorter H, then
% larger kappa). If none qualifies, take the largest driverValid and flag it.
% Contact, braking and FOV thresholds stay at the contract values (margin >= 0).
% The choice, evidence and SHA-256 go to FILE (JSON); test evaluations load it.
assert(strcmp(bank.meta.split,'validation') && strcmp(grid.split,'validation'), ...
    'landing2d:ValidityCalibration','The validity settings are chosen on the validation split only.');
v = c.consistency.validity;
eligible = ~grid.override;
nH = numel(grid.horizons); nK = numel(grid.kappas);
applicable = mean(grid.anySafe(:,eligible),2)';
discrimination = NaN(nH,nK); driverValid = NaN(nH,nK);
P = bank.meta.probeCount;
driver = struct('run',struct('MethodId','reference_driver'), ...
    'requestedAcceleration',reshape(bank.truth.driverMeanAcceleration,[],P,1));
for k = 1:nH
    use = eligible & grid.anySafe(k,:);
    for j = 1:nK
        discrimination(k,j) = mean(1-squeeze(grid.admissibleFraction(k,j,use)));
        candidate = struct('schemaVersion','validity_frozen_v1','horizon',grid.horizons(k), ...
            'kappa',grid.kappas(j),'gridPoints',grid.gridPoints,'hash','calibration');
        result = landing2d.consistency.probeValidity(bank,driver,candidate,grid,c);
        driverValid(k,j) = mean(result.valid(result.applicable,1));
    end
end
qualified = repmat(applicable(:) >= v.minimumApplicable,1,nK) & driverValid >= v.minimumDriverValid;
meetsFloor = any(qualified(:));
score = discrimination;
if meetsFloor
    score(~qualified) = -Inf;
else
    score = driverValid;
end
% Ties: shorter horizon first (rows ascend), then larger kappa (columns descend).
best = -Inf; choice = [1,1];
for k = 1:nH
    for j = nK:-1:1
        if score(k,j) > best+1e-12
            best = score(k,j); choice = [k,j];
        end
    end
end
frozen = struct('schemaVersion','validity_frozen_v1','split',grid.split, ...
    'seeds',bank.meta.seeds,'bankConfigHash',grid.bankConfigHash, ...
    'horizon',grid.horizons(choice(1)),'kappa',grid.kappas(choice(2)), ...
    'gridPoints',grid.gridPoints,'horizonCandidates',grid.horizons, ...
    'kappaCandidates',grid.kappas,'applicableShare',applicable, ...
    'driverValidShare',driverValid,'discrimination',discrimination, ...
    'minimumApplicable',v.minimumApplicable,'minimumDriverValid',v.minimumDriverValid, ...
    'meetsFloors',meetsFloor,'overrideShare',mean(grid.override), ...
    'thresholds','contract margins >= 0; task rules q <= min + kappa*spread', ...
    'created',char(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ss')));
frozen.hash = landing2d.util.sha256(jsonencode(frozen));
if nargin >= 4 && ~isempty(file)
    folder = fileparts(file);
    if ~isempty(folder) && ~exist(folder,'dir'), mkdir(folder); end
    fid = fopen(file,'w'); fwrite(fid,jsonencode(frozen,'PrettyPrint',true),'char'); fclose(fid);
end
end
