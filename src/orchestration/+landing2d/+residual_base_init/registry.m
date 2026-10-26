function registry = registry()
% REGISTRY A versioned four-arm profile; the historical registry is unchanged.
registry = landing2d.config.methodRegistry();
extra = registry.methods(1); extra.id = 'residual_mlp_ppo';
extra.label = 'Residual-MLP PPO'; extra.representation = 'residual_actor';
extra.color = [.15 .55 .35]; extra.marker = 'd';
registry.methods = [registry.methods(1),extra,registry.methods(2:3)];
for k = 2:4, registry.methods(k).representation = 'residual_actor'; end
registry.methods(3).label = 'TOSM residual PPO';
registry.methods(4).label = 'Shuffled residual PPO';
registry.version = 'comparison_registry_residual_v4';
registry.trainSeeds.residualV1Dev = 341:345;
registry.trainSeeds.residualV1Confirm = 351:360;
registry.trainSeeds.residualV2Dev = 361:365;
registry.trainSeeds.residualV2Confirm = 371:380;
registry.trainSeeds.residualV3Dev = 381:385;
registry.trainSeeds.residualV3Confirm = 391:400;
registry.trainSeeds.residualPaired = 381:385;
registry.trainSeeds.residualFresh = 401:405;
registry.trainSeeds.residualDev = registry.trainSeeds.residualPaired;
registry.trainSeeds.residualConfirm = 411:420;
registry.trainSeeds.default = registry.trainSeeds.residualDev;
registry.relationShuffle.minChangedFraction = 2/3;
end
