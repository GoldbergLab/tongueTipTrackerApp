classdef TongueStatsBrowser < VideoBrowser
    properties (Access = public)
        Stack                   StateStack                           % Undo/redo stack
        MaskRootDir             (1, :) char
        VideoRootDir            (1, :) char
        VideoFileList           cell {mustBeText}
        TopMaskFileList         cell {mustBeText}
        BotMaskFileList         cell {mustBeText}
        TStats                  struct
        LickList                matlab.ui.control.UIControl
        CurrentTrial            (1, 1) double
        DisplayFields           cell
        RightPanel              matlab.ui.container.Panel
        ControlPanel            matlab.ui.container.Panel
        EditFieldLabel          matlab.ui.control.UIControl
        EditFieldLabelLabel     matlab.ui.control.UIControl
        AddSelectionButton      matlab.ui.control.UIControl
        RemoveSelectionButton   matlab.ui.control.UIControl
        OnValueEdit             matlab.ui.control.UIControl
        OffValueEdit            matlab.ui.control.UIControl
        OnValueEditLabel        matlab.ui.control.UIControl
        OffValueEditLabel       matlab.ui.control.UIControl
        TrialCollapseStates     logical
    end
    methods
        function obj = TongueStatsBrowser(MaskRootDir, VideoRootDir, options)
            arguments
                MaskRootDir
                VideoRootDir = MaskRootDir
                options.NavigationData = [];
                options.NavigationColor = 'black';
                options.NavigationColormap = colormap();
                options.NavigationCLim = [13.0000, 24.5000]
                options.Title = '';
                options.DisplayFields {mustBeText} = {'volume', 'centroid_x', 'centroid_y', 'centroid_z', 'tip_x', 'tip_y', 'tip_z', 'magspeed_c', 'magspeed_t'}
            end

            VideoFileList = findSessionVideos(VideoRootDir, 'avi', @parsePCCFilenameTimestamp);
            DisplayFields = options.DisplayFields;
            options = rmfield(options, 'DisplayFields');

            vbOptions = options;
%             vbOptions = rmfield(vbOptions, 'Masks');
%             vbOptions = rmfield(vbOptions, 'MaskOrigins');
            args = namedargs2cell(vbOptions);
            args{end+1} = 'NavigationData';
            args{end+1} = cell(1, length(DisplayFields));
            args{end+1} = 'NavigationScrollMode';
            args{end+1} = 'none';

            CurrentTrial = 1;

            obj@VideoBrowser(VideoFileList{CurrentTrial}, args{:});

            obj.DisplayFields = DisplayFields;
            obj.CurrentTrial = CurrentTrial;
            obj.MaskRootDir = MaskRootDir;
            obj.VideoRootDir = VideoRootDir;
            obj.VideoFileList = VideoFileList;
            obj.BotMaskFileList = findFilesByRegex(obj.MaskRootDir, 'Bot_[0-9]+\.mat');
            obj.TopMaskFileList = findFilesByRegex(obj.MaskRootDir, 'Top_[0-9]+\.mat');
            s = load(fullfile(obj.MaskRootDir, 't_stats.mat'), 't_stats');
            obj.TStats = s.t_stats;
            if numel(obj.VideoFileList) ~= numel(obj.BotMaskFileList) || numel(obj.BotMaskFileList) ~= numel(obj.TopMaskFileList)
                warning('Number of videos, top masks, and bottom masks do not all match.');
            end
            obj.TrialCollapseStates = false(1, length(obj.TStats));
            obj.populateLickList();
            obj.Stack = StateStack(100);
            obj.SaveState();
            obj.UpdateNavigationAxes();
            obj.UpdatePlotData();
            
        end
        function createDisplayArea(obj)
            createDisplayArea@VideoBrowser(obj);
            obj.MainFigure.Name = 'TongueStatsbrowser';
            obj.MainFigure.WindowScrollWheelFcn = @obj.ScrollWheelHandler;
            obj.VideoPanel.Position(3) = 0.5;
            obj.RightPanel = uipanel(...
                "Parent", obj.MainFigure, ...
                "Units", "normalized", ...
                "Position", [0.5, 0, 0.5, 1] ...
                );
            obj.LickList = uicontrol(...
                "Style", "listbox", ...
                "Parent", obj.RightPanel, ...
                "Units", "normalized", ...
                "Position", [0, 0.25, 1, 0.75], ...
                "Callback", @obj.LickListClickHandler);
            obj.ControlPanel = uipanel(...
                "Parent", obj.RightPanel, ...
                "Units", "normalized", ...
                "Position", [0, 0, 1, 0.25] ...
                );

            obj.EditFieldLabelLabel = uicontrol(...
                "Style", "text", ...
                "String", "Edit field:", ...
                "Parent", obj.ControlPanel, ...
                "Units", "normalized");
            obj.EditFieldLabel = uicontrol(...
                "Style", "edit", ...
                "String", "orofacial", ...
                "Parent", obj.ControlPanel, ...
                "Units", "normalized", ...
                "Enable", "off");
            obj.AddSelectionButton = uicontrol(...
                "Style", "pushbutton", ...
                "String", "Set selection to 'on'", ...
                "Parent", obj.ControlPanel, ...
                "Units", "normalized");
            obj.RemoveSelectionButton = uicontrol(...
                "Style", "pushbutton", ...
                "String", "Set selection to 'off'", ...
                "Parent", obj.ControlPanel, ...
                "Units", "normalized");
            obj.OnValueEditLabel = uicontrol(...
                "Style", "text", ...
                "String", "On value:", ...
                "Parent", obj.ControlPanel, ...
                "Units", "normalized");
            obj.OnValueEdit = uicontrol(...
                "Style", "edit", ...
                "String", "1", ...
                "Parent", obj.ControlPanel, ...
                "Units", "normalized");
            obj.OffValueEditLabel = uicontrol(...
                "Style", "text", ...
                "String", "Off value:", ...
                "Parent", obj.ControlPanel, ...
                "Units", "normalized");
            obj.OffValueEdit = uicontrol(...
                "Style", "edit", ...
                "String", "0", ...
                "Parent", obj.ControlPanel, ...
                "Units", "normalized");

            a = obj.EditFieldLabelLabel;
            b = obj.EditFieldLabel;
            c = obj.AddSelectionButton;
            d = obj.RemoveSelectionButton;
            e = obj.OnValueEditLabel;
            f = obj.OnValueEdit;
            g = obj.OffValueEditLabel;
            h = obj.OffValueEdit;
            x = gobjects();

            grid = [...
                a, b, e, f, g, h;
                c, d, x, x, x, x
                ];

            gridChildren(grid, "ColumnMargins", 0.05, "RowMargins", 0.05, "RowUnits", "characters", "ColumnWidths", 1, "ColumnUnits", "normalized", "FitToWidth", true);

            % Set up control panel in upper left corner
            shrinkToContent(obj.ControlPanel, "PositionType", "InnerPosition", "Margin", [0.01, 0.01], "MarginUnits", "normalized");
            anchorWidget(obj.ControlPanel, "NW", obj.LickList, "SW");
            
            obj.populateLickList();
        end
        function populateLickList(obj)
            entries = {};
            entryData = struct();
            
            entryNum = 1;
            for trialNum = 1:length(obj.VideoFileList)
                lickNums = find([obj.TStats.trial_num] == trialNum);
                [~, videoName, ~] = fileparts(obj.VideoFileList{trialNum});
                entryData(entryNum).trialNum = trialNum;
                entryData(entryNum).lickNum = lickNums;
                entryData(entryNum).type = 'trial';
                entries{entryNum} = sprintf('(%d) %s', trialNum, videoName); %#ok<AGROW> 
                entryNum = entryNum + 1;
                if ~obj.TrialCollapseStates(trialNum)
                    for lickNum = lickNums
                        lickIndex = obj.TStats(lickNum).lick_index;
                        entries{entryNum} = sprintf('    Lick %d', lickIndex);
                        entryData(entryNum).trialNum = trialNum;
                        entryData(entryNum).lickNum = lickNum;
                        entryData(entryNum).type = 'lick';
                        entryNum = entryNum + 1;
                    end
                end
            end
            obj.LickList.String = entries;
            obj.LickList.UserData = entryData;
        end
        function updateVideoFrame(obj, overlayOnly)
            arguments
                obj TongueStatsBrowser
                overlayOnly (1, 1) logical = false
            end
            if ~overlayOnly
                % If we're not just updating the overlay, update everything
                updateVideoFrame@VideoBrowser(obj);
            end
        end
        function UpdatePlotData(obj, trialNum)
            arguments
                obj TongueStatsBrowser
                trialNum double = obj.CurrentTrial
            end
            plots = obj.DisplayFields;
            obj.NavigationData = cell(1, length(plots));
            for plotIdx = 1:length(plots)
                navData = nan(1, obj.getNumFrames());
                lickNums = find([obj.TStats.trial_num] == trialNum);
                for lickIdx = lickNums
                    onset =  obj.TStats(lickIdx).pairs(1);
%                    offset = obj.TStats(lickIdx).pairs(2);
                    nextNavData = obj.TStats(lickIdx).(plots{plotIdx});
                    navData(onset:(onset+length(nextNavData)-1)) = nextNavData;
                end
                obj.NavigationData{plotIdx} = navData;
            end
            obj.drawNavigationData();
        end
        function LickListClickHandler(obj, varargin)
            persistent last_click
            if isempty(last_click)
                last_click = datetime([-inf, 0, 0]);
            end
            this_click = datetime();
            deltaT = seconds(this_click - last_click);
            last_click = this_click;

            if deltaT < 0.25
                % Double click - collapse/expand
                entryData = obj.LickList.UserData(obj.LickList.Value);
                obj.CollapseExpandTrial(entryData.trialNum);
            else
                t = timer("StartDelay", 0.3, "TimerFcn", @(varargin)obj.HandleLickListChange());
                t.start();
            end
        end
        function CollapseExpandTrial(obj, trialNum)
            obj.TrialCollapseStates(trialNum) = ~obj.TrialCollapseStates(trialNum);
            obj.populateLickList();
            % Attempt to select collapsed/expanded trial entry
            idx = find(trialNum == [obj.LickList.UserData.trialNum], 1);
            if ~isempty(idx)
                obj.LickList.Value = idx;
            end
        end
        function HandleLickListChange(obj)
            entryData = obj.LickList.UserData(obj.LickList.Value);
            if entryData.trialNum ~= obj.CurrentTrial
                obj.LickList.Enable = 'off';
                drawnow();
                try
                    % This is a new video - update the VideoData
                    obj.VideoData = obj.VideoFileList{entryData.trialNum};
                catch ME
                    % Ensure the lick list gets re-enabled
                    obj.LickList.Enable = 'on';
                    rethrow(ME);
                end
    
                obj.UpdatePlotData(entryData.trialNum);

                obj.LickList.Enable = 'on';
            end

            lickNums = entryData.lickNum;
            
            firstOnset = obj.TStats(min(lickNums)).pairs(1);
            lastOffset = obj.TStats(max(lickNums)).pairs(2);
            margin = floor((lastOffset - firstOnset)/10);
            newXLim = [firstOnset - margin, lastOffset + margin] ./ obj.VideoFrameRate;
            obj.NavigationZoom = diff(newXLim) / obj.getDuration();
            obj.CurrentFrameNum = firstOnset;
            obj.CurrentTrial = entryData.trialNum;
            obj.NavigationAxes(1).XLim = newXLim;

            hold(obj.NavigationAxes(1), 'on')
            obj.updateFrameMarker();
            hold(obj.NavigationAxes(1), 'off')
        end
        function VideoClickHandler(obj, src, evt)
            VideoClickHandler@VideoBrowser(obj, src, evt);
%            [x, y] = obj.getCurrentVideoPoint();
            switch obj.MainFigure.SelectionType
                case 'normal'
            end
        end
        function KeyPressHandler(obj, src, evt)
            KeyPressHandler@VideoBrowser(obj, src, evt);
            switch evt.Key
                case 'z'
                    if any(strcmp(evt.Modifier, 'control'))
                        obj.Undo();
                    end
                case 'y'
                    if any(strcmp(evt.Modifier, 'control'))
                        obj.Redo();
                    end
            end
        end
        function MouseMotionHandler(obj, src, evt)
            MouseMotionHandler@VideoBrowser(obj, src, evt);
            x = src.CurrentPoint(1, 1);
            y = src.CurrentPoint(1, 2);
            if obj.inVideoAxes(x, y)
%                [x, y] = obj.getCurrentVideoPoint();
            end
        end
        function ScrollWheelHandler(obj, src, evt)
            x = src.CurrentPoint(1, 1);
            y = src.CurrentPoint(1, 2);
            zoomFactor = 0.1;
            if obj.inNavigationAxes(x, y)
                evt.VerticalScrollCount
                obj.NavigationZoom = obj.NavigationZoom + (1 + evt.VerticalScrollCount*zoomFactor)*zoomFactor;
            end
        end
        function MouseDownHandler(obj, src, evt)
            MouseDownHandler@VideoBrowser(obj, src, evt)
            x = src.CurrentPoint(1, 1);
            y = src.CurrentPoint(1, 2);
            switch obj.MainFigure.SelectionType
                case 'normal'
                    if obj.inVideoAxes(x, y)
                    end
            end
        end
        function MouseUpHandler(obj, src, evt)
            MouseUpHandler@VideoBrowser(obj, src, evt)
        end
        function state = getState(obj)
            % Get current state (for the undo/redo stack)
            state.frameNum = obj.CurrentFrameNum;
        end
        function setState(obj, state)
            % Set current state (from the undo/redo stack)
            obj.CurrentFrameNum = state.frameNum;
            obj.updateVideoFrame();
        end
        function ClearStack(obj)
            if ~isempty(obj.Stack)
                obj.Stack.Clear();
            end
        end
        function SaveState(obj)
            if ~isempty(obj.Stack)
                obj.Stack.SaveState(obj.getState());
            end
        end
        function Undo(obj)
            if ~isempty(obj.Stack)
                currentState = obj.getState();
                newState = obj.Stack.UndoState(currentState);
                obj.setState(newState);
            end
        end
        function Redo(obj)
            if ~isempty(obj.Stack)
                currentState = obj.getState();
                newState = obj.Stack.RedoState(currentState);
                obj.setState(newState);
            end
        end
    end
end