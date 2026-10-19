function hex = sha256(data)
% SHA256  SHA-256 hex digest of a character vector/string (UTF-8) or numeric bytes.
% Used for graph_hash and checkpoint_hash; landing2d.util.checksum remains the
% short non-cryptographic task fingerprint. With a JVM the Java
% MessageDigest is used; without one (thread-based parallel workers) the
% same FIPS 180-4 digest is computed in MATLAB (landing2d.orchestration.
% selfTest checks that both give identical hex strings).
if ischar(data) || isstring(data)
    bytes = unicode2native(char(data),'UTF-8');
else
    bytes = uint8(data(:));
end
bytes = uint8(bytes(:));
if usejava('jvm')
    digest = java.security.MessageDigest.getInstance('SHA-256');
    if ~isempty(bytes), digest.update(typecast(bytes,'int8')); end
    raw = typecast(int8(digest.digest()),'uint8');
else
    raw = matlabDigest(bytes);
end
hex = lower(reshape(dec2hex(raw,2)',1,[]));
end

function raw = matlabDigest(bytes)
% FIPS 180-4 SHA-256 on uint32 words (arithmetic modulo 2^32 in double).
k = uint32(hex2dec(['428a2f98';'71374491';'b5c0fbcf';'e9b5dba5';'3956c25b';'59f111f1'; ...
    '923f82a4';'ab1c5ed5';'d807aa98';'12835b01';'243185be';'550c7dc3';'72be5d74';'80deb1fe'; ...
    '9bdc06a7';'c19bf174';'e49b69c1';'efbe4786';'0fc19dc6';'240ca1cc';'2de92c6f';'4a7484aa'; ...
    '5cb0a9dc';'76f988da';'983e5152';'a831c66d';'b00327c8';'bf597fc7';'c6e00bf3';'d5a79147'; ...
    '06ca6351';'14292967';'27b70a85';'2e1b2138';'4d2c6dfc';'53380d13';'650a7354';'766a0abb'; ...
    '81c2c92e';'92722c85';'a2bfe8a1';'a81a664b';'c24b8b70';'c76c51a3';'d192e819';'d6990624'; ...
    'f40e3585';'106aa070';'19a4c116';'1e376c08';'2748774c';'34b0bcb5';'391c0cb3';'4ed8aa4a'; ...
    '5b9cca4f';'682e6ff3';'748f82ee';'78a5636f';'84c87814';'8cc70208';'90befffa';'a4506ceb'; ...
    'bef9a3f7';'c67178f2']));
h = uint32(hex2dec(['6a09e667';'bb67ae85';'3c6ef372';'a54ff53a';'510e527f';'9b05688c'; ...
    '1f83d9ab';'5be0cd19']));
bitLength = 8*numel(bytes);
padded = [bytes;uint8(128);zeros(mod(55-numel(bytes),64),1,'uint8')];
lengthBytes = zeros(8,1,'uint8');
value = bitLength;
for i = 8:-1:1
    lengthBytes(i) = uint8(mod(value,256)); value = floor(value/256);
end
padded = [padded;lengthBytes];
words = reshape(padded,4,[]);
words = uint32(words(1,:))*2^24+uint32(words(2,:))*2^16+uint32(words(3,:))*2^8+uint32(words(4,:));
for block = 1:numel(words)/16
    w = zeros(1,64,'uint32');
    w(1:16) = words((block-1)*16+(1:16));
    for t = 17:64
        s0 = bitxor(bitxor(rotr(w(t-15),7),rotr(w(t-15),18)),bitshift(w(t-15),-3));
        s1 = bitxor(bitxor(rotr(w(t-2),17),rotr(w(t-2),19)),bitshift(w(t-2),-10));
        w(t) = add32(w(t-16),s0,w(t-7),s1);
    end
    a = h(1); b = h(2); c = h(3); d = h(4); e = h(5); f = h(6); g = h(7); hh = h(8);
    for t = 1:64
        S1 = bitxor(bitxor(rotr(e,6),rotr(e,11)),rotr(e,25));
        ch = bitxor(bitand(e,f),bitand(bitcmp(e),g));
        temp1 = add32(hh,S1,ch,k(t),w(t));
        S0 = bitxor(bitxor(rotr(a,2),rotr(a,13)),rotr(a,22));
        maj = bitxor(bitxor(bitand(a,b),bitand(a,c)),bitand(b,c));
        temp2 = add32(S0,maj);
        hh = g; g = f; f = e; e = add32(d,temp1); d = c; c = b; b = a; a = add32(temp1,temp2);
    end
    h = [add32(h(1),a);add32(h(2),b);add32(h(3),c);add32(h(4),d); ...
        add32(h(5),e);add32(h(6),f);add32(h(7),g);add32(h(8),hh)];
end
raw = zeros(32,1,'uint8');
for i = 1:8
    v = double(h(i));
    raw(4*i-3:4*i) = uint8(mod(floor(v./[2^24;2^16;2^8;1]),256));
end
end

function y = rotr(x,n)
y = bitor(bitshift(x,-n),bitshift(x,32-n));
end

function y = add32(varargin)
total = 0;
for i = 1:nargin, total = total+double(varargin{i}); end
y = uint32(mod(total,2^32));
end
