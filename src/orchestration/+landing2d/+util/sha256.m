function hex = sha256(data)
% SHA256  SHA-256 hex digest of a character vector/string (UTF-8) or numeric bytes.
% Used for graph_hash and checkpoint_hash; landing2d.util.checksum remains the
% short non-cryptographic task fingerprint.
if ischar(data) || isstring(data)
    bytes = unicode2native(char(data),'UTF-8');
else
    bytes = uint8(data(:));
end
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(typecast(uint8(bytes(:)),'int8'));
raw = typecast(int8(digest.digest()),'uint8');
hex = lower(reshape(dec2hex(raw,2)',1,[]));
end
