function [code,names] = supervisorReasonCode(reasons)
% SUPERVISORREASONCODE  Safety-supervisor reason -> uint8 log code (0 = no reason).
% landing2d.control.safetySupervisor reports at most one reason per call; the
% code indexes NAMES. Logging only; it never changes the applied command.
names = {'recovery_backup','descent_inhibited','vertical_stopping_margin'};
code = uint8(0);
if isempty(reasons), return; end
assert(numel(reasons) == 1,'landing2d:SupervisorReason', ...
    'The supervisor reports at most one reason per physics step.');
index = find(strcmp(names,reasons{1}),1);
assert(~isempty(index),'landing2d:SupervisorReason', ...
    'Unregistered supervisor reason %s.',reasons{1});
code = uint8(index);
end
