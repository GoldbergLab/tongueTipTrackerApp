function spoutMask = findSpout(frame, numSpouts)

spoutModels = {
    @(topPos, botPos, topAmp, botAmp, topWidth, botWidth, topBaseline, botBaseline, topCutoff, botCutoff, x)dualSpoutModel(topPos, botPos, topAmp, botAmp, topWidth, botWidth, topBaseline, botBaseline, topCutoff, botCutoff, x),
    @(pos, amp, width, baseline, cutoff, x)singleSpoutModel(pos, amp, width, baseline, cutoff, x)
    };
profileAveragingWidth = 15;
yProfile = mean(double(frame(:, end-profileAveragingWidth+1:end)), 2);
x = (1:length(yProfile))';

[fH, fW] = size(frame);

% Find peaks for estimating model parameters
[pks, locs] = findpeaks(yProfile, 'NPeaks', numSpouts, 'SortStr', 'descend', 'MinPeakHeight', 20); %, 'MinPeakProminence', 20);

% Define model parameters
baseline = median(yProfile);
minAmplitude = quantile(yProfile, 0.75);
IQR = quantile(yProfile, 0.75) - quantile(yProfile, 0.25);
maxAmplitude = max(yProfile) + IQR - baseline;
width = 30;
cutoff = min(pks)/2;
yProfile(yProfile > cutoff) = cutoff;
lowerModelBounds = {
    [1, minAmplitude, 0, 0, 0],
    [1, fH/2, minAmplitude, minAmplitude, 0, 0, 0, 0, 0, 0]
    };
upperModelBounds = {
    [fH, maxAmplitude, fH, maxAmplitude, maxAmplitude],
    [fH/2, fH, maxAmplitude, maxAmplitude, fH, fH, maxAmplitude, maxAmplitude, maxAmplitude, maxAmplitude]
    };
modelStartPoints = {
    [locs', pks', width, baseline, cutoff],
    [locs', pks', width, width, baseline, baseline, cutoff, cutoff]
    };

spoutFitType = fittype(spoutModels{numSpouts});
spoutFitOptions = fitoptions(spoutFitType);
spoutFitOptions.Lower = lowerModelBounds{numSpouts};
spoutFitOptions.Upper = upperModelBounds{numSpouts};
spoutFitOptions.StartPoint = modelStartPoints{numSpouts};

spoutFit = fit(x, smooth(yProfile), spoutFitType, spoutFitOptions);
figure; plot(spoutFit, x, smooth(yProfile))
spoutPositions = [spoutFit.tsp, spoutFit.bsp];
spoutWidths = [spoutFit.tsw, spoutFit.bsw];

[~, topIdx] = min(spoutPositions);
[~, botIdx] = max(spoutPositions);

topSpoutY = round(spoutPositions(topIdx));
botSpoutY = round(spoutPositions(botIdx));
topSpoutW = spoutWidths(topIdx)*4;
botSpoutW = spoutWidths(botIdx)*4;

xProfile = double(frame(botSpoutY, :));
x = (1:length(xProfile))';
%plot(ax, x, 400 - getLocalVariation(xProfile, 20), 'red');

spoutIm = frame(round(botSpoutY-botSpoutW/2.5):round(botSpoutY+botSpoutW/2.5), :);
xProfile = mean(double(spoutIm), 1);

splitStart = round(fW*0.5);
splitEnd = fW; %round(fW*0.75);
lineFit = [];
lineFitX = [];
for splitPoint = splitStart:splitEnd
    candidateRegion = xProfile(splitPoint:end);
    md = fitlm(1:length(candidateRegion), candidateRegion);
    lineFit(end+1) = md.Rsquared.Adjusted;
    lineFitX(end+1) = splitPoint;
end

% figure;
% plot(lineFitX, lineFit);
% spoutMask = [];

[pks, locs] = findpeaks(lineFit, lineFitX, 'NPeaks', 1, 'MinPeakHeight', 0.05, 'MinPeakProminence', 0.05);
spoutHalo1 = max(locs);
[pks, locs] = findpeaks(1-lineFit, lineFitX, 'NPeaks', 1, 'MinPeakHeight', 0.05, 'MinPeakProminence', 0.05);
spoutHalo2 = max(locs);
spoutEnd = round(mean([spoutHalo1, spoutHalo2]));

topSpoutXs = [spoutEnd, spoutEnd, 192, 192];
botSpoutXs = [spoutEnd, spoutEnd, 192, 192];
topSpoutYs = [topSpoutY+topSpoutW/2, topSpoutY-topSpoutW/2, topSpoutY-topSpoutW/2, topSpoutY+topSpoutW/2];
botSpoutYs = [botSpoutY+botSpoutW/2, botSpoutY-botSpoutW/2, botSpoutY-botSpoutW/2, botSpoutY+botSpoutW/2];

figure;
ax = axes(); 
imshow(frame, 'Parent', ax);
patch(ax, topSpoutXs, topSpoutYs, 'red', 'FaceAlpha', 0.1);
patch(ax, botSpoutXs, botSpoutYs, 'yellow', 'FaceAlpha', 0.1);

% hold on; plot(400-xProfile, 'cyan');

function spoutProfile = dualSpoutModel(topPos, botPos, topAmp, botAmp, topWidth, botWidth, topBaseline, botBaseline, topCutoff, botCutoff, x)

half = round(length(x)/2);
topX = x(1:half);
botX = x(half+1:end);

% topProfile = ((-4 * topAmp)./(topWidth.^2)) .* (topX - topPos).^2 + topAmp;
% botProfile = ((-4 * botAmp)./(botWidth.^2)) .* (botX - botPos).^2 + botAmp;
% 
% topProfile(topProfile < 0) = 0;
% botProfile(botProfile < 0) = 0;
% 
% spoutProfile = [topProfile + topBaseline; botProfile + botBaseline];

topProfile = topAmp * topWidth * sqrt(2*pi) * normpdf(topX, topPos, topWidth) + topBaseline;
botProfile = botAmp * botWidth * sqrt(2*pi) * normpdf(botX, botPos, botWidth) + botBaseline;

topProfile(topProfile > topCutoff) = topCutoff;
botProfile(botProfile > botCutoff) = botCutoff;

spoutProfile = [topProfile; botProfile];


function spoutProfile = singleSpoutModel(pos, amp, width, baseline, cutoff, x)
spoutProfile = amp * width * sqrt(2*pi) * normpdf(x, pos, width) + baseline;
spoutProfile(spoutProfile > cutoff) = cutoff;
