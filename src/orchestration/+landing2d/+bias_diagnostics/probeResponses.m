function [T,importance] = probeResponses(runs,S,d)
% PROBERESPONSES Open-loop responses of every frozen policy at identical states (Q1, Q2, Q4, P6).
% One row per (model, state). Requested accelerations are in m/s^2; responses
% to physical contrasts are central differences [(m/s^2)/(m/s) or (m/s^2)/m].
%   J            central finite-difference Jacobian of tanh(mu) w.r.t. single
%                o_t entries (arbitrary feature perturbation, not physical)
%   NormSensitivity  ||J diag(s)||_F with s the training-family std of o_t
%   Rugv/Rdrone/Rpos physical contrasts through the observation structure
%   NoiseStd*    action std over the nominal and the other sensor-noise tables
%   KLNoise/KLUgv  KL between the Gaussian latent policies (shared sigma)
%   StaleDelta*  requested(stale) - requested(fresh), fresh states only
%   CorrectionOff  ||requested - requested with sigma(beta)=0|| (residual actors)
%   TypingSwap     ||requested - requested with the same-seed partner's relation
%                  typing|| (TOSM <-> Shuffled; same parameters, same inputs)
% Agreement* compares response signs with the reference driver (a scale/sign
% reference, not an optimal policy). Rows are aggregated per training seed later.
p = d.perturbation; n = size(S.o,2); h = p.finiteDifference;
rows = cell(1,numel(runs)); importanceRows = cell(1,numel(runs));
refUgv = [S.reference.ugv]; refDrone = [S.reference.drone]; refPos = [S.reference.pos];
refStale = [S.reference.stale];
for r = 1:numel(runs)
    run = runs(r);
    base = landing2d.bias_diagnostics.response(run,S.o);
    J = NaN(2,10,n);
    for j = p.jacobianInputs
        plus = S.o; minus = S.o; plus(j,:) = plus(j,:)+h; minus(j,:) = minus(j,:)-h;
        valid = true(1,n);
        if ismember(j,[3 4]), valid = abs(S.o(j,:))<=1-2*h; end
        plus(:,~valid) = S.o(:,~valid); minus(:,~valid) = S.o(:,~valid);
        J(:,j,:) = reshape((landing2d.bias_diagnostics.response(run,plus).action- ...
            landing2d.bias_diagnostics.response(run,minus).action)/(2*h),2,1,n);
        J(:,j,~valid) = NaN;
    end
    scaled = J.*reshape(S.inputScale,1,10);
    normSensitivity = sqrt(squeeze(sum(scaled.^2,[1 2],'omitnan')))';
    req = @(V)landing2d.bias_diagnostics.response(run,V).requested;
    muOf = @(V)landing2d.bias_diagnostics.response(run,V).mu;
    rugv = (req(S.ugvPlus)-req(S.ugvMinus))/(2*p.ugvVelocity);
    rdrone = (req(S.dronePlus)-req(S.droneMinus))/(2*p.droneVelocity);
    rpos = (req(S.posPlus)-req(S.posMinus))/(2*p.ugvPosition);
    sigma = base.sigma;
    R = size(S.noise,2); noiseReq = zeros(2,R,n); kl = zeros(R,n);
    for j = 1:R
        V = squeeze(S.noise(:,j,:));
        out = landing2d.bias_diagnostics.response(run,V);
        noiseReq(:,j,:) = reshape(out.requested,2,1,n);
        kl(j,:) = sum((out.mu-base.mu).^2./(2*sigma.^2),1);
    end
    allReq = cat(2,reshape(base.requested,2,1,n),noiseReq);
    noiseStd = squeeze(std(allReq,0,2));
    klUgv = sum((muOf(S.ugvPlus)-muOf(S.ugvMinus)).^2./(2*sigma.^2),1);
    staleDelta = NaN(2,n); hasStale = S.states.HasStale';
    if any(hasStale)
        staleDelta(:,hasStale) = req(S.stale(:,hasStale))-base.requested(:,hasStale);
    end
    correctionOff = NaN(1,n); typingSwap = NaN(1,n); baseRms = NaN(1,n); correctionRms = NaN(1,n);
    if isfield(base,'correction')
        off = landing2d.bias_diagnostics.response(run,S.o,struct('correction','off'));
        correctionOff = vecnorm(base.requested-off.requested,2,1);
        baseRms = sqrt(mean(base.base.^2,1)); correctionRms = sqrt(mean(base.correction.^2,1));
        partner = partnerRun(runs,run);
        if ~isempty(partner)
            swapped = landing2d.bias_diagnostics.response(run,S.o, ...
                struct('spec',partner.agent.encoderSpec));
            typingSwap = vecnorm(base.requested-swapped.requested,2,1);
        end
    end
    rows{r} = [S.states(:,{'Family','EnvironmentSeed','Decision','Class','MarkerUpdated', ...
        'Height','FovRatio','PadAcceleration','HasStale'}), table( ...
        repmat(string(run.id),n,1),repmat(run.trainSeed,n,1), ...
        base.requested(1,:)',base.requested(2,:)', ...
        double(abs(base.action(1,:))>d.saturationThreshold)', ...
        double(abs(base.action(2,:))>d.saturationThreshold)', ...
        normSensitivity',rugv(1,:)',rugv(2,:)',rdrone(1,:)',rdrone(2,:)',rpos(1,:)',rpos(2,:)', ...
        noiseStd(1,:)',noiseStd(2,:)',mean(kl,1)',klUgv',staleDelta(1,:)',staleDelta(2,:)', ...
        double(sign(rugv(1,:))==sign(refUgv(1,:)))',double(sign(rdrone(1,:))==sign(refDrone(1,:)))', ...
        double(sign(rpos(1,:))==sign(refPos(1,:)))',refUgv(1,:)',refDrone(1,:)',refPos(1,:)', ...
        refStale(1,:)',correctionOff',typingSwap',baseRms',correctionRms', ...
        'VariableNames',{'MethodId','TrainSeed','RequestedAx','RequestedAz', ...
        'SaturatedX','SaturatedZ','NormSensitivity','RugvX','RugvZ','RdroneX','RdroneZ', ...
        'RposX','RposZ','NoiseStdX','NoiseStdZ','KLNoise','KLUgv','StaleDeltaX','StaleDeltaZ', ...
        'AgreeUgvX','AgreeDroneX','AgreePosX','ReferenceRugvX','ReferenceRdroneX', ...
        'ReferenceRposX','ReferenceStaleDeltaX','CorrectionOff','TypingSwap', ...
        'BaseMeanRms','CorrectionRms'})];
    % Mean |J| x typical input variation per input and axis (which inputs move actions).
    meanScaled = mean(abs(scaled),3,'omitnan');
    importanceRows{r} = table(repmat(string(run.id),20,1),repmat(run.trainSeed,20,1), ...
        repelem(["ax";"az"],10,1),repmat((1:10)',2,1), ...
        reshape(meanScaled',[],1),'VariableNames', ...
        {'MethodId','TrainSeed','Axis','Input','MeanAbsScaledJacobian'});
end
T = vertcat(rows{:}); importance = vertcat(importanceRows{:});
end

function partner = partnerRun(runs,run)
partner = [];
pairs = struct('onto_rgat_ppo','shuffled_rgat_ppo','shuffled_rgat_ppo','onto_rgat_ppo');
if ~isfield(pairs,run.id), return; end
k = find(strcmp({runs.id},pairs.(run.id)) & [runs.trainSeed]==run.trainSeed,1);
if ~isempty(k), partner = runs(k); end
end
