function startingTrialNums = alignTDiffs(sessionDataRoots, tdiffs_FPGA, tdiffs_Video)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% alignTDiffs: Align session starting numbers for FPGA & video data
% usage:  startingTrialNums = alignTDiffs(sessionDataRoots, tdiffs_FPGA, tdiffs_Video)
%
% where,
%    sessionDataRoots is a cell array of session paths
%    tdiffs_FPGA is a cell array of trial start times for each session as 
%       recorded in the FPGA data stream
%    tdiffs_Video is a cell array of trial start times for each session as
%       recored in the camera data stream
%    startingTrialNums is a two-element array indicating the first trial
%       number for the FPGA and camera streams such that the two streams
%       are time aligned.
%
% This is a helper function for tongueTipTrackerApp which allows the user
%   to use a GUI to align the start trial numbers for the two data streams
%   - FPGA and camera. These streams are not necessarily aligned, because
%   sometimes the FPGA starts recording before the camera is turned on.
%
% See also: TongueTipTrackerApp
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

f = figure('Units', 'normalized', 'Position', [0.1, 0, 0.8, 0.85]);
% Overwrite function close callback to prevent user from
% clicking "x", which would destroy data. User must use
% "Accept" button instead

set(f, 'CloseRequestFcn', @customCloseReqFcn);
% Create accept button, which resumes main thread execution
% when clicked.
%            pan(f, 'xon');
%            zoom(f, 'xon');
autoAlignButton = uicontrol(f, 'Units', 'Normalized', 'Position', [0.025, 1-0.05, 0.085, 0.035], 'String', 'Auto-align', 'Callback', @autoAlign);
resetButton =     uicontrol(f, 'Units', 'Normalized', 'Position', [0.025, 1-0.10, 0.085, 0.035], 'String', 'Reset', 'Callback', @reset);
acceptButton =    uicontrol(f, 'Units', 'Normalized', 'Position', [0.025, 1-0.15, 0.085, 0.035], 'String', 'Accept alignments', 'Callback', 'uiresume(gcbf)');

% %% DEBUG TESTING ONLY DELETE THIS
% Randomly shift one of the time series to test auto-align feature
% randShift = randi(20, size(sessionDataRoots))
% for k = 1:length(sessionDataRoots)
%     tdiffs_Video{k} = tdiffs_Video{k}(randShift(k):end);
% end
% %%

tdiffs.FPGA = tdiffs_FPGA;
tdiffs.Video = tdiffs_Video;

sgtitle({'For each session, select the earliest starting trial interval',...
         'for FPGA and Video trials so they line up with each other.',...
         'Click Accept when done'});

f.UserData = struct();
f.UserData.seriesList = {'FPGA', 'Video'};
f.UserData.faceColors.FPGA = 'g';
f.UserData.faceColors.Video = 'c';
f.UserData.yVal.FPGA = 0;
f.UserData.yVal.Video = 0.5;
f.UserData.h = 0.5;
for sessionNum = 1:numel(sessionDataRoots)
    f.UserData.ax(sessionNum) = subplot(numel(sessionDataRoots), 1, sessionNum, 'HitTest', 'off', 'YLimMode', 'manual');
    hold(f.UserData.ax(sessionNum), 'on');
    f.UserData.ax(sessionNum).UserData = struct();
    f.UserData.ax(sessionNum).UserData.selectedRectangle = struct();
    for seriesNum = 1:numel(f.UserData.seriesList)
        % For each series (FPGA and Video), add useful info to
        %   axis UserData
        series = f.UserData.seriesList{seriesNum};
        f.UserData.ax(sessionNum).UserData.sessionNum = sessionNum;
        f.UserData.ax(sessionNum).UserData.StartingTrialNum.(series) = 1;
        f.UserData.ax(sessionNum).UserData.selectedRectangle.(series) = [];
        f.UserData.ax(sessionNum).UserData.rectangles.(series) = matlab.graphics.primitive.Rectangle.empty();
        f.UserData.ax(sessionNum).UserData.tdiff.(series) = tdiffs.(series){sessionNum}; %tdiffs_FPGA{sessionNum};
        f.UserData.ax(sessionNum).UserData.t.(series) = [0, cumsum(f.UserData.ax(sessionNum).UserData.tdiff.(series))];
        
        seriesShift = f.UserData.ax(sessionNum).UserData.t.(series)(f.UserData.ax(sessionNum).UserData.StartingTrialNum.(series));
        for trialNum = 1:(numel(f.UserData.ax(sessionNum).UserData.t.(series))-1)
            % Create rectangles and save handles to axis UserData
            rectangleID.trialNum = trialNum;
            rectangleID.series = series;
            f.UserData.ax(sessionNum).UserData.rectangles.(series)(trialNum) = ...
                rectangle(f.UserData.ax(sessionNum), ...
                          'Position', [f.UserData.ax(sessionNum).UserData.t.(series)(trialNum) - seriesShift, f.UserData.yVal.(series), f.UserData.ax(sessionNum).UserData.tdiff.(series)(trialNum), f.UserData.h], ...
                          'FaceColor', f.UserData.faceColors.(series), ...
                          'ButtonDownFcn', @tdiffRectangleCallback, ...
                          'UserData', rectangleID);
        end
        xmaxSeries(seriesNum) = f.UserData.ax(sessionNum).UserData.t.(series)(min([numel(f.UserData.ax(sessionNum).UserData.t.(series)), 15]));
    end
    xmax = max(xmaxSeries);
    xlim(f.UserData.ax(sessionNum), [-0.05*xmax, xmax]);
%                 plot(f.UserData.ax(sessionNum), 1:numel(tdiff_FPGA), tdiff_FPGA, 1:numel(tdiff_Video), tdiff_Video);
    title(f.UserData.ax(sessionNum),abbreviateText(sessionDataRoots{sessionNum}, 120), 'Interpreter', 'none', 'HitTest', 'off');
    yticks(f.UserData.ax(sessionNum), [])
end
% Waits until accept button is clicked
uiwait(f);
% If user cancelled alignment, just exit:
if ~isvalid(f)
    startingTrialNums = [];
    return;
end
% Collect results from GUI into struct array
startingTrialNums = struct();
for sessionNum = 1:numel(sessionDataRoots)
    for seriesNum = 1:numel(f.UserData.seriesList)
        series = f.UserData.seriesList{seriesNum};
        startingTrialNums(sessionNum).(series) = f.UserData.ax(sessionNum).UserData.StartingTrialNum.(series);
    end
end
delete(f)

function tdiffRectangleCallback(rectangle, ~)
% This is a callback function for the time-alignment rectangles in
% tongueTipTrackerApp.mlapp.

currentSeries = rectangle.UserData.series;
ax = rectangle.Parent;
f = ax.Parent;
if ~isempty(ax.UserData.selectedRectangle)
    % Deselect previously selected rectangle, if any
    ax.UserData.selectedRectangle.(currentSeries).FaceColor = f.UserData.faceColors.(currentSeries);
    ax.UserData.selectedRectangle.(currentSeries) = [];
end
% Make rectangle the selected rectangle
rectangle.FaceColor = [1, 0, 0];
ax.UserData.selectedRectangle.(currentSeries) = rectangle;
% Shift all rectangles in that session/series
rectangles = ax.UserData.rectangles.(currentSeries);
ax.UserData.StartingTrialNum.(currentSeries) = rectangle.UserData.trialNum;
seriesShift = ax.UserData.t.(currentSeries)(ax.UserData.StartingTrialNum.(currentSeries));
for trialNum = 1:numel(rectangles)
    newPosition = [ax.UserData.t.(currentSeries)(trialNum) - seriesShift, f.UserData.yVal.(currentSeries), ax.UserData.tdiff.(currentSeries)(trialNum), f.UserData.h];
    rectangles(trialNum).Position = newPosition;
end

function customCloseReqFcn(src, callbackdata)
selection = questdlg('Are you sure you want to discard your alignment? Use the ''Accept'' button instead to keep your alignment.',...
    'Are you sure?',...
    'Yes, discard','No, keep','Yes, discard'); 
switch selection 
    case 'Yes, discard'
        delete(src);
    case 'No, keep'
        return;
end

function autoAlign(btn, ~)
f = btn.Parent;

for sessionNum = 1:length(f.UserData.ax)
    ax = f.UserData.ax(sessionNum);
    
    if length(f.UserData.seriesList) ~= 2
        warning('Auto align currently only works for aligning sessions with only two data series.')
        return;
    end

    % For code simplicity, copy time series into a separate variable 
    timeSeries = cell(size(f.UserData.seriesList));
    for k = 1:length(f.UserData.seriesList)
        currentSeries = f.UserData.seriesList{k};
        timeSeries{k} = ax.UserData.t.(currentSeries);
    end

    % Calculate the max lag (
    minLength = min([length(timeSeries{1}), length(timeSeries{2})]);
    maxLag = max(0, minLength - 100);

    % Loop over lags attempting to find a good match
    foundMatch = false;
    diffSeries1 = diff(timeSeries{1});
    diffSeries2 = diff(timeSeries{2});
    minDiff = min([min(diffSeries1), min(diffSeries2)]);
    for lag = -maxLag:maxLag
        startTrialNums = [1, 1];
        startTrialNums(1) = startTrialNums(1) + lag;
        startTrialNums = startTrialNums - min(startTrialNums) + 1;
        shiftedDiffSeries1 = diffSeries1(startTrialNums(1):end);
        shiftedDiffSeries2 = diffSeries2(startTrialNums(2):end);
        minLength = min([length(shiftedDiffSeries1), length(shiftedDiffSeries2)]);
        shiftedDiffSeries1 = shiftedDiffSeries1(1:minLength);
        shiftedDiffSeries2 = shiftedDiffSeries2(1:minLength);
        if all(abs(shiftedDiffSeries1 - shiftedDiffSeries2) < minDiff/100)
            foundMatch = true;
            break;
        end
    end
    
%     [corrs, shifts] = xcorr(diff(timeSeries{1}), diff(timeSeries{2}));
%     [~, I] = max(corrs);
%     startTrialNums = [1, 1];
%     startTrialNums(1) = startTrialNums(1) + shifts(I);
%     startTrialNums = startTrialNums - min(startTrialNums) + 1;

    if foundMatch
        for k = 1:length(f.UserData.seriesList)
            series = f.UserData.seriesList{k};
            alignRectangle = ax.UserData.rectangles.(series)(startTrialNums(k));
            tdiffRectangleCallback(alignRectangle);
        end
    end
end

function reset(btn, ~)
f = btn.Parent;
for sessionNum = 1:length(f.UserData.ax)
    ax = f.UserData.ax(sessionNum);
    for k = 1:length(f.UserData.seriesList)
        series = f.UserData.seriesList{k};
        alignRectangle = ax.UserData.rectangles.(series)(1);
        tdiffRectangleCallback(alignRectangle);
    end
end
