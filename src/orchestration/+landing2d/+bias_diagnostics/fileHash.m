function digest = fileHash(file)
% FILEHASH SHA-256 of a file's bytes (landing2d.util.sha256).
fid = fopen(file,'r'); assert(fid>=0,'landing2d:BiasDiagnosticsFile','Cannot read %s.',file);
bytes = fread(fid,'*uint8'); fclose(fid);
digest = landing2d.util.sha256(bytes);
end
