function T = printHeadline(results)
% PRINTHEADLINE  Print the seed-paired key contrasts (landing2d.evaluation.headlineContrasts).
% Each line: contrast, mean difference over training seeds, 95% t interval,
% number of seeds and how many seeds favour A. With one seed the interval is
% NaN and no method claim is possible.
T = landing2d.evaluation.headlineContrasts(results);
if isempty(T), return; end
fprintf('\nHeadline contrasts (A - B, paired by training seed)\n');
for i = 1:height(T)
    fprintf('  %-52s %-34s %+8.4f +/- %-8.4f n=%d, A>B in %d\n',T.Quantity(i), ...
        T.Contrast(i),T.Delta(i),T.CI(i),T.Seeds(i),T.Positive(i));
end
end
