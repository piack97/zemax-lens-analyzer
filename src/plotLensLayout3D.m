function ax = plotLensLayout3D(lensData, surfaceRange, varargin)
%PLOTLENSLAYOUT3D Plot 3D revolved surfaces and traced rays.

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
view(ax, 3);
materialColors = buildMaterialColors(lensData.surfaces);
for s = startIdx:endIdx
    surfaceDef = lensData.surfaces(s);
    semid = surfaceDef.semiDiameter;
    if isnan(semid) || semid <= 0
        semid = 10;
    end
    rho = linspace(0, semid, 70);
    th = linspace(0, 2 * pi, 80);
    [R, T] = meshgrid(rho, th);
    X = R .* cos(T);
    Y = R .* sin(T);
    Z = zv(s) + conicSag(surfaceDef.curvature, surfaceDef.conic, R);
    matKey = upper(strtrim(surfaceDef.material));
    if isKey(materialColors, matKey)
        fc = materialColors(matKey);
    else
        fc = [0.3, 0.5, 0.85];
    end
    surf(ax, Z, X, Y, 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'FaceColor', fc);
end

rays = generateRays(lensData, opts.NumRays, opts.FieldPoints);
tr = traceSequentialRays(lensData, rays, 'Wavelength', opts.Wavelength);
for i = 1:numel(tr.paths)
    p = tr.paths(i).points;
    valid = all(isfinite(p), 2);
    p = p(valid, :);
    if size(p, 1) > 1
        plot3(ax, p(:, 3), p(:, 1), p(:, 2), 'r-', 'LineWidth', 1.0);
    end
end

xlabel(ax, 'z (mm)'); ylabel(ax, 'x (mm)'); zlabel(ax, 'y (mm)');
title(ax, '3D Lens Layout'); grid(ax, 'on'); axis(ax, 'equal');
end

function opts = parseOpts(varargin)
p = inputParser();
p.addParameter('NumRays', 24, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter('FieldPoints', [], @(x) isnumeric(x) && size(x, 2) == 2);
p.addParameter('Wavelength', NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter('Axes', [], @(x) isempty(x) || isAxesHandle(x));
p.parse(varargin{:});
opts = p.Results;
end

function [startIdx, endIdx] = validatedRange(surfaceRange, n)
startIdx = max(1, min(n, round(surfaceRange(1))));
endIdx = max(1, min(n, round(surfaceRange(2))));
if endIdx < startIdx
    t = startIdx; startIdx = endIdx; endIdx = t;
end
end

function z = surfaceVertices(surfaces)
z = zeros(1, numel(surfaces));
for i = 2:numel(surfaces)
    z(i) = z(i - 1) + surfaces(i - 1).thickness;
end
end

function rays = generateRays(lensData, nRays, fieldPoints)
if isempty(fieldPoints)
    if isfield(lensData, 'system') && isfield(lensData.system, 'fieldPoints') && ~isempty(lensData.system.fieldPoints)
        fieldPoints = lensData.system.fieldPoints;
    else
        fieldPoints = [0, 0];
    end
end

if isfield(lensData, 'system') && isfield(lensData.system, 'entrancePupilDiameter') && ~isnan(lensData.system.entrancePupilDiameter)
    epd = lensData.system.entrancePupilDiameter;
else
    epd = 10;
end

rings = max(2, ceil(sqrt(nRays)));
radii = linspace(0, epd / 2, rings);
angles = linspace(0, 2 * pi, rings * 4 + 1); angles(end) = [];
idx = 0;
rays = struct('origin', {}, 'direction', {});
for f = 1:size(fieldPoints, 1)
    d = normalizeVec([tand(fieldPoints(f, 1)), tand(fieldPoints(f, 2)), 1]);
    for ir = 1:numel(radii)
        rr = radii(ir);
        for ia = 1:numel(angles)
            idx = idx + 1;
            rays(idx).origin = [rr * cos(angles(ia)), rr * sin(angles(ia)), -1]; %#ok<AGROW>
            rays(idx).direction = d; %#ok<AGROW>
            if idx >= nRays * size(fieldPoints, 1)
                break;
            end
        end
        if idx >= nRays * size(fieldPoints, 1)
            break;
        end
    end
end
end

function sag = conicSag(c, k, r)
if abs(c) < 1e-12
    sag = zeros(size(r));
    return;
end
rootTerm = 1 - (1 + k) .* c.^2 .* r.^2;
rootTerm(rootTerm < 0) = 0;
sag = (c .* r.^2) ./ (1 + sqrt(rootTerm));
end

function v = normalizeVec(v)
v = v ./ norm(v);
end

function cmap = buildMaterialColors(surfaces)
cmap = containers.Map('KeyType', 'char', 'ValueType', 'any');
colors = lines(12);
next = 1;
for i = 1:numel(surfaces)
    m = upper(strtrim(surfaces(i).material));
    if strcmp(m, 'AIR') || strcmp(m, 'VACUUM') || strcmp(m, '')
        c = [0.85, 0.85, 0.9];
    else
        c = colors(mod(next - 1, size(colors, 1)) + 1, :);
        next = next + 1;
    end
    if ~isKey(cmap, m)
        cmap(m) = c;
    end
end
end

function tf = isAxesHandle(x)
tf = isa(x, 'matlab.graphics.axis.Axes') || isa(x, 'matlab.ui.control.UIAxes');
end
