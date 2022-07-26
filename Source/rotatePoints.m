function [xr, yr] = rotatePoints(x, y, angle)
cr = exp(-angle*1i) * (x + y*1i);
xr = real(cr);
yr = imag(cr);
