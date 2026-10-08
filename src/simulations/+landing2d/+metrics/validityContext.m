function id = validityContext(ctx,h,c)
% VALIDITYCONTEXT  Observable context label 'vision/height/decision' of a probe.
% vision    fresh (vision update now), recent (within recentTrackGrace), stale,
%           none (UGV estimate not initialized), from the reference observation
% height    final (<= final-descent exit height), low (<= 2 m), high, from own
%           navigation height above the known pad plane
% decision  abort (backup requested), inhibited, authorized
s = c.experiment.safety;
if ctx.visionUpdated
    vision = 'fresh';
elseif ctx.estimateInitialized && ctx.visionAge <= s.recentTrackGrace
    vision = 'recent';
elseif ctx.estimateInitialized
    vision = 'stale';
else
    vision = 'none';
end
if h <= c.experiment.commonObservation.finalDescent.exitHeight
    band = 'final';
elseif h <= 2
    band = 'low';
else
    band = 'high';
end
if ctx.abortRequested
    decision = 'abort';
elseif ctx.landingInhibited
    decision = 'inhibited';
else
    decision = 'authorized';
end
id = [vision '/' band '/' decision];
end
