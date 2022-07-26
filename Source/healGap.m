function [xH, yH] = healGap(x, y, gapStartIdx, numPoints)
% Approximate healing of gap in sequence of points


if any(diff(x) < 0)
    % Ordering must be reversed
    flipX = true;
    x = flip(x);
    y = flip(y);
else
    flipX = false;
end

totalDY = y(end) - y(1);
totalDX = x(end) - x(1);
angle = atan(totalDY/totalDX);
if totalDX < 0
    angle = angle + pi;
end

[xr, yr] = rotatePoints(x, y, angle);
%[angle, xr, yr] = findFunctionalRotation(x, y);
if flipX
    xr = flip(xr);
    yr = flip(yr);
end

xH = linspace(x(gapStartIdx), x(gapStartIdx+1), numPoints+2)';
xH = xH(2:end-1);

xqr = linspace(xr(gapStartIdx), xr(gapStartIdx+1), numPoints+2)';
xqr = xqr(2:end-1);

% Fit pchip to rotated points
try
    yHr = pchip(xr, yr, xqr);
catch
    disp('oops');
end

% Unrotate interpolated points
r = exp(angle*1i) .* (xqr + yHr*1i);
yH = imag(r);