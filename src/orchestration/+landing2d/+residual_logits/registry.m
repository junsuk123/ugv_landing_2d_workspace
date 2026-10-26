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
registry.version = 'comparison_registry_residual_v2';
registry.trainSeeds.residualV1Dev = 341:345;
registry.trainSeeds.residualV1Confirm = 351:360;
registry.trainSeeds.residualDev = 361:365;
registry.trainSeeds.residualConfirm = 371:380;
registry.trainSeeds.default = registry.trainSeeds.residualDev;
registry.relationShuffle.minChangedFraction = 2/3;
end
