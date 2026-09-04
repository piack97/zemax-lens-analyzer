function spot = computeSpotMetrics(lensData, fieldPoint, varargin)
%COMPUTESPOTMETRICS Trace pupil rays and compute image-plane spot metrics.

p = inputParser();
p.addParameter('PupilSamples', 17, @(x) isnumeric(x) && isscalar(x) && x > 1);
p.addParameter('Wavelength', NaN, @(x) isnumeric(x) && isscalar(x));
p.parse(varargin{:});
opts = p.Results;

rays = samplePupilRays(lensData, fieldPoint, opts.PupilSamples);
tr = traceSequentialRays(lensData, rays, 'Wavelength', opts.Wavelength);

pts = [];
for i = 1:numel(tr.paths)
    if tr.paths(i).valid
        pEnd = tr.paths(i).points(end, :);
        if all(isfinite(pEnd))
            pts(end + 1, :) = pEnd(1:2); %#ok<AGROW>
        end
    end
end

if isempty(pts)
    centroid = [NaN, NaN];
    rmsRadius = NaN;
else
    centroid = mean(pts, 1);
    d = pts - centroid;
    rmsRadius = sqrt(mean(sum(d.^2, 2)));
end

spot = struct('points', pts, 'centroid', centroid, 'rmsRadius', rmsRadius, 'trace', tr);
end

function rays = samplePupilRays(lensData, fieldPoint, n)
if isfield(lensData, 'system') && isfield(lensData.system, 'entrancePupilDiameter') && ~isnan(lensData.system.entrancePupilDiameter)
    radius = lensData.system.entrancePupilDiameter / 2;
else
    radius = 5;
end

u = linspace(-1, 1, n);
[X, Y] = meshgrid(u, u);
mask = (X.^2 + Y.^2) <= 1;
X = X(mask); Y = Y(mask);

rays = struct('origin', cell(1, numel(X)), 'direction', cell(1, numel(X)));
dir = normalizeVec([tand(fieldPoint(1)), tand(fieldPoint(2)), 1]);
for i = 1:numel(X)
    rays(i).origin = [radius * X(i), radius * Y(i), -1];
    rays(i).direction = dir;
end
end

function v = normalizeVec(v)
v = v ./ norm(v);
end
