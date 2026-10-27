function verifySources(root,registered)
% VERIFYSOURCES Refuse both modified and newly added registered-scope files.
current=landing2d.current_semantics.sourceManifest(root);
assert(numel(current)==numel(registered),'landing2d:CurrentSemanticsSource','The registered source inventory changed.');
[~,ia]=sort(string({current.path})); [~,ib]=sort(string({registered.path}));
for k=1:numel(current)
    a=current(ia(k)); b=registered(ib(k));
    assert(strcmp(a.path,b.path) && strcmp(a.sha256,b.sha256), ...
        'landing2d:CurrentSemanticsSource','Registered source differs at %s.',a.path);
end
end
