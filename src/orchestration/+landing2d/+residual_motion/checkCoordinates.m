function report = checkCoordinates()
% TEST ONLY: stable physical coordinate mapping, finite differences, missingness.
rs = RandStream('threefry','Seed',74394);
o = .97*tanh(randn(rs,10,100));
[q,jacobian] = landing2d.residual_motion.motionCoordinates(o);
unscale = @(z) z./(1-abs(z));
own = unscale(o(4,:))-unscale(o(3,:));
expected = own./(1+abs(own));
maximumAlgebraError = max(abs(q(3,:)-expected));
relative = unscale(q(4,:))-unscale(q(3,:));
maximumRoundtripError = max(abs(relative./(1+abs(relative))-o(3,:)));
assert(maximumAlgebraError<1e-12 && maximumRoundtripError<1e-12);
assert(isequal(q([1 2 4:10],:),o([1 2 4:10],:)) && all(jacobian.available));
dq = randn(rs,size(q)); dx = landing2d.residual_motion.motionCoordinatesBackward(dq,jacobian);
step = 1e-6; maximumDerivativeError = 0;
for k = 1:numel(o)
    plus = o; minus = o; plus(k) = plus(k)+step; minus(k) = minus(k)-step;
    yp = landing2d.residual_motion.motionCoordinates(plus);
    ym = landing2d.residual_motion.motionCoordinates(minus);
    numerical = sum((yp-ym).*dq,'all')/(2*step);
    maximumDerivativeError = max(maximumDerivativeError,abs(numerical-dx(k)));
end
assert(maximumDerivativeError<2e-7);
missing = o; missing(1:4,:) = 0; missing(9,:) = 0; missing(10,:) = 1;
mapped = landing2d.residual_motion.motionCoordinates(missing);
assert(isequal(mapped,missing),'Missing own velocity must remain a masked zero placeholder.');
boundary = zeros(10,4); boundary(3,:) = [-1 -1 1 1]; boundary(4,:) = [-1 1 -1 1];
[mapped,boundaryJacobian] = landing2d.residual_motion.motionCoordinates(boundary);
assert(all(isfinite(mapped),'all') && all(mapped(3,:)==0) && ~any(boundaryJacobian.available));
assert(all(boundaryJacobian.relative==0) && all(boundaryJacobian.target==0));
report = struct('testOnly',true,'maximumAlgebraError',maximumAlgebraError, ...
    'maximumRoundtripError',maximumRoundtripError,'maximumDerivativeError',maximumDerivativeError, ...
    'missingPreserved',true,'finiteSaturationConvention',true,'passed',true);
end
