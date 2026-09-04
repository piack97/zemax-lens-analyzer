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
p.addParameter('Axes', [], @(x) isempty(x) || all(isAxesHandle(x)));
p.parse(varargin{:});
opts = p.Results;

nFields = size(fieldPoint, 1);
gridCols = ceil(sqrt(nFields));
gridRows = ceil(nFields / gridCols);
axs = gobjects(nFields, 1);
if isempty(opts.Axes)
    targetAxes = gobjects(0);
else
    targetAxes = opts.Axes(:);
    if ~(numel(targetAxes) == 1 || numel(targetAxes) == nFields)
        error('plotSpotDiagram:InvalidAxesCount', 'Provide either 1 axes handle or one per field point.');
    end
    if numel(targetAxes) == 1 && nFields > 1
        error('plotSpotDiagram:InvalidAxesCount', ...
            'A single axes handle can only be used for one field point.');
    end
end

for i = 1:nFields
    if isempty(targetAxes)
        axs(i) = subplot(gridRows, gridCols, i);
    elseif numel(targetAxes) == 1
        axs(i) = targetAxes(1);
    else
        axs(i) = targetAxes(i);
    end
    cla(axs(i));
    hold(axs(i), 'on');

    spot = computeSpotMetrics(lensData, fieldPoint(i, :), 'PupilSamples', opts.PupilSamples, 'Wavelength', opts.Wavelength);
    if ~isempty(spot.points)
        scatter(axs(i), spot.points(:, 1), spot.points(:, 2), 12, 'filled', 'MarkerFaceAlpha', 0.45);
        plot(axs(i), spot.centroid(1), spot.centroid(2), 'kx', 'MarkerSize', 8, 'LineWidth', 1.2);
    else
        text(axs(i), 0.5, 0.5, 'No valid rays', 'Units', 'normalized', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
    end

    if opts.ShowAiryDisk && isfinite(opts.AiryRadius) && opts.AiryRadius > 0
        th = linspace(0, 2 * pi, 200);
        plot(axs(i), spot.centroid(1) + opts.AiryRadius * cos(th), ...
            spot.centroid(2) + opts.AiryRadius * sin(th), 'k--');
    end

    title(axs(i), sprintf('Field [%.3g, %.3g]  RMS=%.4g', fieldPoint(i, 1), fieldPoint(i, 2), spot.rmsRadius));
    xlabel(axs(i), 'x (mm)'); ylabel(axs(i), 'y (mm)');
    axis(axs(i), 'equal'); grid(axs(i), 'on');

    if all(isfinite(spot.centroid))
        text(axs(i), 0.02, 0.98, sprintf('Centroid: (%.4g, %.4g)', spot.centroid(1), spot.centroid(2)), ...
            'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
    end
end
end

function tf = isAxesHandle(x)
tf = isa(x, 'matlab.graphics.axis.Axes') || isa(x, 'matlab.ui.control.UIAxes');
end
