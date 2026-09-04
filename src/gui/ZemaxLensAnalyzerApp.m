classdef ZemaxLensAnalyzerApp < handle
    properties
        UIFigure matlab.ui.Figure
        LoadButton matlab.ui.control.Button
        SummaryText matlab.ui.control.TextArea
        SurfaceStartSpinner matlab.ui.control.Spinner
        SurfaceEndSpinner matlab.ui.control.Spinner
        FieldDropdown matlab.ui.control.DropDown
        WavelengthDropdown matlab.ui.control.DropDown
        ApertureField matlab.ui.control.NumericEditField

        LayoutAxes matlab.ui.control.UIAxes
        LabelMaterialsCheckBox matlab.ui.control.CheckBox
        LayoutPlotButton matlab.ui.control.Button
        Layout3DButton matlab.ui.control.Button

        SpotAxes matlab.ui.control.UIAxes
        SpotPlotButton matlab.ui.control.Button

        ColormapAxes matlab.ui.control.UIAxes
        UnitsDropdown matlab.ui.control.DropDown
        ColormapPlotButton matlab.ui.control.Button
        Layout3DFigure matlab.ui.Figure
        Layout3DAxes matlab.ui.control.UIAxes

        LensData = []
        FieldPoints = zeros(0, 2)
        Wavelengths = []
    end

    methods
        function app = ZemaxLensAnalyzerApp()
            app.buildUi();
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure) && strcmp(app.UIFigure.BeingDeleted, 'off')
                delete(app.UIFigure);
            end
            if ~isempty(app.Layout3DFigure) && isvalid(app.Layout3DFigure) && strcmp(app.Layout3DFigure.BeingDeleted, 'off')
                delete(app.Layout3DFigure);
            end
        end
    end

    methods (Access = private)
        function buildUi(app)
            app.UIFigure = uifigure('Name', 'Zemax Lens Analyzer', 'Position', [100 100 1200 760]);
            main = uigridlayout(app.UIFigure, [2 1]);
            main.RowHeight = {170, '1x'};

            top = uigridlayout(main, [4 6]);
            top.Layout.Row = 1;
            top.ColumnWidth = {170, 90, 90, 260, 260, '1x'};
            top.RowHeight = {28, 28, 28, '1x'};

            app.LoadButton = uibutton(top, 'push', 'Text', 'Load .zmx File', ...
                'ButtonPushedFcn', @(~, ~) app.loadZmxFile());
            app.LoadButton.Layout.Row = 1;
            app.LoadButton.Layout.Column = 1;

            lbl = uilabel(top, 'Text', 'Surface Start');
            lbl.Layout.Row = 1;
            lbl.Layout.Column = 2;
            app.SurfaceStartSpinner = uispinner(top, 'Limits', [1 1], 'Value', 1, ...
                'RoundFractionalValues', true, 'ValueChangedFcn', @(~, ~) app.refreshLayout());
            app.SurfaceStartSpinner.Layout.Row = 1;
            app.SurfaceStartSpinner.Layout.Column = 3;

            lbl = uilabel(top, 'Text', 'Surface End');
            lbl.Layout.Row = 1;
            lbl.Layout.Column = 4;
            app.SurfaceEndSpinner = uispinner(top, 'Limits', [1 1], 'Value', 1, ...
                'RoundFractionalValues', true, 'ValueChangedFcn', @(~, ~) app.refreshLayout());
            app.SurfaceEndSpinner.Layout.Row = 1;
            app.SurfaceEndSpinner.Layout.Column = 5;

            lbl = uilabel(top, 'Text', 'Field Point');
            lbl.Layout.Row = 2;
            lbl.Layout.Column = 1;
            app.FieldDropdown = uidropdown(top, 'Items', {'[0, 0]'}, 'ItemsData', 1, 'Value', 1, ...
                'ValueChangedFcn', @(~, ~) app.refreshFieldDependentPlots());
            app.FieldDropdown.Layout.Row = 2;
            app.FieldDropdown.Layout.Column = [2 3];

            lbl = uilabel(top, 'Text', 'Wavelength (um)');
            lbl.Layout.Row = 2;
            lbl.Layout.Column = 4;
            app.WavelengthDropdown = uidropdown(top, 'Items', {'0.55'}, 'ItemsData', 0.55, 'Value', 0.55, ...
                'ValueChangedFcn', @(~, ~) app.refreshAllPlots());
            app.WavelengthDropdown.Layout.Row = 2;
            app.WavelengthDropdown.Layout.Column = 5;

            lbl = uilabel(top, 'Text', 'Aperture (ENPD)');
            lbl.Layout.Row = 3;
            lbl.Layout.Column = 1;
            app.ApertureField = uieditfield(top, 'numeric', 'Editable', 'off', 'Value', NaN);
            app.ApertureField.Layout.Row = 3;
            app.ApertureField.Layout.Column = 2;

            app.SummaryText = uitextarea(top, 'Editable', 'off', ...
                'Value', {'No .zmx file loaded.'});
            app.SummaryText.Layout.Row = [3 4];
            app.SummaryText.Layout.Column = [3 6];

            tabs = uitabgroup(main);
            tabs.Layout.Row = 2;

            layoutTab = uitab(tabs, 'Title', 'Layout');
            layoutGrid = uigridlayout(layoutTab, [2 1]);
            layoutGrid.RowHeight = {34, '1x'};
            layoutTop = uigridlayout(layoutGrid, [1 4]);
            layoutTop.ColumnWidth = {130, 140, 120, '1x'};
            layoutTop.Layout.Row = 1;
            app.LayoutPlotButton = uibutton(layoutTop, 'push', 'Text', 'Plot Layout', ...
                'ButtonPushedFcn', @(~, ~) app.refreshLayout());
            app.LayoutPlotButton.Layout.Column = 1;
            app.LabelMaterialsCheckBox = uicheckbox(layoutTop, 'Text', 'Label Materials', 'Value', true, ...
                'ValueChangedFcn', @(~, ~) app.refreshLayout());
            app.LabelMaterialsCheckBox.Layout.Column = 2;
            app.Layout3DButton = uibutton(layoutTop, 'push', 'Text', '3D Layout', ...
                'ButtonPushedFcn', @(~, ~) app.show3DLayout());
            app.Layout3DButton.Layout.Column = 3;
            app.LayoutAxes = uiaxes(layoutGrid);
            app.LayoutAxes.Layout.Row = 2;

            spotTab = uitab(tabs, 'Title', 'Spot Diagram');
            spotGrid = uigridlayout(spotTab, [2 1]);
            spotGrid.RowHeight = {34, '1x'};
            app.SpotPlotButton = uibutton(spotGrid, 'push', 'Text', 'Plot Spot Diagram', ...
                'ButtonPushedFcn', @(~, ~) app.refreshSpotDiagram());
            app.SpotPlotButton.Layout.Row = 1;
            app.SpotAxes = uiaxes(spotGrid);
            app.SpotAxes.Layout.Row = 2;

            colormapTab = uitab(tabs, 'Title', 'RMS / FWHM Colormap');
            cmapGrid = uigridlayout(colormapTab, [2 1]);
            cmapGrid.RowHeight = {34, '1x'};
            cmapTop = uigridlayout(cmapGrid, [1 4]);
            cmapTop.ColumnWidth = {80, 100, 160, '1x'};
            cmapTop.Layout.Row = 1;
            lbl = uilabel(cmapTop, 'Text', 'Units');
            lbl.Layout.Column = 1;
            app.UnitsDropdown = uidropdown(cmapTop, 'Items', {'RMS', 'FWHM'}, 'Value', 'RMS', ...
                'ValueChangedFcn', @(~, ~) app.refreshColormap());
            app.UnitsDropdown.Layout.Column = 2;
            app.ColormapPlotButton = uibutton(cmapTop, 'push', 'Text', 'Plot Colormap', ...
                'ButtonPushedFcn', @(~, ~) app.refreshColormap());
            app.ColormapPlotButton.Layout.Column = 3;
            app.ColormapAxes = uiaxes(cmapGrid);
            app.ColormapAxes.Layout.Row = 2;
        end

        function loadZmxFile(app)
            [fileName, folderPath] = uigetfile( ...
                {'*.zmx', 'Zemax Lens Files (*.zmx)'; '*.*', 'All Files'}, ...
                'Select Zemax Lens File');
            if isequal(fileName, 0)
                return;
            end

            filePath = fullfile(folderPath, fileName);
            try
                lensData = parseZmxFile(filePath);
            catch ME
                uialert(app.UIFigure, sprintf('Failed to load file:\n%s', ME.message), 'Load Error');
                return;
            end

            app.LensData = lensData;
            app.populateControlsFromLens();
            app.refreshAllPlots();
        end

        function populateControlsFromLens(app)
            nSurfaces = numel(app.LensData.surfaces);
            app.SurfaceStartSpinner.Limits = [1, max(1, nSurfaces)];
            app.SurfaceEndSpinner.Limits = [1, max(1, nSurfaces)];
            app.SurfaceStartSpinner.Value = 1;
            app.SurfaceEndSpinner.Value = max(1, nSurfaces);

            if isfield(app.LensData, 'system') && isfield(app.LensData.system, 'fieldPoints') && ~isempty(app.LensData.system.fieldPoints)
                app.FieldPoints = app.LensData.system.fieldPoints;
            else
                app.FieldPoints = [0, 0];
            end
            nFields = size(app.FieldPoints, 1);
            fieldItems = arrayfun(@(i) sprintf('[%.6g, %.6g]', app.FieldPoints(i, 1), app.FieldPoints(i, 2)), ...
                1:nFields, 'UniformOutput', false);
            app.FieldDropdown.Items = fieldItems;
            app.FieldDropdown.ItemsData = 1:nFields;
            app.FieldDropdown.Value = 1;

            if isfield(app.LensData, 'system') && isfield(app.LensData.system, 'wavelengths') && ~isempty(app.LensData.system.wavelengths)
                app.Wavelengths = app.LensData.system.wavelengths(:).';
            else
                app.Wavelengths = 0.55;
            end
            waveItems = arrayfun(@(w) sprintf('%.6g', w), app.Wavelengths, 'UniformOutput', false);
            app.WavelengthDropdown.Items = waveItems;
            app.WavelengthDropdown.ItemsData = app.Wavelengths;
            app.WavelengthDropdown.Value = app.Wavelengths(1);

            if isfield(app.LensData, 'system') && isfield(app.LensData.system, 'entrancePupilDiameter')
                app.ApertureField.Value = app.LensData.system.entrancePupilDiameter;
            else
                app.ApertureField.Value = NaN;
            end

            imgIdx = NaN;
            if isfield(app.LensData, 'system') && isfield(app.LensData.system, 'imageSurfaceIndex')
                imgIdx = app.LensData.system.imageSurfaceIndex;
            end
            app.SummaryText.Value = {
                sprintf('Loaded: %s', app.LensData.filePath), ...
                sprintf('Surfaces: %d', nSurfaces), ...
                sprintf('Image surface index: %g', imgIdx)
                };
        end

        function refreshAllPlots(app)
            app.refreshLayout();
            app.refreshSpotDiagram();
            app.refreshColormap();
        end

        function refreshFieldDependentPlots(app)
            app.refreshLayout();
            app.refreshSpotDiagram();
        end

        function refreshLayout(app)
            if isempty(app.LensData)
                return;
            end
            try
                plotLensLayout2D(app.LensData, app.currentSurfaceRange(), ...
                    'Axes', app.LayoutAxes, ...
                    'FieldPoints', app.currentFieldPoint(), ...
                    'Wavelength', app.currentWavelength(), ...
                    'ShadeMaterials', true, ...
                    'LabelMaterials', app.LabelMaterialsCheckBox.Value);
            catch ME
                uialert(app.UIFigure, sprintf('Failed to plot layout:\n%s', ME.message), 'Plot Error');
            end
        end

        function show3DLayout(app)
            if isempty(app.LensData)
                return;
            end
            fig = app.Layout3DFigure;
            ax = app.Layout3DAxes;
            try
                if isempty(fig) || ~isvalid(fig) || isempty(ax) || ~isvalid(ax)
                    fig = uifigure('Name', '3D Lens Layout', 'Position', [150 150 900 650]);
                    gl = uigridlayout(fig, [1 1]);
                    ax = uiaxes(gl);
                    app.Layout3DFigure = fig;
                    app.Layout3DAxes = ax;
                end
                plotLensLayout3D(app.LensData, app.currentSurfaceRange(), ...
                    'Axes', ax, ...
                    'FieldPoints', app.currentFieldPoint(), ...
                    'Wavelength', app.currentWavelength());
            catch ME
                if ~isempty(fig) && isgraphics(fig)
                    delete(fig);
                end
                uialert(app.UIFigure, sprintf('Failed to plot 3D layout:\n%s', ME.message), 'Plot Error');
            end
        end

        function refreshSpotDiagram(app)
            if isempty(app.LensData)
                return;
            end
            try
                plotSpotDiagram(app.LensData, app.currentFieldPoint(), ...
                    'Axes', app.SpotAxes, ...
                    'Wavelength', app.currentWavelength());
            catch ME
                uialert(app.UIFigure, sprintf('Failed to plot spot diagram:\n%s', ME.message), 'Plot Error');
            end
        end

        function refreshColormap(app)
            if isempty(app.LensData)
                return;
            end
            try
                fx = app.FieldPoints(:, 1);
                fy = app.FieldPoints(:, 2);
                fxRange = nonDegenerateRange([min(fx), max(fx)]);
                fyRange = nonDegenerateRange([min(fy), max(fy)]);
                plotRmsSpotColormap(app.LensData, ...
                    'Axes', app.ColormapAxes, ...
                    'Units', app.UnitsDropdown.Value, ...
                    'Wavelength', app.currentWavelength(), ...
                    'GridSize', [max(2, numel(unique(fx))), max(2, numel(unique(fy)))], ...
                    'FieldRangeX', fxRange, ...
                    'FieldRangeY', fyRange);
            catch ME
                uialert(app.UIFigure, sprintf('Failed to plot colormap:\n%s', ME.message), 'Plot Error');
            end
        end

        function range = currentSurfaceRange(app)
            s0 = round(app.SurfaceStartSpinner.Value);
            s1 = round(app.SurfaceEndSpinner.Value);
            range = [min(s0, s1), max(s0, s1)];
        end

        function fp = currentFieldPoint(app)
            idx = app.FieldDropdown.Value;
            fp = app.FieldPoints(idx, :);
        end

        function w = currentWavelength(app)
            w = app.WavelengthDropdown.Value;
        end
    end
end

function r = nonDegenerateRange(r)
scale = max(1, max(abs(r)));
if abs(r(2) - r(1)) < 1e-9 * scale
    pad = max(1, 0.1 * max(1, abs(r(1))));
    r = [r(1) - pad, r(2) + pad];
end
end
