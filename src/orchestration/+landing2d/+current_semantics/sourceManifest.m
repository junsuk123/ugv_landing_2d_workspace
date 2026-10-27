function sources = sourceManifest(root)
% SOURCEMANIFEST Freeze code, public entry points, and research contracts.
files=[dir(fullfile(root,'src','**','*.m'));dir(fullfile(root,'*.m')); ...
    dir(fullfile(root,'docs','**','*.md'));dir(fullfile(root,'tools','**','*.py'))];
paths=arrayfun(@(f)fullfile(f.folder,f.name),files,'UniformOutput',false);
if isfile(fullfile(root,'AGENTS.md')), paths{end+1}=fullfile(root,'AGENTS.md'); end
if isfile(fullfile(root,'README.md')), paths{end+1}=fullfile(root,'README.md'); end
paths=sort(unique(paths));
sources=struct('path',{},'sha256',{});
for k=1:numel(paths)
    relative=string(paths{k}); prefix=string(root)+filesep;
    assert(startsWith(relative,prefix)); relative=extractAfter(relative,strlength(prefix));
    sources(k)=struct('path',strrep(relative,'\','/'), ...
        'sha256',string(landing2d.bias_diagnostics.fileHash(paths{k}))); %#ok<AGROW>
end
end
