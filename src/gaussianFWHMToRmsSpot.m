function rmsRadius = gaussianFWHMToRmsSpot(fwhm)
%GAUSSIANFWHMTORMSSPOT Convert Gaussian FWHM to equivalent 2D RMS radius.

rmsRadius = fwhm ./ (2 * sqrt(log(2)));
end
