function [coordinates,jacobian] = motionCoordinates(o)
% Same observations (ten, or eleven with the H3 acceleration entry, which passes
% through unchanged); slot 3 becomes masked normalized own horizontal speed.
% Original r = softsign(v_target-v_own), t = softsign(v_target), same scale.
% This rational form avoids explicitly inverting either near-saturated input.
assert(ismember(size(o,1),[10 11]) && all(isfinite(o),'all') && all(abs(o(3:4,:))<=1,'all'));
r = o(3,:); t = o(4,:);
A = 1-abs(r); B = 1-abs(t);
numerator = t.*A-r.*B;
denominator = A.*B+abs(numerator);
available = denominator>0;
own = zeros(size(r)); dr = own; dt = own;
own(available) = numerator(available)./denominator(available);
dr(available) = -(B(available)./denominator(available)).^2;
dt(available) = (A(available)./denominator(available)).^2;
% If both coordinates saturate exactly, their lost magnitudes cannot be
% recovered. Return a finite zero placeholder, not an invented velocity.
% At this exceptional boundary derivatives are the explicit zero convention.
coordinates = o; coordinates(3,:) = own;
jacobian = struct('relative',dr,'target',dt,'available',available);
end
