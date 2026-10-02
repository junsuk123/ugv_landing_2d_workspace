function [results,info] = evaluatePnV2(c,seeds)
% EVALUATEPNV2  Paired held-out V2 evaluation for the causal PN comparator.
cells=cell(1,numel(seeds)); returns=zeros(1,numel(seeds));
success=false(size(returns)); unsafe=success; abort=success; capture=zeros(size(returns));
for i=1:numel(seeds)
    cells{i}=landing2d.control.rolloutPnV2(c,seeds(i));
    returns(i)=cells{i}.return; capture(i)=cells{i}.captureRate;
    reason=cells{i}.terminalReason;
    success(i)=strcmp(reason,'SUCCESS');
    unsafe(i)=ismember(reason,{'UNSAFE_CONTACT','UNAUTHORIZED_CONTACT', ...
        'MISSED_PAD_CONTACT','SAFETY_ENVELOPE_VIOLATION'});
    abort(i)=strcmp(reason,'SAFE_ABORT');
end
results=[cells{:}];
info=struct('returns',returns,'captureRate',capture,'landed',success, ...
    'landingTime',[results.landingTime],'landingRate',mean(success), ...
    'meanCaptureRate',mean(capture),'meanReturn',mean(returns), ...
    'selectionScore',1000*mean(success)-1000*mean(unsafe)-100*mean(abort)+mean(returns), ...
    'unsafeRate',mean(unsafe),'safeAbortRate',mean(abort), ...
    'nodeMean',[],'nodeVariance',[],'edgeAttentionMean',[],'graphSchema',struct());
end
