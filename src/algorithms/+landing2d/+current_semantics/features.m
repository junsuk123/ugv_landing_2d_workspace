function [phi,X,detail,J] = features(o,k)
% FEATURES Deterministic semantics from exactly the current 10-D observation.
% phi is 19 x B, with all variable node channels and no zero padding/node ID.
% X is 6 x 7 x B: five data channels followed by the fixed node index / 7.
% J is d(phi)/d(o), 19 x 10 x B. This is an algebraic derivative, not history.
%
% In physical units: ea = ex - m*max(h,0), va = relativeVx - m*vz for h>0,
% and va = relativeVx for h<=0 (zero derivative for max(h,0) at h=0).
% ea*va is the instantaneous rate of ea^2/2 under the planar motion model;
% it is not a measured finite difference or a claim about estimator jumps.
% P stores softsign(ea;3), softsign(va;1), softsign(ea*va;3), with the scales
% supplied in K. The latter is NOT the product of the two bounded features.
% Contact ratios are pointwise softsigns of the five mechanical quantities.
%
% The inverse-softsign expressions are algebraically combined into rational
% forms. Physical slots exactly +/-1 have no finite inverse and are rejected.
% o10=1 (no previous vision update) is valid; no hidden initialized flag is read.
if nargin < 2, k = landing2d.current_semantics.featureConstants(); end
% Only immutable schema/constant names are cached; no observation is retained.
persistent fixedSchema constantNames
if isempty(constantNames)
    constantNames = fieldnames(landing2d.current_semantics.featureConstants());
end
assert(isnumeric(o) && isreal(o) && ismatrix(o) && size(o,1)==10 && size(o,2)>=1 ...
    && all(isfinite(o),'all'),'landing2d:CurrentSemanticsObservation', ...
    'Expected a finite real 10-by-B current observation.');
assert(all(abs(o([1:5 8],:))<1,'all'),'landing2d:CurrentSemanticsSaturation', ...
    'Physical softsign slots [1:5,8] must be strictly inside (-1,1).');
assert(all(abs(o(6:7,:))<=1,'all') && all(sum(o(6:7,:).^2,1)>0) ...
    && all(o(9:10,:)>=0 & o(9:10,:)<=1,'all'), ...
    'landing2d:CurrentSemanticsObservation','Malformed attitude/quality channels.');
names = constantNames;
assert(isequal(sort(fieldnames(k)),sort(names)),'landing2d:CurrentSemanticsConstants', ...
    'Feature constants must contain only the registered public constants.');
for i = 1:numel(names)
    v = k.(names{i});
    assert(isnumeric(v) && isreal(v) && isscalar(v) && isfinite(v), ...
        'landing2d:CurrentSemanticsConstants','Feature constants must be finite scalars.');
    if ~strcmp(names{i},'aimSlope')
        assert(v>0,'landing2d:CurrentSemanticsConstants','Feature scales must be positive.');
    end
end
o = double(o); B = size(o,2);
derivatives = 0;
if nargout > 3, derivatives = 10; end
v = cell(1,10);
for j = 1:10
    q = zeros(derivatives,B);
    if derivatives>0, q(j,:) = 1; end
    v{j} = struct('v',o(j,:),'j',q);
end
one = constant(ones(1,B),derivatives);
D = cell(1,10);
for j = [1:5 8], D{j} = minusAD(one,absAD(v{j})); end
% Recover bounded own horizontal speed with the same scale as o3/o4.
ownN = minusAD(timesAD(v{4},D{3}),timesAD(v{3},D{4}));
ownD = timesAD(D{3},D{4});
ownVx = signedRatio(ownN,ownD,1);
% A rational representation numerator / positive denominator is kept until
% bounding; this avoids subtracting two large inverse-normalized numbers.
exN = scaleAD(v{1},k.positionScale);
rvN = scaleAD(v{3},k.velocityScale);
eaPositiveN = minusAD(timesAD(exN,D{2}), ...
    scaleAD(timesAD(v{2},D{1}),k.aimSlope*k.heightScale));
eaN = selectAD(o(2,:)>0,eaPositiveN,exN);
eaD = selectAD(o(2,:)>0,timesAD(D{1},D{2}),D{1});
vaPositiveN = minusAD(timesAD(rvN,D{5}), ...
    scaleAD(timesAD(v{5},D{3}),k.aimSlope*k.verticalVelocityScale));
vaN = selectAD(o(2,:)>0,vaPositiveN,rvN);
vaD = selectAD(o(2,:)>0,timesAD(D{3},D{5}),D{3});
ea = signedRatio(eaN,eaD,k.approachPositionScale);
va = signedRatio(vaN,vaD,k.approachVelocityScale);
growth = signedRatio(timesAD(eaN,vaN),timesAD(eaD,vaD),k.approachProductScale);
thetaDen = o(6,:).^2+o(7,:).^2;
thetaJ = zeros(derivatives,B);
if derivatives>0
    thetaJ(6,:) = o(7,:)./thetaDen; thetaJ(7,:) = -o(6,:)./thetaDen;
end
theta = struct('v',atan2(o(6,:),o(7,:)),'j',thetaJ);
channels = {v{9},v{10},v{1},v{2},v{3},v{4},ownVx,v{5},v{6},v{7},v{8}, ...
    ea,va,growth, ...
    signedRatio(exN,D{1},k.padHalfLength), ...
    signedRatio(rvN,D{3},k.touchdownSpeedX), ...
    signedRatio(scaleAD(v{5},k.verticalVelocityScale),D{5},k.touchdownSpeedZ), ...
    signedRatio(theta,one,k.touchdownPitchTolerance), ...
    signedRatio(scaleAD(v{8},k.pitchRateScale),D{8},k.touchdownPitchRateTolerance)};
phi = zeros(19,B); J = [];
if derivatives>0, J = zeros(19,10,B); end
for j = 1:19
    phi(j,:) = channels{j}.v;
    if derivatives>0, J(j,:,:) = reshape(channels{j}.j,1,10,B); end
end
if isempty(fixedSchema), fixedSchema = landing2d.current_semantics.schema(); end
s = fixedSchema;
flat = zeros(42,B); flat(s.activeLinearIndices,:) = phi;
flat(6:6:42,:) = repmat((1:7)'/7,1,B);
X = reshape(flat,6,7,B);
assert(all(isfinite(phi),'all') && all(isfinite(J),'all') && all(abs(phi)<=1+1e-12,'all'), ...
    'landing2d:CurrentSemanticsFinite','The current-state features must remain bounded and finite.');
if nargout > 2
    detail = struct('version','current_semantics_v1','phiNames',{s.phiNames}, ...
        'nodeNames',{s.nodeNames},'activeLinearIndices',s.activeLinearIndices, ...
        'currentOnly',true,'usesHistory',false,'usesPreviousAction',false, ...
        'heightPositive',o(2,:)>0,'atHeightKink',o(2,:)==0);
end
end

function a = constant(x,derivatives)
a = struct('v',x,'j',zeros(derivatives,numel(x)));
end

function z = minusAD(a,b)
z = struct('v',a.v-b.v,'j',a.j-b.j);
end

function z = scaleAD(a,s)
z = struct('v',s*a.v,'j',s*a.j);
end

function z = timesAD(a,b)
z = struct('v',a.v.*b.v,'j',a.j.*b.v+b.j.*a.v);
end

function z = absAD(a)
% Zero is the chosen derivative of abs at its kink. In the complete softsign
% expression it yields the continuous first derivative at numerator zero.
z = struct('v',abs(a.v),'j',a.j.*sign(a.v));
end

function z = selectAD(mask,a,b)
z = b; z.v(mask) = a.v(mask); z.j(:,mask) = a.j(:,mask);
end

function z = signedRatio(n,d,s)
den = abs(n.v)+s*d.v;
assert(all(den>0),'landing2d:CurrentSemanticsDenominator','The registered feature ratio has zero denominator.');
dDen = n.j.*sign(n.v)+s*d.j;
value = n.v./den;
% Bound first, then multiply the derivative; no squared small denominator.
z = struct('v',value,'j',(n.j-value.*dDen)./den);
end
