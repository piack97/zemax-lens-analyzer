function ax = plotRmsSpotColormap(lensData, varargin)
%PLOTRMSSPOTCOLORMAP Plot RMS spot radius over sampled field grid.

p = inputParser();
p.addParameter('GridSize', [9 9], @(x) isnumeric(x) && numel(x) == 2);
p.addParameter('FieldRangeX', [], @(x) isnumeric(x) && numel(x) == 2);
p.addParameter('FieldRangeY', [], @(x) isnumeric(x) && numel(x) == 2);
p.addParameter('PupilSamples', 13, @(x) isnumeric(x) && isscalar(x) && x > 1);
p.addParameter('Wavelength', NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter('Units', 'RMS', @(x) ischar(x) || isstring(x));
p.addParameter('Axes', [], @(x) isempty(x) || isAxesHandle(x));
p.parse(varargin{:});
opts = p.Results;

[fxRange, fyRange] = inferFieldRanges(lensData, opts.FieldRangeX, opts.FieldRangeY);

nx = max(2, round(opts.GridSize(1)));
ny = max(2, round(opts.GridSize(2)));
fx = linspace(fxRange(1), fxRange(2), nx);
fy = linspace(fyRange(1), fyRange(2), ny);
[FX, FY] = meshgrid(fx, fy);
RMS = zeros(size(FX));

for i = 1:numel(FX)
    spot = computeSpotMetrics(lensData, [FX(i), FY(i)], 'PupilSamples', opts.PupilSamples, 'Wavelength', opts.Wavelength);
    RMS(i) = spot.rmsRadius;
end

units = char(opts.Units);
if strcmpi(units, 'FWHM')
    C = rmsSpotToGaussianFWHM(RMS);
    ttl = 'FWHM Spot Diameter Colormap';
    cbarLabel = 'FWHM (mm)';
elseif strcmpi(units, 'RMS')
    C = RMS;
    ttl = 'RMS Spot Radius Colormap';
    cbarLabel = 'RMS Radius (mm)';
else
    error('plotRmsSpotColormap:InvalidUnits', 'Units must be ''RMS'' or ''FWHM''.');
end

ax = opts.Axes;
if isempty(ax)
    ax = axes();
else
    cla(ax);
end
oldCb = getappdata(ax, 'plotRmsSpotColormapColorbar');
if ~isempty(oldCb) && isgraphics(oldCb)
    delete(oldCb);
end
imagesc(ax, fx, fy, C);
set(ax, 'YDir', 'normal');
axis(ax, 'image');
cb = colorbar(ax);
cb.Tag = 'plotRmsSpotColormapColorbar';
setappdata(ax, 'plotRmsSpotColormapColorbar', cb);
ylabel(cb, cbarLabel);
xlabel(ax, 'Field X'); ylabel(ax, 'Field Y');
title(ax, ttl);
end

function [fxRange, fyRange] = inferFieldRanges(lensData, inX, inY)
if ~isempty(inX)
    fxRange = inX;
else
    if isfield(lensData, 'system') && isfield(lensData.system, 'fieldPoints') && ~isempty(lensData.system.fieldPoints)
        f = lensData.system.fieldPoints(:, 1);
        fxRange = [min(f), max(f)];
    else
        fxRange = [-1, 1];
    end
end

if ~isempty(inY)
    fyRange = inY;
else
    if isfield(lensData, 'system') && isfield(lensData.system, 'fieldPoints') && ~isempty(lensData.system.fieldPoints)
        f = lensData.system.fieldPoints(:, 2);
        fyRange = [min(f), max(f)];
    else
        fyRange = [-1, 1];
    end
end
end

function tf = isAxesHandle(x)
tf = isa(x, 'matlab.graphics.axis.Axes') || isa(x, 'matlab.ui.control.UIAxes');
end
