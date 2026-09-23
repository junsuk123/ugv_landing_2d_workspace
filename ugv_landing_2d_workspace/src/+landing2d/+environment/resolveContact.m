function [s, contact] = resolveContact(s, xp, vp, c)
% RESOLVECONTACT  환경의 접촉 판정. 제어기 관측과 참값을 분리.
contact = struct('landed',false,'failed',false);
ex = xp - s.x;
ev = vp - s.vx;
safeTouchdown = s.mode == 1 && s.h <= c.touchdownHeight ...
    && abs(ex) <= c.padHalfLength ...
    && abs(ev) <= c.touchdownSpeedX ...
    && s.vz <= 0 && abs(s.vz) <= c.touchdownSpeedZ;
if safeTouchdown
    s.mode = 3;
    s.h = 0;
    s.vz = 0;
    s.vx = vp;
    s.heightReference = 0;
    contact.landed = true;
elseif s.mode < 3 && s.h <= 0
    s.mode = 4;
    s.h = 0;
    s.vx = 0;
    s.vz = 0;
    contact.failed = true;
end
end
