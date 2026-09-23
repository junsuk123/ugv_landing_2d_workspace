function id = checksum(values)
% CHECKSUM  숫자 배열에 대한 짧은 결정론적 식별자. 설계 결과 추적용입니다.
% 암호학적 해시가 아니며, 같은 설계가 같은 문자열을 갖게 하는 용도입니다.
bytes = typecast(double(values(:))','uint8');
h = 5381;
for i = 1:numel(bytes)
    h = mod(h*33+double(bytes(i)),4294967296);
end
id = lower(dec2hex(h,8));
end
