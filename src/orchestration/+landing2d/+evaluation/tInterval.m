function [mu,sd,half,n] = tInterval(x)
% TINTERVAL  Mean, standard deviation and 95% Student-t half width of the finite values.
x = double(x(:)); x = x(isfinite(x)); n = numel(x);
mu = NaN; sd = NaN; half = NaN;
if n == 0, return; end
mu = mean(x);
if n > 1
    sd = std(x);
    half = quantile975(n-1)*sd/sqrt(n);
end
end

function q = quantile975(df)
% Two-sided 95% Student-t quantile (no toolbox): table to 30, then z + 2.372/df.
table = [12.706,4.303,3.182,2.776,2.571,2.447,2.365,2.306,2.262,2.228, ...
    2.201,2.179,2.160,2.145,2.131,2.120,2.110,2.101,2.093,2.086, ...
    2.080,2.074,2.069,2.064,2.060,2.056,2.052,2.048,2.045,2.042];
if df <= 30, q = table(df); else, q = 1.959964+2.372/df; end
end
