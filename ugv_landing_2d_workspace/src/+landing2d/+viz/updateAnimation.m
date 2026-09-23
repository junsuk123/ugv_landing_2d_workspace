function updateAnimation(live, results, k, c)
for j = 1:numel(results)
    r = results(j); ax = live.axes(j); h = live.items(j);
    xd = r.xDrone(k); zd = r.zDrone(k); xp = r.xUgv(k);
    width = r.fovHalfWidth(k);
    set(h.fov, 'XData', [xd,xd-width,xd+width], ...
        'YData', [zd,c.padHeight,c.padHeight]);
    left = min(xd-width, xp-1) - 4;
    right = max(xd+width, xp+1) + 4;
    center = (left + right) / 2;
    span = max(24, right-left);
    limits = center + [-0.5,0.5] * span;
    xlim(ax, limits);
    set(h.ground, 'XData', limits, 'YData', [0,0]);
    set(h.ugv, 'Position', [xp-0.9,0,1.8,c.padHeight]);
    set(h.pad, 'XData', xp + [-c.padHalfLength,c.padHalfLength], ...
        'YData', [c.padHeight,c.padHeight]);
    set(h.drone, 'XData', xd + [-0.55,0,0.55], 'YData', [zd,zd,zd]);
    first = max(1, k-round(12/c.dt));
    set(h.trail, 'XData', r.xDrone(first:k), 'YData', r.zDrone(first:k));
    labels = {'TRACK / ALIGN','SEARCH / CLIMB','LANDED','FAILED'};
    modeText = labels{r.mode(k)};
    if r.mode(k) == 1 && r.descending(k)
        modeText = 'TRACK / DESCEND';
    end
    if r.mode(k) >= 3
        visibility = 'N/A';
    elseif r.visible(k)
        visibility = 'VISIBLE';
    else
        visibility = 'LOST';
    end
    set(h.info, 'String', sprintf(['t = %.2f s | %s\nPad: %s\n' ...
        'vUGV = %.2f m/s | vDrone = %.2f m/s\n' ...
        'x error = %.2f m | height above pad = %.2f m'], ...
        r.time(k),modeText,visibility,r.vxUgv(k),r.vxDrone(k), ...
        r.xError(k),zd-c.padHeight));
    id = r.segmentId(k);
    title(ax, sprintf('%s | S%d | target %.2g m/s', ...
        r.name,id,r.speeds(id)), 'Color', 0.7*c.segmentColors(id,:));
end
end
