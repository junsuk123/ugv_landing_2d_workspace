function writeJson(file,value)
% WRITEJSON UTF-8 JSON output, with checked write completion.
fid=fopen(file,'w','n','UTF-8');
assert(fid>=0,'landing2d:CurrentSemanticsFile','Cannot write %s.',file);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=unicode2native(jsonencode(value,'PrettyPrint',true),'UTF-8');
written=fwrite(fid,bytes,'uint8');
assert(written==numel(bytes),'landing2d:CurrentSemanticsFile','Incomplete write: %s.',file);
end
