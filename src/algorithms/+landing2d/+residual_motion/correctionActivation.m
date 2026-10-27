function [y,slope] = correctionActivation(z,kind)
% CORRECTIONACTIVATION Activation of the residual correction branch and its derivative.
%   'tanh'            y = tanh(z),               slope = 1 - y.^2   (v3-v5)
%   'soft_linear_v1'  y = 0.9 tanh(z) + 0.1 z,   slope = 0.9 (1 - tanh(z).^2) + 0.1
%                     (relational_residual_v6 / C1: same sign and odd symmetry,
%                     slope >= 0.1, so the correction does not saturate)
% The tanh case uses the same floating-point expressions as the earlier code.
t = tanh(z);
switch kind
    case 'tanh'
        y = t; slope = 1-y.^2;
    case 'soft_linear_v1'
        y = 0.9*t+0.1*z; slope = 0.9*(1-t.^2)+0.1;
    otherwise
        error('landing2d:CorrectionActivation','Unknown correction activation %s.',kind);
end
end
