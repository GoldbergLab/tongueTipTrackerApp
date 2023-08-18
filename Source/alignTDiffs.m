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
% Overwritfunce function close callback to prevent user from
% clicking "x", which would destroy data. User must use
% "Accept" button instead

set(f, 'CloseRequestFcn', @customCloseReqFcn);
% Create accept button, which resumes main thread execution
% when clicked.
acceptButton = uicontrol(f, 'Position',[10 10 200 20],'String','Accept trial alignments','Callback','uiresume(gcbf)');
%            pan(f, 'xon');
%            zoom(f, 'xon');
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
    ax(sessionNum) = subplot(numel(sessionDataRoots), 1, sessionNum, 'HitTest', 'off', 'YLimMode', 'manual');
    hold(ax(sessionNum), 'on');
    ax(sessionNum).UserData = struct();
    ax(sessionNum).UserData.selectedRectangle = struct();
    for seriesNum = 1:numel(f.UserData.seriesList)
        % For each series (FPGA and Video), add useful info to
        %   axis UserData
        series = f.UserData.seriesList{seriesNum};
        ax(sessionNum).UserData.sessionNum = sessionNum;
        ax(sessionNum).UserData.StartingTrialNum.(series) = 1;
        ax(sessionNum).UserData.selectedRectangle.(series) = [];
        ax(sessionNum).UserData.rectangles.(series) = matlab.graphics.primitive.Rectangle.empty();
        ax(sessionNum).UserData.tdiff.(series) = tdiffs.(series){sessionNum}; %tdiffs_FPGA{sessionNum};
        ax(sessionNum).UserData.t.(series) = [0, cumsum(ax(sessionNum).UserData.tdiff.(series))];
        
        seriesShift = ax(sessionNum).UserData.t.(series)(ax(sessionNum).UserData.StartingTrialNum.(series));
        for trialNum = 1:(numel(ax(sessionNum).UserData.t.(series))-1)
            % Create rectangles and save handles to axis UserData
            rectangleID.trialNum = trialNum;
            rectangleID.series = series;
            ax(sessionNum).UserData.rectangles.(series)(trialNum) = ...
                rectangle(ax(sessionNum), ...
                          'Position', [ax(sessionNum).UserData.t.(series)(trialNum) - seriesShift, f.UserData.yVal.(series), ax(sessionNum).UserData.tdiff.(series)(trialNum), f.UserData.h], ...
                          'FaceColor', f.UserData.faceColors.(series), ...
                          'ButtonDownFcn', @tdiffRectangleCallback, ...
                          'UserData', rectangleID);
        end
        xmaxSeries(seriesNum) = ax(sessionNum).UserData.t.(series)(min([numel(ax(sessionNum).UserData.t.(series)), 15]));
    end
    xmax = max(xmaxSeries);
    xlim(ax(sessionNum), [-0.05*xmax, xmax]);
%                 plot(ax(sessionNum), 1:numel(tdiff_FPGA), tdiff_FPGA, 1:numel(tdiff_Video), tdiff_Video);
    title(ax(sessionNum),abbreviateText(sessionDataRoots{sessionNum}, 120), 'Interpreter', 'none', 'HitTest', 'off');
    yticks(ax(sessionNum), [])
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
        startingTrialNums(sessionNum).(series) = ax(sessionNum).UserData.StartingTrialNum.(series);
    end
end
delete(f)

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
