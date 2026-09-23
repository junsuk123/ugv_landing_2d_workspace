function live = createAnimation(c, nCases)
live.fig = figure('Name', '2D UGV landing - live', 'NumberTitle', 'off', ...
    'Position', [70, 100, 1400, 620], 'Color', 'w');
layout = tiledlayout(live.fig, 1, nCases, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'PD tracking / FOV loss / climb / reacquisition / landing');
for j = 1:nCases
    ax = nexttile(layout);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    palette = ax.ColorOrder;
    h.fov = patch(ax, NaN, NaN, palette(1,:), 'FaceAlpha', 0.10, ...
        'EdgeColor', palette(1,:), 'LineStyle', ':', 'HandleVisibility', 'off');
    h.ground = plot(ax, NaN, NaN, '-', 'HandleVisibility', 'off');
    h.trail = plot(ax, NaN, NaN, '-', 'LineWidth', 1.2, 'DisplayName', 'Drone path');
    h.ugv = rectangle(ax, 'Position', [0,0,1.8,c.padHeight], ...
        'LineWidth', 1.5, 'HandleVisibility', 'off');
    h.pad = plot(ax, NaN, NaN, '-', 'LineWidth', 5, 'DisplayName', 'Landing pad');
    h.drone = plot(ax, NaN, NaN, '-o', 'LineWidth', 2, ...
        'MarkerSize', 5, 'DisplayName', 'Drone');
    h.info = text(ax, 0.03, 0.97, '', 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'Interpreter', 'none', 'FontSize', 10);
    xlabel(ax, 'Forward position x [m]'); ylabel(ax, 'Altitude z [m]');
    title(ax, sprintf('Scenario %d: %.1f / %.1f / %.1f m/s', ...
        j, c.scenarioSpeeds(j,:)));
    daspect(ax, [1,1,1]);
    ylim(ax, [0, c.padHeight + c.maxHeight + 4]);
    xlim(ax, [-8, 16]);
    legend(ax, [h.trail, h.pad, h.drone], 'Location', 'southoutside');
    live.axes(j) = ax;
    live.items(j) = h;
end
end
