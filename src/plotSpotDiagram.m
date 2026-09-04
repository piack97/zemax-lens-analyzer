function axs = plotSpotDiagram(lensData, fieldPoint, varargin)
%PLOTSPOTDIAGRAM Plot geometric spot diagram(s) for one or more field points.

if nargin < 2 || isempty(fieldPoint)
    if isfield(lensData, 'system') && isfield(lensData.system, 'fieldPoints') && ~isempty(lensData.system.fieldPoints)
        fieldPoint = lensData.system.fieldPoints;
    else
        fieldPoint = [0, 0];
    end
end

if size(fieldPoint, 2) ~= 2
    error('plotSpotDiagram:InvalidFieldPoint', 'fieldPoint must be Nx2 [xField yField].');
end

p = inputParser();
p.addParameter('PupilSamples', 17, @(x) isnumeric(x) && isscalar(x) && x > 1);
p.addParameter('Wavelength', NaN, @(x) isnumeric(x) && isscalar(x));
p.addParameter('ShowAiryDisk', false, @(x) islogical(x) && isscalar(x));
p.addParameter('AiryRadius', NaN, @(x) isnumeric(x) && isscalar(x));
p.parse(varargin{:});
opts = p.Results;

nFields = size(fieldPoint, 1);
gridCols = ceil(sqrt(nFields));
gridRows = ceil(nFields / gridCols);
axs = gobjects(nFields, 1);

for i = 1:nFields
    axs(i) = subplot(gridRows, gridCols, i);
    hold(axs(i), 'on');

    spot = computeSpotMetrics(lensData, fieldPoint(i, :), 'PupilSamples', opts.PupilSamples, 'Wavelength', opts.Wavelength);
    scatter(axs(i), spot.points(:, 1), spot.points(:, 2), 12, 'filled', 'MarkerFaceAlpha', 0.45);
    plot(axs(i), spot.centroid(1), spot.centroid(2), 'kx', 'MarkerSize', 8, 'LineWidth', 1.2);

    if opts.ShowAiryDisk && isfinite(opts.AiryRadius) && opts.AiryRadius > 0
        th = linspace(0, 2 * pi, 200);
        plot(axs(i), spot.centroid(1) + opts.AiryRadius * cos(th), ...
            spot.centroid(2) + opts.AiryRadius * sin(th), 'k--');
    end

    title(axs(i), sprintf('Field [%.3g, %.3g]  RMS=%.4g', fieldPoint(i, 1), fieldPoint(i, 2), spot.rmsRadius));
    xlabel(axs(i), 'x (mm)'); ylabel(axs(i), 'y (mm)');
    axis(axs(i), 'equal'); grid(axs(i), 'on');

    text(axs(i), 0.02, 0.98, sprintf('Centroid: (%.4g, %.4g)', spot.centroid(1), spot.centroid(2)), ...
        'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
end
end
