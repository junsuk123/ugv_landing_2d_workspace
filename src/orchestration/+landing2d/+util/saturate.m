function y = saturate(x, limit)
y = min(max(x, -limit), limit);
end
