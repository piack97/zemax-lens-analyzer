function traceResult = traceSequentialRays(lensData, rays, varargin)
%TRACESEQUENTIALRAYS Non-paraxial sequential ray tracing for parsed Zemax data.

opts = parseOptions(varargin{:});
validateattributes(rays, {'struct'}, {'nonempty'}, mfilename, 'rays');

numRays = numel(rays);
numSurfaces = numel(lensData.surfaces);
if numSurfaces < 1
    error('traceSequentialRays:NoSurfaces', 'lensData.surfaces is empty.');
end

surfaceZ = zeros(1, numSurfaces);
for i = 2:numSurfaces
    surfaceZ(i) = surfaceZ(i - 1) + lensData.surfaces(i - 1).thickness;
end

wavelength = opts.wavelength;
if isnan(wavelength)
    if isfield(lensData, 'system') && isfield(lensData.system, 'wavelengths') && ~isempty(lensData.system.wavelengths)
        wavelength = lensData.system.wavelengths(1);
    else
        wavelength = 0.55;
    end
end

materials = cell(1, numSurfaces);
for i = 1:numSurfaces
    materials{i} = lensData.surfaces(i).material;
end

traceResult = struct();
traceResult.wavelength = wavelength;
traceResult.surfaceZ = surfaceZ;
traceResult.paths = repmat(struct('points', zeros(numSurfaces + 1, 3), ...
    'directions', zeros(numSurfaces + 1, 3), ...
    'valid', true, ...
    'failureReason', ''), 1, numRays);

for r = 1:numRays
    pos = rays(r).origin(:).';
    dir = normalizeVec(rays(r).direction(:).');

    rayPathPoints = zeros(numSurfaces + 1, 3);
    rayPathDirs = zeros(numSurfaces + 1, 3);
    rayPathPoints(1, :) = pos;
    rayPathDirs(1, :) = dir;

    nBefore = getMaterialIndex('AIR', wavelength, opts.glassModel);
    valid = true;
    reason = '';

    for s = 1:numSurfaces
        surf = lensData.surfaces(s);
        zVertex = surfaceZ(s);

        [hitPoint, normal, hitOk] = intersectSurface(pos, dir, surf, zVertex);
        if ~hitOk
            valid = false;
            reason = sprintf('Ray missed surface %d.', surf.number);
            break;
        end
        if isfinite(surf.semiDiameter) && surf.semiDiameter > 0
            if hypot(hitPoint(1), hitPoint(2)) > surf.semiDiameter
                valid = false;
                reason = sprintf('Ray vignetted at surface %d.', surf.number);
                break;
            end
        end

        nAfter = getMaterialIndex(materials{s}, wavelength, opts.glassModel);
        [refractedDir, refractOk] = refractDirection(dir, normal, nBefore, nAfter);
        if ~refractOk
            valid = false;
            reason = sprintf('Total internal reflection at surface %d.', surf.number);
            break;
        end

        pos = hitPoint;
        dir = normalizeVec(refractedDir);
        nBefore = nAfter;

        rayPathPoints(s + 1, :) = pos;
        rayPathDirs(s + 1, :) = dir;
    end

    traceResult.paths(r).points = rayPathPoints;
    traceResult.paths(r).directions = rayPathDirs;
    traceResult.paths(r).valid = valid;
    traceResult.paths(r).failureReason = reason;
end
end

function opts = parseOptions(varargin)
parser = inputParser();
parser.addParameter('Wavelength', NaN, @(x) isnumeric(x) && isscalar(x));
parser.addParameter('GlassModel', defaultGlassModel(), @isstruct);
parser.parse(varargin{:});
opts = struct('wavelength', parser.Results.Wavelength, 'glassModel', parser.Results.GlassModel);
end

function [hitPoint, normal, ok] = intersectSurface(pos, dir, surf, zVertex)
ok = true;
hitPoint = [NaN, NaN, NaN];
normal = [0, 0, 1];

c = surf.curvature;
k = surf.conic;

if abs(c) < 1e-12
    if abs(dir(3)) < 1e-12
        ok = false;
        return;
    end
    t = (zVertex - pos(3)) / dir(3);
    if t <= 0
        ok = false;
        return;
    end
    hitPoint = pos + t * dir;
    normal = [0, 0, 1];
    return;
end

% Newton solve for conic/spherical sag intersection in local coordinates.
den = dir(3);
if abs(den) < 1e-6
    den = signOrOne(den) * 1e-6;
end
t = max((zVertex - pos(3)) / den, 1e-6);
for it = 1:30
    p = pos + t * dir;
    x = p(1);
    y = p(2);
    z = p(3);
    r = hypot(x, y);
    sag = conicSag(c, k, r);
    f = z - zVertex - sag;

    if abs(f) < 1e-9
        hitPoint = p;
        break;
    end

    dt = 1e-6 * max(1, abs(t));
    p2 = pos + (t + dt) * dir;
    r2 = hypot(p2(1), p2(2));
    f2 = p2(3) - zVertex - conicSag(c, k, r2);
    dfdT = (f2 - f) / dt;
    if abs(dfdT) < 1e-14
        ok = false;
        return;
    end
    tNext = t - f / dfdT;
    if ~isfinite(tNext)
        ok = false;
        return;
    end
    t = tNext;
end

if any(~isfinite(hitPoint)) || t <= 0
    ok = false;
    return;
end

x = hitPoint(1);
y = hitPoint(2);
r = hypot(x, y);
dsag = dSagDr(c, k, r);
if r > 1e-12
    normal = [-dsag * x / r, -dsag * y / r, 1];
else
    normal = [0, 0, 1];
end
normal = normalizeVec(normal);
end

function sag = conicSag(c, k, r)
rootTerm = 1 - (1 + k) * (c^2) * (r^2);
if rootTerm < 0
    rootTerm = 0;
end
sag = (c * r^2) / (1 + sqrt(rootTerm));
end

function val = dSagDr(c, k, r)
if r < 1e-12
    val = 0;
    return;
end
h = 1e-6 * max(1, r);
val = (conicSag(c, k, r + h) - conicSag(c, k, r - h)) / (2 * h);
end

function [t, ok] = refractDirection(i, n, n1, n2)
ok = true;
i = normalizeVec(i);
n = normalizeVec(n);

if dot(i, n) > 0
    n = -n;
end

eta = n1 / n2;
cosI = -dot(n, i);
k = 1 - eta^2 * (1 - cosI^2);
if k < 0
    t = [NaN, NaN, NaN];
    ok = false;
    return;
end

t = eta * i + (eta * cosI - sqrt(k)) * n;
t = normalizeVec(t);
end

function n = getMaterialIndex(glassName, wavelengthUm, glassModel)
if nargin < 1 || isempty(glassName)
    glassName = 'AIR';
end
key = upper(strtrim(glassName));
if isfield(glassModel, key)
    entry = glassModel.(key);
    if isstruct(entry) && isfield(entry, 'wavelength') && isfield(entry, 'index')
        n = interp1(entry.wavelength, entry.index, wavelengthUm, 'linear', 'extrap');
    else
        n = entry;
    end
else
    n = 1.5; % graceful fallback for unknown glasses
end
if strcmp(key, 'AIR')
    n = 1.0;
end
end

function model = defaultGlassModel()
model = struct();
model.AIR = 1.0;
model.BK7 = struct('wavelength', [0.4861, 0.5876, 0.6563], 'index', [1.52238, 1.51680, 1.51432]);
model.F2 = struct('wavelength', [0.4861, 0.5876, 0.6563], 'index', [1.63208, 1.62004, 1.61503]);
model.SF11 = struct('wavelength', [0.4861, 0.5876, 0.6563], 'index', [1.80610, 1.78472, 1.77611]);
end

function v = normalizeVec(v)
nrm = norm(v);
if nrm < eps
    v = [0, 0, 1];
else
    v = v ./ nrm;
end
end

function s = signOrOne(x)
if x < 0
    s = -1;
else
    s = 1;
end
end
