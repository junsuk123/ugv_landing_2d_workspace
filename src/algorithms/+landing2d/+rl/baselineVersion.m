function version = baselineVersion(algorithmVersion)
% BASELINEVERSION  Version of the plain-PPO path inside an algorithm version.
%   version = landing2d.rl.baselineVersion('relational-policy-v2.13')
% Plain PPO reads o_t through the identity encoder and never touches the
% R-GAT encoder or the graph features. Algorithm versions that changed only
% the R-GAT arms share one plain-PPO version, so a plain-PPO checkpoint of
% one of them is the same policy under the others (landing2d.rl.signatureMatches).
% A version is listed only after its code change was checked to leave the
% plain-PPO path (o_t, MLP 48-51 / 47-50, PPO loss and update, validation,
% early stop, random streams) untouched:
%   relational-policy-v2.13  graph features tosm7_v3 only (2026-10-23)
%   relational-policy-v2.14  graph features tosm7_v4 only (2026-10-23)
% Every other version maps to itself.
%   relational-policy-v2.15  graph features tosm7_v5 only (2026-10-24)
samePath = {'relational-policy-v2.12','relational-policy-v2.13', ...
    'relational-policy-v2.14','relational-policy-v2.15'};
if ismember(algorithmVersion,samePath)
    version = 'plain-ppo-v2.12';
else
    version = algorithmVersion;
end
end
