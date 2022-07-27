function yH = healGap(x, y, xq)
% Approximate healing of gap in sequence of ordered points

[x, y, xq] = sanitizeXY(x, y, xq);

yH = pchip(x, y, xq);

function [x, y, xq] = sanitizeXY(x, y, xq)
% If points seem to be ordered in reverse-x order, flip them
if mean(diff(x)) < 0
    % Ordering must be reversed
    x = flip(x);
    y = flip(y);
    xq = flip(xq);
end

% Force x to be monotonic increasing (still could stay the same)
x = cummax(x);

% Find starts and ends of stretches of repeated x-coordinates
repeatStarts = find(diff(diff([NaN; x; NaN]) == 0)>0);
repeatEnds = find(diff(diff([NaN; x; NaN]) == 0)<0);

for k = 1:length(repeatStarts)
    % Identify start and end of set of repeated X values
    repStart = repeatStarts(k);
    repEnd = repeatEnds(k);
    repVal = x(repStart);
    nReps = repEnd - repStart + 1;
    % Generate new slightly spread out x-values to de-duplicate them
    newX = linspace(repVal-0.9, repVal+0.9, nReps+2);
    newX = newX(2:end-1);
    x(repStart:repEnd) = newX;
end