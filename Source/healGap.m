function xyH = healGap(xy, gapIdx, referenceRadius)
% Approximate healing of gap in sequence of ordered points
% GapIdx is the index of the pixel immediately "before" the gap.

if size(xy, 1) < 2*referenceRadius+1
    error('Coordinate list to heal is too short.');
end

if gapIdx - referenceRadius < 1 || gapIdx + referenceRadius > size(xy, 1)
    % Gap is too close to end of vector - need to "rotate" array and
    % indices
    newGapIdx = referenceRadius + 1;
    xy = circshift(xy, [newGapIdx - gapIdx, 0]);
    gapIdx = newGapIdx;
end

% Extract target region for healing
idxStart = (gapIdx-referenceRadius);
idxEnd = (gapIdx+referenceRadius);
targetXY = xy(idxStart:idxEnd, :);
targetGapIdx = referenceRadius + 1;

% Prep target region for interpolation
[x, y, flipped] = sanitizeXY(targetXY(:, 1), targetXY(:, 2));
targetXY = [x, y];

% Adjust gap index if flipping was necessary
if flipped
    targetGapIdx = size(targetXY, 1) - targetGapIdx + 1;
end

% Generate list of x coordinates to fill gap
xGap = (targetXY(targetGapIdx, 1)+1):(targetXY(targetGapIdx+1, 1)-1);

% Interpolate list of y coordinates to fill gap
yGap = pchip(targetXY(:, 1), targetXY(:, 2), xGap);

% Combine to get coordinate list to fill gap
xyGap = [xGap', yGap'];

% Insert gap coordinates into target region
targetXY = round([targetXY(1:targetGapIdx, :); xyGap; targetXY(targetGapIdx+1:end, :)]);
% Ensure target region is "airtight" so imfill can be used to fill
targetXY = calculateMaskPolygon(targetXY);

% If necessary, un-flip target region
if flipped
    targetXY = flip(targetXY);
end

% Insert fixed target region back into full coordinates
xyH = [xy(1:idxStart, :); targetXY; xy(idxEnd:end, :)];

function [x, y, flipped] = sanitizeXY(x, y)
% If points seem to be ordered in reverse-x order, flip them
if mean(diff(x)) < 0
    % Ordering must be reversed
    flipped = true;
    x = flip(x);
    y = flip(y);
else
    flipped = false;
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