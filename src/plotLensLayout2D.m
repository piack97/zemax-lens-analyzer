function ax = plotLensLayout2D(lensData, surfaceRange, varargin)
%PLOTLENSLAYOUT2D Plot y-z cross-sectional lens layout and representative rays.

if nargin < 2 || isempty(surfaceRange)
    surfaceRange = [1, numel(lensData.surfaces)];
end
opts = parseOpts(varargin{:});

[startIdx, endIdx] = validatedRange(surfaceRange, numel(lensData.surfaces));
zv = surfaceVertices(lensData.surfaces);

ax = opts.Axes;
if isempty(ax)
    ax = axes();
else
    cla(ax);
end
hold(ax, 'on');

if opts.ShadeMaterials
    drawMaterialFills(ax, lensData, zv, startIdx, endIdx, opts.LabelMaterials);
end

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
        plot(ax, p(:, 3), p(:, 2), '-', 'Color', [0.85, 0.2, 0.2]);
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
p.addParameter('Axes', [], @(x) isempty(x) || isAxesHandle(x));
p.addParameter('ShadeMaterials', false, @(x) islogical(x) && isscalar(x));
p.addParameter('LabelMaterials', false, @(x) islogical(x) && isscalar(x));
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
    xField = fieldPoints(f, 1);
    yField = fieldPoints(f, 2);
    dir = normalizeVec([tand(xField), tand(yField), 1]);
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

function drawMaterialFills(ax, lensData, zv, startIdx, endIdx, labelMaterials)
surfaces = lensData.surfaces;
if endIdx - startIdx < 1
    return;
end

materialMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
colorLut = lines(12);
nextColor = 1;

for s = startIdx:min(endIdx - 1, numel(surfaces) - 1)
    material = string(surfaces(s).material);
    if ~isGlassMaterial(material)
        continue;
    end

    key = upper(char(strtrim(material)));
    if ~isKey(materialMap, key)
        materialMap(key) = colorLut(mod(nextColor - 1, size(colorLut, 1)) + 1, :);
        nextColor = nextColor + 1;
    end
    c = materialMap(key);

    semid = inferElementSemiDiameter(surfaces(s), surfaces(s + 1));
    y = linspace(-semid, semid, 200);
    r = abs(y);
    z1 = zv(s) + conicSag(surfaces(s).curvature, surfaces(s).conic, r);
    z2 = zv(s + 1) + conicSag(surfaces(s + 1).curvature, surfaces(s + 1).conic, r);

    patch(ax, [z1, fliplr(z2)], [y, fliplr(y)], c, ...
        'FaceAlpha', 0.2, 'EdgeColor', 'none');

    if labelMaterials
        zMid = mean([mean(z1), mean(z2)]);
        text(ax, zMid, 0, key, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Color', c, ...
            'FontWeight', 'bold');
    end
end
end

function semid = inferElementSemiDiameter(surfA, surfB)
vals = [surfA.semiDiameter, surfB.semiDiameter];
vals = vals(isfinite(vals) & vals > 0);
if isempty(vals)
    semid = 10;
else
    semid = min(vals);
end
end

function tf = isGlassMaterial(material)
m = upper(strtrim(char(material)));
tf = ~(strcmp(m, 'AIR') || strcmp(m, 'VACUUM') || strcmp(m, ''));
end

function tf = isAxesHandle(x)
tf = isa(x, 'matlab.graphics.axis.Axes') || isa(x, 'matlab.ui.control.UIAxes');
end
