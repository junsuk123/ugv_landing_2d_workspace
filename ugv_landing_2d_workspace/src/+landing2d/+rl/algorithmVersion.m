function version = algorithmVersion()
% ALGORITHMVERSION  Behavior-changing implementation version for policies.
% Bump when code changes make a saved policy incompatible even if numeric
% configuration values are unchanged.
version = ['reward-transition-v3_fov-gradient_terminal-v1_' ...
    'relative-risk-v1_event-selection-v1'];
end
