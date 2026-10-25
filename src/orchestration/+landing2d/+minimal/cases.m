function cases = cases(c)
% CASES One reference and two single-factor interventions, fixed before training.
% Same initial state, noise seeds, event time and horizon in all three cases.
allCases = landing2d.evaluation.factorialCases(c);
cases = allCases(1:3);
end
