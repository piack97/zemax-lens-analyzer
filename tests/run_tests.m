function run_tests()
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'src'));

testParseAscii(repoRoot);
testParseUtf16(repoRoot);
testParseUtf16Be(repoRoot);
testTraceAndSpot(repoRoot);
testInvalidRayHandling(repoRoot);
testRmsFwhmRoundtrip();
testPlotAxesOptions(repoRoot);

fprintf('All tests passed.\n');
end

function testParseAscii(repoRoot)
lens = parseZmxFile(fullfile(repoRoot, 'tests', 'data', 'sample_lens.zmx'));
assert(numel(lens.surfaces) == 3);
assert(abs(lens.surfaces(1).curvature - 0.02) < 1e-12);
assert(strcmpi(lens.surfaces(1).material, 'BK7'));
assert(numel(lens.system.wavelengths) == 3);
assert(size(lens.system.fieldPoints, 2) == 2);
end

function testParseUtf16(repoRoot)
src = fullfile(repoRoot, 'tests', 'data', 'sample_lens.zmx');
dst = fullfile(repoRoot, 'tests', 'data', 'sample_lens_utf16.zmx');

ascii = fileread(src);
bytes = unicode2native(ascii, 'UTF-16LE');
fid = fopen(dst, 'w');
assert(fid > 0);
cleanup = onCleanup(@() cleanupTempFile(dst)); %#ok<NASGU>
fwrite(fid, uint8([255 254]), 'uint8'); % BOM
fwrite(fid, bytes, 'uint8');
fclose(fid);

lens = parseZmxFile(dst);
assert(numel(lens.surfaces) == 3);
assert(abs(lens.system.entrancePupilDiameter - 20) < 1e-12);

end

function testParseUtf16Be(repoRoot)
src = fullfile(repoRoot, 'tests', 'data', 'sample_lens.zmx');
dst = fullfile(repoRoot, 'tests', 'data', 'sample_lens_utf16be.zmx');

ascii = fileread(src);
bytes = unicode2native(ascii, 'UTF-16BE');
fid = fopen(dst, 'w');
assert(fid > 0);
cleanup = onCleanup(@() cleanupTempFile(dst)); %#ok<NASGU>
fwrite(fid, uint8([254 255]), 'uint8'); % BOM
fwrite(fid, bytes, 'uint8');
fclose(fid);

lens = parseZmxFile(dst);
assert(numel(lens.surfaces) == 3);
assert(abs(lens.system.entrancePupilDiameter - 20) < 1e-12);
end

function testTraceAndSpot(repoRoot)
lens = parseZmxFile(fullfile(repoRoot, 'tests', 'data', 'sample_lens.zmx'));
rays(1).origin = [0, 0, -1];
rays(1).direction = [0, 0, 1];
tr = traceSequentialRays(lens, rays, 'Wavelength', 0.5876);
assert(tr.paths(1).valid);
assert(all(isfinite(tr.paths(1).points(end, :))));

spot = computeSpotMetrics(lens, [0, 0], 'PupilSamples', 7, 'Wavelength', 0.5876);
assert(isfinite(spot.rmsRadius));
assert(size(spot.points, 2) == 2);
end

function testInvalidRayHandling(repoRoot)
lens = parseZmxFile(fullfile(repoRoot, 'tests', 'data', 'sample_lens.zmx'));
rays(1).origin = [20, 0, -1];
rays(1).direction = [0, 0, 1];
tr = traceSequentialRays(lens, rays, 'Wavelength', 0.5876);
assert(~tr.paths(1).valid);
assert(contains(tr.paths(1).failureReason, 'vignetted'));

spot = computeSpotMetrics(lens, [0, 0], 'PupilSamples', 9, 'Wavelength', 0.5876);
u = linspace(-1, 1, 9);
[X, Y] = meshgrid(u, u);
totalPupilSamples = nnz((X.^2 + Y.^2) <= 1);
assert(size(spot.points, 1) < totalPupilSamples);
end

function testRmsFwhmRoundtrip()
rms0 = 12.34;
fwhm = rmsSpotToGaussianFWHM(rms0);
rms1 = gaussianFWHMToRmsSpot(fwhm);
assert(abs(rms1 - rms0) < 1e-12);
end

function testPlotAxesOptions(repoRoot)
lens = parseZmxFile(fullfile(repoRoot, 'tests', 'data', 'sample_lens.zmx'));

fig = figure('Visible', 'off');
cleanup = onCleanup(@() delete(fig)); %#ok<NASGU>
ax1 = subplot(2, 2, 1, 'Parent', fig);
axOut1 = plotLensLayout2D(lens, [], 'Axes', ax1, 'ShadeMaterials', true, 'LabelMaterials', true);
assert(axOut1 == ax1);

ax2 = subplot(2, 2, 2, 'Parent', fig);
axOut2 = plotLensLayout3D(lens, [], 'Axes', ax2);
assert(axOut2 == ax2);

ax3 = subplot(2, 2, 3, 'Parent', fig);
plotSpotDiagram(lens, [0, 0], 'Axes', ax3, 'PupilSamples', 7);
didThrow = false;
try
    plotSpotDiagram(lens, [0, 0; 5, 0], 'Axes', ax3, 'PupilSamples', 7);
catch ME
    didThrow = strcmp(ME.identifier, 'plotSpotDiagram:InvalidAxesCount');
end
assert(didThrow);

ax4 = subplot(2, 2, 4, 'Parent', fig);
axOut4 = plotRmsSpotColormap(lens, 'Axes', ax4, 'GridSize', [3 3], 'Units', 'FWHM', 'PupilSamples', 7);
assert(axOut4 == ax4);
plotRmsSpotColormap(lens, 'Axes', ax4, 'GridSize', [3 3], 'Units', 'RMS', 'PupilSamples', 7);
images = findobj(ax4, 'Type', 'image');
assert(~isempty(images));
assert(all(isfinite(images(1).CData(:))));
cbs = findall(fig, 'Type', 'ColorBar', 'Tag', 'plotRmsSpotColormapColorbar');
assert(numel(cbs) == 1);

didThrowUnits = false;
try
    plotRmsSpotColormap(lens, 'Axes', ax4, 'Units', 'NOT_A_UNIT', 'PupilSamples', 5);
catch ME
    didThrowUnits = strcmp(ME.identifier, 'plotRmsSpotColormap:InvalidUnits');
end
assert(didThrowUnits);
end

function cleanupTempFile(path)
if isfile(path)
    delete(path);
end
end
