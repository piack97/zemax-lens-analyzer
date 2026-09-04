function lensData = parseZmxFile(filePath)
%PARSEZMXFILE Parse a Zemax sequential .zmx lens file.

if ~(ischar(filePath) || isstring(filePath))
    error('parseZmxFile:InvalidInput', 'filePath must be a character vector or string scalar.');
end
filePath = char(filePath);
if ~isfile(filePath)
    error('parseZmxFile:FileNotFound', 'File not found: %s', filePath);
end

textData = readTextWithEncodingFallback(filePath);
lines = splitlines(string(textData));

lensData = struct();
lensData.filePath = filePath;
lensData.system = struct( ...
    'entrancePupilDiameter', NaN, ...
    'stopSurface', NaN, ...
    'wavelengths', [], ...
    'fieldPoints', zeros(0, 2), ...
    'objectSurfaceIndex', NaN, ...
    'imageSurfaceIndex', NaN);
lensData.surfaces = struct('number', {}, 'curvature', {}, 'thickness', {}, ...
    'material', {}, 'semiDiameter', {}, 'conic', {}, 'surfaceType', {}, 'asphereCoefficients', {});

currentSurfaceIdx = 0;
fieldX = containers.Map('KeyType', 'int32', 'ValueType', 'double');
fieldY = containers.Map('KeyType', 'int32', 'ValueType', 'double');

for i = 1:numel(lines)
    line = strtrim(lines(i));
    if line == "" || startsWith(line, "!") || startsWith(line, "#")
        continue;
    end

    tokens = split(line);
    keyword = upper(tokens(1));
    args = tokens(2:end);

    switch keyword
        case "SURF"
            if isempty(args)
                continue;
            end
            surfNum = str2double(args(1));
            if isnan(surfNum)
                continue;
            end
            currentSurfaceIdx = numel(lensData.surfaces) + 1;
            lensData.surfaces(currentSurfaceIdx) = defaultSurface(surfNum);

        case {"TYPE", "COMM"}
            if currentSurfaceIdx > 0 && keyword == "TYPE"
                lensData.surfaces(currentSurfaceIdx).surfaceType = strjoin(cellstr(args), ' ');
            end

        case "CURV"
            if currentSurfaceIdx > 0
                lensData.surfaces(currentSurfaceIdx).curvature = firstNumeric(args, lensData.surfaces(currentSurfaceIdx).curvature);
            end

        case "DISZ"
            if currentSurfaceIdx > 0
                lensData.surfaces(currentSurfaceIdx).thickness = firstNumeric(args, lensData.surfaces(currentSurfaceIdx).thickness);
            end

        case "GLAS"
            if currentSurfaceIdx > 0 && ~isempty(args)
                lensData.surfaces(currentSurfaceIdx).material = char(args(1));
            end

        case "DIAM"
            if currentSurfaceIdx > 0
                diam = firstNumeric(args, NaN);
                if ~isnan(diam)
                    lensData.surfaces(currentSurfaceIdx).semiDiameter = diam / 2;
                end
            end

        case "CONI"
            if currentSurfaceIdx > 0
                lensData.surfaces(currentSurfaceIdx).conic = firstNumeric(args, lensData.surfaces(currentSurfaceIdx).conic);
            end

        case "PARM"
            if currentSurfaceIdx > 0
                nums = parseNumbers(args);
                if numel(nums) >= 2
                    parmIndex = nums(1);
                    parmValue = nums(2);
                    if parmIndex >= 0 && isfinite(parmIndex)
                        coeffs = lensData.surfaces(currentSurfaceIdx).asphereCoefficients;
                        idx = floor(parmIndex) + 1;
                        if numel(coeffs) < idx
                            coeffs(idx) = 0; %#ok<AGROW>
                        end
                        coeffs(idx) = parmValue;
                        lensData.surfaces(currentSurfaceIdx).asphereCoefficients = coeffs;
                    end
                end
            end

        case "ENPD"
            lensData.system.entrancePupilDiameter = firstNumeric(args, lensData.system.entrancePupilDiameter);

        case {"WAVL", "WAVM"}
            nums = parseNumbers(args);
            if ~isempty(nums)
                lensData.system.wavelengths = nums(:).';
            end

        case {"XFLN", "FLDX"}
            nums = parseNumbers(args);
            if numel(nums) >= 2
                fieldX(int32(nums(1))) = nums(2);
            elseif numel(nums) == 1
                fieldX(int32(fieldX.Count + 1)) = nums(1);
            end

        case {"YFLN", "FLDY"}
            nums = parseNumbers(args);
            if numel(nums) >= 2
                fieldY(int32(nums(1))) = nums(2);
            elseif numel(nums) == 1
                fieldY(int32(fieldY.Count + 1)) = nums(1);
            end

        case "STOP"
            lensData.system.stopSurface = firstNumeric(args, lensData.system.stopSurface);

        case "OBJS"
            lensData.system.objectSurfaceIndex = firstNumeric(args, lensData.system.objectSurfaceIndex);

        case "IMAS"
            lensData.system.imageSurfaceIndex = firstNumeric(args, lensData.system.imageSurfaceIndex);

        otherwise
            % Intentionally ignored for robustness.
    end
end

lensData.system.fieldPoints = mergeFieldMaps(fieldX, fieldY);

if isempty(lensData.surfaces)
    error('parseZmxFile:MalformedFile', 'No SURF blocks were found in %s.', filePath);
end

if isnan(lensData.system.objectSurfaceIndex)
    lensData.system.objectSurfaceIndex = lensData.surfaces(1).number;
end
if isnan(lensData.system.imageSurfaceIndex)
    lensData.system.imageSurfaceIndex = lensData.surfaces(end).number;
end
end

function s = defaultSurface(surfNum)
s = struct( ...
    'number', surfNum, ...
    'curvature', 0, ...
    'thickness', 0, ...
    'material', 'AIR', ...
    'semiDiameter', NaN, ...
    'conic', 0, ...
    'surfaceType', 'STANDARD', ...
    'asphereCoefficients', []);
end

function nums = parseNumbers(args)
nums = [];
for k = 1:numel(args)
    val = str2double(args(k));
    if ~isnan(val)
        nums(end + 1) = val; %#ok<AGROW>
    end
end
end

function val = firstNumeric(args, fallback)
val = fallback;
nums = parseNumbers(args);
if ~isempty(nums)
    val = nums(1);
end
end

function fields = mergeFieldMaps(fieldX, fieldY)
allKeys = unique([cell2mat(fieldX.keys), cell2mat(fieldY.keys)]);
if isempty(allKeys)
    fields = [0, 0];
    return;
end
fields = zeros(numel(allKeys), 2);
for i = 1:numel(allKeys)
    k = allKeys(i);
    if isKey(fieldX, k)
        fields(i, 1) = fieldX(k);
    end
    if isKey(fieldY, k)
        fields(i, 2) = fieldY(k);
    end
end
end

function textData = readTextWithEncodingFallback(filePath)
raw = filereadBinary(filePath);

if numel(raw) >= 2 && raw(1) == 255 && raw(2) == 254
    textData = readWithEncoding(filePath, 'UTF-16LE');
    return;
end
if numel(raw) >= 2 && raw(1) == 254 && raw(2) == 255
    textData = readWithEncoding(filePath, 'UTF-16BE');
    return;
end

try
    textData = readWithEncoding(filePath, 'UTF-8');
catch
    textData = readWithEncoding(filePath, 'US-ASCII');
end
end

function raw = filereadBinary(filePath)
fid = fopen(filePath, 'r');
if fid < 0
    error('parseZmxFile:ReadError', 'Unable to open file: %s', filePath);
end
cleaner = onCleanup(@() fclose(fid));
raw = fread(fid, inf, 'uint8=>uint8').';
end

function textData = readWithEncoding(filePath, encoding)
fid = fopen(filePath, 'r', 'n', encoding);
if fid < 0
    error('parseZmxFile:ReadError', 'Unable to read %s using %s.', filePath, encoding);
end
cleaner = onCleanup(@() fclose(fid));
chunks = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
if isempty(chunks) || isempty(chunks{1})
    textData = '';
else
    textData = strjoin(chunks{1}, newline);
end
end
