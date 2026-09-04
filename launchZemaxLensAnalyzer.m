function app = launchZemaxLensAnalyzer()
%LAUNCHZEMAXLENSANALYZER Launch the Zemax Lens Analyzer GUI.
repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'src'));
addpath(fullfile(repoRoot, 'src', 'gui'));
app = ZemaxLensAnalyzerApp();
end
