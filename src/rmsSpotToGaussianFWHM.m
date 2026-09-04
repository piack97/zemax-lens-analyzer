function fwhm = rmsSpotToGaussianFWHM(rmsRadius)
%RMSSPOTTOGAUSSIANFWHM Convert 2D RMS radius to equivalent Gaussian FWHM.
% Isotropic 2D Gaussian: rmsRadius = sqrt(2)*sigma, FWHM = 2*sqrt(2*ln2)*sigma.

fwhm = rmsRadius .* (2 * sqrt(log(2)));
end
