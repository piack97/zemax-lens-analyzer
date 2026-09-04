function ax = plotLensLayout2D(lensData, surfaceRange, varargin)
%PLOTLENSLAYOUT2D Plot y-z cross-sectional lens layout and representative rays.

if nargin < 2 || isempty(surfaceRange)
    surfaceRange = [1, numel(lensData.surfaces)];
end
opts = parseOpts(varargin{:});

[startIdx, endIdx] = validatedRange(surfaceRange, numel(lensData.surfaces));
zv = surfaceVertices(lensData.surfaces);

ax = axes(); hold(ax, 'on');
for s = startIdx:endIdx
    surf = lensData.surfaces(s);
    semid = surf.semiDiameter;
    if isnan(semid) || semid <= 0
        semid = 10;
    end
    y = linspace(-semid, semid, 200);
    r = abs(y);
    z = zv(s) + conicSag(surf.curvature, surf.conic, r);
    plot(ax, z, y, 'k-', 'LineWidth', 1.1);
end

rays = generateRepresentativeRays(lensData, opts.NumRays, opts.FieldPoints);
tr = traceSequentialRays(lensData, rays, 'Wavelength', opts.Wavelength);
for i = 1:numel(tr.paths)
    p = tr.paths(i).points;
    valid = all(isfinite(p), 2);
    p = p(valid, :);
    if size(p, 1) > 1
        plot(ax, p(:, 3), p(:, 2), '-', 'Color', [0.85, 0.2, 0.2, 0.65]);
    end
end

xlabel(ax, 'z (mm)'); ylabel(ax, 'y (mm)');
title(ax, '2D Lens Layout'); axis(ax, 'equal'); grid(ax, 'on');
end

function opts = parseOpts(varargin)
p = inputParser();
p.addParameter('NumRays', 7, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter('FieldPoints', [], @(x) isnumeric(x) && size(x, 2) == 2);
p.addParameter('Wavelength', NaN, @(x) isnumeric(x) && isscalar(x));
p.parse(varargin{:});
opts = p.Results;
end

function [startIdx, endIdx] = validatedRange(surfaceRange, n)
startIdx = max(1, min(n, round(surfaceRange(1))));
endIdx = max(1, min(n, round(surfaceRange(2))));
if endIdx < startIdx
    tmp = startIdx; startIdx = endIdx; endIdx = tmp;
end
end

function z = surfaceVertices(surfaces)
z = zeros(1, numel(surfaces));
for i = 2:numel(surfaces)
    z(i) = z(i - 1) + surfaces(i - 1).thickness;
end
end

function rays = generateRepresentativeRays(lensData, nRays, fieldPoints)
if isempty(fieldPoints)
    if isfield(lensData, 'system') && isfield(lensData.system, 'fieldPoints') && ~isempty(lensData.system.fieldPoints)
        fieldPoints = lensData.system.fieldPoints;
    else
        fieldPoints = [0, 0];
    end
end

epd = 10;
if isfield(lensData, 'system') && isfield(lensData.system, 'entrancePupilDiameter') && ~isnan(lensData.system.entrancePupilDiameter)
    epd = lensData.system.entrancePupilDiameter;
end

ys = linspace(-epd / 2, epd / 2, nRays);
z0 = -1;
idx = 0;
rays = struct('origin', {}, 'direction', {});
for f = 1:size(fieldPoints, 1)
    ax = fieldPoints(f, 1);
    ay = fieldPoints(f, 2);
    dir = normalizeVec([tand(ax), tand(ay), 1]);
    for j = 1:numel(ys)
        idx = idx + 1;
        rays(idx).origin = [0, ys(j), z0]; %#ok<AGROW>
        rays(idx).direction = dir; %#ok<AGROW>
    end
end
end

function sag = conicSag(c, k, r)
if abs(c) < 1e-12
    sag = zeros(size(r));
    return;
end
rootTerm = 1 - (1 + k) .* (c.^2) .* (r.^2);
rootTerm(rootTerm < 0) = 0;
sag = (c .* (r.^2)) ./ (1 + sqrt(rootTerm));
end

function v = normalizeVec(v)
v = v ./ norm(v);
end
