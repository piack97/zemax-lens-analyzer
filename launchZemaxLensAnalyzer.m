function app = launchZemaxLensAnalyzer()
%LAUNCHZEMAXLENSANALYZER Launch the Zemax Lens Analyzer GUI.
if ~exist('ZemaxLensAnalyzerApp', 'class')
    error('launchZemaxLensAnalyzer:MissingPath', ...
        'Add src and src/gui to the MATLAB path before launching the app.');
end
app = ZemaxLensAnalyzerApp();
end
