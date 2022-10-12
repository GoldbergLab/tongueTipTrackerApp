classdef tongueTipTrackerApp_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        FPGAdataformatDropDown          matlab.ui.control.DropDown
        FPGAdataformatDropDownLabel     matlab.ui.control.Label
        DeactivateallButton             matlab.ui.control.Button
        ActivateallButton               matlab.ui.control.Button
        SetupsessiondirectoriesLabel    matlab.ui.control.Label
        HelpButton                      matlab.ui.control.Button
        cursorPositionLabel             matlab.ui.control.Label
        HoverovertheimageandpressLabel  matlab.ui.control.Label
        FPGAdataprocessingLabel         matlab.ui.control.Label
        MaskprocessingLabel             matlab.ui.control.Label
        VideoprocessingLabel            matlab.ui.control.Label
        OverlayMasksCheckBox            matlab.ui.control.CheckBox
        DIncorporateFPGAdataintotiptracksButton  matlab.ui.control.Button
        ClearButton                     matlab.ui.control.Button
        PlotNplickOutputCheckBox        matlab.ui.control.CheckBox
        BProcessFPGAdataButton          matlab.ui.control.Button
        ACombineconvertFPGAdatfilesButton  matlab.ui.control.Button
        CAlignFPGAandVideoTrialsButton  matlab.ui.control.Button
        reloadVideoBrowser              matlab.ui.control.Button
        DryrunlabelingCheckBox          matlab.ui.control.CheckBox
        BLabelvideoswcuelaserButton     matlab.ui.control.Button
        BGetlicksegmentationandkinematicsButton  matlab.ui.control.Button
        OpenselecteddirectoryButton     matlab.ui.control.Button
        BotSpoutXLabel                  matlab.ui.control.Label
        TopSpoutXLabel                  matlab.ui.control.Label
        BotFiducialLabel                matlab.ui.control.Label
        TopFiducialLabel                matlab.ui.control.Label
        CleardatatableButton            matlab.ui.control.Button
        LoadDataTableButton             matlab.ui.control.Button
        SaveDataTableButton             matlab.ui.control.Button
        TrackTongueTipsButton           matlab.ui.control.Button
        SaveKinematicsPlotsCheckBox     matlab.ui.control.CheckBox
        SaveTrackingDataCheckBox        matlab.ui.control.CheckBox
        PlotKinematicsCheckBox          matlab.ui.control.CheckBox
        MakeMoviesCheckBox              matlab.ui.control.CheckBox
        VerboseCheckBox                 matlab.ui.control.CheckBox
        TiptrackprocessingLabel         matlab.ui.control.Label
        StartParallelPoolButton         matlab.ui.control.Button
        ParallelPoolStateLabel          matlab.ui.control.Label
        AConvertCINEstoAVIsButton       matlab.ui.control.Button
        TongueTipTrackerLabel           matlab.ui.control.Label
        Output                          matlab.ui.control.TextArea
        OutputLabel_2                   matlab.ui.control.Label
        CurrentVideoLabel               matlab.ui.control.Label
        ShowMarkersCheckBox             matlab.ui.control.CheckBox
        MarkerInstructionLabel          matlab.ui.control.Label
        ShowCrosshairCheckBox           matlab.ui.control.CheckBox
        FindDirectoryButton             matlab.ui.control.Button
        LoadVideoButton                 matlab.ui.control.Button
        VideoBrowserLabel               matlab.ui.control.Label
        VideoBrowser                    matlab.ui.container.Tree
        AddSessionButton                matlab.ui.control.Button
        FrameSlider                     matlab.ui.control.Slider
        FrameLabel                      matlab.ui.control.Label
        SessionDataTable                matlab.ui.control.Table
        ImageAxes                       matlab.ui.control.UIAxes
    end


    properties (Access = private)
        newSessionRow               table
        videoBrowserSessionNodes    matlab.ui.container.TreeNode
        sessionDataTableSelection   uint16
        currentVideo                struct
        currentFrame                matlab.graphics.primitive.Image
        crosshair                   matlab.graphics.primitive.Line
        currentDataTable            table
        imageMarkers                struct
        maxOutputLength             uint16
        markerColors                struct
        dataTableAutoSaveName       char
    end

    methods (Access = private)

        function updateFrame(app, frameNum)
            if isempty(app.currentVideo.Data)
                % No video loaded
                return;
            end
            frame = app.currentVideo.Data(:, :, frameNum);
            if app.OverlayMasksCheckBox.Value && ~isempty(app.currentVideo.SessionMaskDir)
                if ~isempty(app.currentVideo.MaskData)
                    frame = imfuse(frame, app.currentVideo.MaskData(:, :, frameNum));
                else
                    app.print('Masks not loaded...something went wrong.')
                end
            end
            
            if isempty(app.currentFrame)
                app.currentFrame = imshow(frame, 'Parent', app.ImageAxes);
            else
                app.currentFrame.CData = frame;
            end
        end
            
        function addVideoBrowserSession(app, sessionMaskDir, sessionVideoDir)
            if isempty(sessionVideoDir)
                % No video dir specified, default to mask dir
                videoDir = sessionMaskDir;
            else
                videoDir = sessionVideoDir;
            end
            if ~isempty(videoDir)
                [~, videoDirName, ~] = fileparts(videoDir);
                dirStruct.sessionMaskDir = sessionMaskDir;
                dirStruct.sessionVideoDir = sessionVideoDir;
                newSessionNode = uitreenode(app.VideoBrowser, 'Text', videoDirName, 'NodeData', videoDir, 'UserData', dirStruct, 'Tag', 'session');
                app.videoBrowserSessionNodes = [app.videoBrowserSessionNodes, newSessionNode];
                videos = dir(fullfile(videoDir, '*.avi'));
                for j = 1:numel(videos)
                    uitreenode(newSessionNode, 'Text', videos(j).name, 'Tag', 'video', 'NodeData', struct());
                end
            end
        end
        
        function deleteVideoBrowserSession(app, SessionMaskDir)
            delete(app.videoBrowserSessionNodes(strcmp(SessionMaskDir, {app.videoBrowserSessionNodes.UserData.sessionMaskDir})));
        end

        function videoNode = getVideoNode(app, sessionMaskDir, sessionVideoDir, videoName)
            % Find a video node in the video tree by session dirs and filename
            % Loop over video session nodes:
            for s = 1:numel(app.videoBrowserSessionNodes)
                sessionNode = app.videoBrowserSessionNodes(s);
                % Filter out video nodes that do not match the session mask
                % or video dirs:
                if strcmp(sessionNode.UserData.sessionMaskDir, sessionMaskDir) && strcmp(sessionNode.UserData.sessionVideoDir, sessionVideoDir)
                    % Loop over matching sessions (usually should just be one?)
                    for v = 1:numel(sessionNode.Children)
                        videoNode = sessionNode.Children(v);
                        if strcmp(videoNode.Text, videoName)
                            % Found the matching video node - return.
                            return
                        end
                    end
                end
            end
            videoNode = matlab.ui.container.TreeNode.empty;
        end
        
        function updateVideoBrowser(app, sessionMaskDir, sessionVideoDir)
            app.print('Updating video browser');
%             if exist('SessionMaskDir', 'var')
%                 if any(strcmp(sessionMaskDir, {app.videoBrowserSessionNodes.UserData}))
%                     % Given SessionMaskDir already exists. Delete it.
%                     app.deleteVideoBrowserSession(sessionMaskDir)
%                 end
%                 % Given SessionMaskDir does not exist. Add it.
%                 app.addVideoBrowserSession(sessionMaskDir, sessionVideoDir);
%             else
% hi

            % Update all session mask dirs to match UI table, and videos to
            %   match directory contents.
            delete(app.VideoBrowser.Children);
            app.videoBrowserSessionNodes = matlab.ui.container.TreeNode.empty;
            for k = 1:numel(app.SessionDataTable.Data.SessionMaskDirs)
                sessionMaskDir = app.SessionDataTable.Data.SessionMaskDirs{k};
                sessionVideoDir = app.SessionDataTable.Data.SessionVideoDirs{k};
                app.addVideoBrowserSession(sessionMaskDir, sessionVideoDir);
            end
            
            % Reconnect new video node to app.currentVideo if possible
            videoNode = app.getVideoNode(app.currentVideo.SessionMaskDir, app.currentVideo.SessionVideoDir, app.currentVideo.videoName);
            app.currentVideo.videoNode = videoNode;
        end
        
        function mouseMotionHandler(app, varargin)
            currentPoint = app.ImageAxes.CurrentPoint(1, 1:2);
            curX = currentPoint(1); curY = currentPoint(2);
            minX = app.ImageAxes.XLim(1); maxX = app.ImageAxes.XLim(2);
            minY = app.ImageAxes.YLim(1); maxY = app.ImageAxes.YLim(2);
            if app.ShowCrosshairCheckBox.Value && curX >= minX && curX <= maxX && curY >= minY && curY <= maxY
                % Mouse is within boundaries of image
%                 if app.ShowPointerCheckBox.Value
%                     set(app.UIFigure, 'Pointer', 'custom', 'PointerShapeCData', NaN(16,16));
%                 else
%                     set(app.UIFigure, 'Pointer', 'arrow');
%                 end
                app.cursorPositionLabel.Text = [num2str(round(curX)), ', ', num2str(round(curY))];
                if isempty(app.crosshair)
                    % Lines have not been created yet. Create them.
                    app.crosshair(1) = line(app.ImageAxes, [minX, maxX], [curY, curY], 'LineStyle', '--', 'Color', [1, 0, 0], 'LineWidth', 1);
                    app.crosshair(2) = line(app.ImageAxes, [curX, curX], [minY, maxY], 'LineStyle', '--', 'Color', [1, 0, 0], 'LineWidth', 1);
                else
                    app.crosshair(1).YData = [curY, curY];
                    app.crosshair(2).XData = [curX, curX];
                end
            else
%                 set(app.UIFigure, 'Pointer', 'arrow');
                % Mouse is outside boundaries of image
                app.cursorPositionLabel.Text = '';
                if ~isempty(app.crosshair)
                    delete(app.crosshair(1))
                    delete(app.crosshair(2))
                    app.crosshair = matlab.graphics.primitive.Line.empty;
                end
            end
        end
        
        function [valid, reasons] = updateDataTable(app, newDataTable, validate, autosave)
            if ~exist('validate', 'var')
                validate = true;
            end
            if ~exist('autosave', 'var')
                autosave = false;
            end
            if validate
                [valid, reasons] = app.validateDataTable(newDataTable);
            else
                valid = logical.empty;
                reasons = {};
            end
            if ~validate || valid
                app.SessionDataTable.Data = newDataTable;
                % Store current data, in case we need to revert.
                oldDataTable = app.currentDataTable;
                app.currentDataTable = newDataTable;
                % Erase and reset data table to reflect new data.
%                app.SessionDataTable.Data = [];  %Not actually necessary
            
                if ~isempty(oldDataTable) && ~isempty(newDataTable)
                    diffs = tdiff(oldDataTable, newDataTable);
                    if isfield(diffs, 'SessionVideoDirs') || isfield(diffs, 'SessionMaskDirs')
                        % One or more of the video directories has been changed.
                        % Update video browser
                        app.updateVideoBrowser();
                    end
                else
                    app.updateVideoBrowser();
                end
                % Update image markers
                app.updateMarkers()
                drawnow;
            else
                app.print(['Invalid data:', reasons])
                warndlg(reasons, 'Invalid data');
            end
            if autosave
                app.saveDataTable(app.dataTableAutoSaveName);
            end
        end
        
        function data = getDataTable(app, all)
            if ~exist('all', 'var')
                all = false;
            end
            % Return the selected rows of the current data table  or all
            % the rows if "all" is true.
            data = app.SessionDataTable.Data(app.SessionDataTable.Data.Active | all, :);
        end
        
        function isBlank = isTableRowBlank(app, tableRow)
            % Check if table row is blank or not
            isBlank = isempty(tdiff(tableRow, app.newSessionRow));
        end
        
        function [valid, reasons] = validateDataTable(app, newDataTable)
            n = numel(newDataTable.SessionMaskDirs);
            m = numel(unique(newDataTable.SessionMaskDirs));
            valid = true;
            reasons = {};
            if (n ~= m)
                valid = false;
                reasons = [reasons, 'Duplicate session mask dirs'];
            end
            if ~all(newDataTable.Top_Y0 >= 0)
                % Top Y0 can't be negative
                valid = false;
                reasons = [reasons, 'Top box Y0 must be greater than or equal to zero'];
            end
%             if ~all((newDataTable.Top_Y0 < newDataTable.Top_Y1) | (newDataTable.TopY1 == -1)) || ~all((newDataTable.Bot_Y0 < newDataTable.Bot_Y1) | (newDataTable.Bot_Y1 == -1))
%                 % Some Y0 is not smaller than Y1
%                 valid = false;
%                 reasons = [reasons, 'Box Y''s must be smaller than corresponding Y1''s'];
%             end
            for k = 1:height(newDataTable)
                if app.isTableRowBlank(newDataTable(k, :))
                    % kth row is just a  blank row. Ignore it.
                    continue;
                end
                sessionMaskDir = newDataTable.SessionMaskDirs{k};
                sessionVideoDir = newDataTable.SessionVideoDirs{k};
                if ~isempty(sessionMaskDir) && ~exist(sessionMaskDir, 'file')
                    valid = false;
                    reasons = [reasons, ['Invalid mask directory: ', sessionMaskDir]];
                else
                    if ~isempty(sessionMaskDir) && ~exist(sessionMaskDir, 'dir')
                        valid = false;
                        reasons = [reasons, ['Mask directory must be a directory, not a file: ', sessionMaskDir]];
                    end
                end
                if ~isempty(sessionVideoDir) && ~exist(sessionVideoDir, 'file')
                    valid = false;
                    reasons = [reasons, ['Invalid video directory: ', sessionVideoDir]];
                else
                    if ~isempty(sessionVideoDir) && ~exist(sessionVideoDir, 'dir')
                        valid = false;
                        reasons = [reasons, ['Video directory must be a directory, not a file: ', sessionVideoDir]];
                    end
                end
            end
        end
        
        function rows = getDataTableRowsByVideoDir(app, sessionVideoDir)
            % Find row indices by video dir. This may return more than one
            % index, as video directories are not guaranteed to be unique.
            tableData = app.getDataTable(true);
            numRows = height(tableData);
            idx = 1:numRows;
            rows = idx(strcmp(sessionVideoDir, tableData.SessionVideoDirs));
        end
        
        function sessionMaskDirInDataTable = isSessionMaskDirInDataTable(app, sessionMaskDir)
            tableData = app.getDataTable(true);
            sessionMaskDirInDataTable = any(strcmp(sessionMaskDir, tableData.SessionMaskDirs));
        end
        
        function row = getDataTableRow(app, sessionMaskDir)
            % Find row index by session mask dir. This will only return one
            % index, as session mask dirs are guaranteed to be unique. If
            % it does find more than one row match, it will raise an error.
            tableData = app.getDataTable(true);
            numRows = height(tableData);
            idx = 1:numRows;
            row = idx(strcmp(sessionMaskDir, tableData.SessionMaskDirs));
            if isempty(row)
                disp(sessionMaskDir)
                error('Nonexistent sessionMaskDir was supplied for setDataTableElements.')
            elseif numel(row) > 1
                error('Duplicate sesionMaskDirs detected. That should not be possible.')
            end
        end
        
        function setDataTableElements(app, properties, values, sessionMaskDirs)
            if ~exist('sessionMaskDirs', 'var')
                % No session mask dir given, use the one associated with the
                %   current video.
                sessionMaskDirs = app.currentVideo.videoNode.Parent.UserData.sessionMaskDir;
            end
            tableData = app.getDataTable(true);
            for k = 1:numel(properties)
                if iscell(sessionMaskDirs)
                    sessionMaskDir = sessionMaskDirs{k};
                else
                    sessionMaskDir = sessionMaskDirs;
                end
                if iscell(properties)
                    property = properties{k};
                else
                    property = properties;
                end
                if iscell(values)
                    % Values is a cell array
                    if numel(values) > 1
                        value = values{k};
                    else
                        value = values{1};
                    end
                elseif ischar(values)
                    % Values is a char array representing one property
                    value = values;
                elseif numel(values) > 1
                    % Value is not a char array or a cell array, and there's
                    % more than one element - index it.
                    value = values(k);
                else
                    % Value is not a char array or a cell array, and
                    % there's only one element.
                    value = values;
                end

                row = app.getDataTableRow(sessionMaskDir);
                if isempty(row)
                    error('Nonexistent sessionMaskDir was supplied for setDataTableElements.')
                elseif numel(row) > 1
                    error('Duplicate sesionMaskDirs detected. That should not be possible.')
                end
                if iscell(tableData.(property))
                    value = cell(value);
                end
                tableData.(property)(row) = value;
            end
            app.updateDataTable(tableData, true, true);
        end

        function clearMarkers(app)
            if ~isempty(app.imageMarkers)
                delete(app.imageMarkers.topSpoutX);
                delete(app.imageMarkers.botSpoutX);
                delete(app.imageMarkers.topFiducial);
                delete(app.imageMarkers.botFiducial);
%                 delete(app.imageMarkers.topBox);
%                 delete(app.imageMarkers.botBox);
                app.imageMarkers = struct.empty;
            end
        end
        
        function updateMarkers(app)
            % Update fiducial and spout reference markers.
            if ~isempty(app.currentVideo.Data) && app.ShowMarkersCheckBox.Value
                % A video is loaded
                rows = app.getDataTableRowsByVideoDir(app.currentVideo.SessionVideoDir);
                if length(rows) > 1
                    app.print('Warning, the current video''s directory is associated with multiple data table rows. If this is not intended, you may want to check that your video directories are correct. Using the first row match.');
                    row = rows(1);
                elseif isempty(rows)
                    error('Something went wrong. Attempting to update markers on current video, but current video does not match any video directories found in data table.');
                else
                    % Exactly one row matched.
                    row = rows;
                end
                dataTable = app.getDataTable(true);
                topSpoutX = dataTable.Top_Spout_X(row);
                botSpoutX = dataTable.Bot_Spout_X(row);
                topFiducialY = dataTable.Top_Fiducial_Y(row);
                botFiducialY = dataTable.Bot_Fiducial_Y(row);
                fiducialX = dataTable.Fiducial_X(row);
%                 topY0 = dataTable.Top_Y0(row);
%                 topY1 = dataTable.Top_Y1(row);
%                 botY0 = dataTable.Bot_Y0(row);
%                 botY1 = dataTable.Bot_Y1(row);
                
                minX = app.ImageAxes.XLim(1); maxX = app.ImageAxes.XLim(2);
                minY = app.ImageAxes.YLim(1); maxY = app.ImageAxes.YLim(2);
                
                if isempty(app.imageMarkers)
                    app.imageMarkers(1).topSpoutX = line(app.ImageAxes, [topSpoutX, topSpoutX], [minY, maxY], 'LineStyle', '--', 'Color', [0, 1, 0], 'LineWidth', 1);
                    app.imageMarkers(1).botSpoutX = line(app.ImageAxes, [botSpoutX, botSpoutX], [minY, maxY], 'LineStyle', '--', 'Color', [0.1, 0.1, 1], 'LineWidth', 1);
                    app.imageMarkers(1).topFiducial = line(app.ImageAxes, fiducialX, topFiducialY, 'Marker', 'x', 'MarkerSize', 10, 'LineStyle', 'none', 'Color', [0, 1, 1]);
                    app.imageMarkers(1).botFiducial = line(app.ImageAxes, fiducialX, botFiducialY, 'Marker', 'x', 'MarkerSize', 10, 'LineStyle', 'none', 'Color', [1, 0, 1]);
%                     app.imageMarkers(1).topBox = rectangle(app.ImageAxes, 'Position', [minX, topY0, maxX-minX, topY1-topY0], 'LineStyle', ':', 'EdgeColor', [0.5, 0.5, 1], 'LineWidth', 2);
%                     app.imageMarkers(1).botBox = rectangle(app.ImageAxes, 'Position', [minX, botY0, maxX-minX, botY1-botY0], 'LineStyle', ':', 'EdgeColor', [0.5, 1, 0.5], 'LineWidth', 2);
                else
                    app.imageMarkers.topSpoutX.XData = [topSpoutX, topSpoutX];
                    app.imageMarkers.topSpoutX.YData = [minY, maxY];
                    app.imageMarkers.botSpoutX.XData = [botSpoutX, botSpoutX];
                    app.imageMarkers.botSpoutX.YData = [minY, maxY];
                    app.imageMarkers.topFiducial.XData = fiducialX;
                    app.imageMarkers.topFiducial.YData = topFiducialY;
                    app.imageMarkers.botFiducial.XData = fiducialX;
                    app.imageMarkers.botFiducial.YData = botFiducialY;
%                     app.imageMarkers.topBox.Position = [minX, topY0, maxX-minX, topY1-topY0];
%                     app.imageMarkers.botBox.Position = [minX, botY0, maxX-minX, botY1-botY0];
                end
                if topSpoutX < 0
                    app.imageMarkers.topSpoutX.Visible = 'off';
                else
                    app.imageMarkers.topSpoutX.Visible = 'on';
                end
                if botSpoutX < 0
                    app.imageMarkers.botSpoutX.Visible = 'off';
                else
                    app.imageMarkers.botSpoutX.Visible = 'on';
                end
                if topFiducialY < 0 || fiducialX < 0
                    app.imageMarkers.topFiducial.Visible = 'off';
                else
                    app.imageMarkers.topFiducial.Visible = 'on';
                end
                if botFiducialY < 0 || fiducialX < 0
                    app.imageMarkers.botFiducial.Visible = 'off';
                else
                    app.imageMarkers.botFiducial.Visible = 'on';
                end
                drawnow;
            else
                app.clearMarkers();
            end
        end
        
        function print(app, msg)
            outputText = app.Output.Value';
            if ~iscell(outputText)
                if isempty(outputText)
                    outputText = {};
                else
                    outputText = cell(outputText);
                end
            end
            outputText = [outputText, msg];
            if numel(outputText) > app.maxOutputLength
                outputText = outputText(1:app.maxOutputLength);
            end
            app.Output.Value = outputText;
            drawnow;
        end
        
        function updateParallelPoolStateLabel(app)
            p = gcp('nocreate');
            labelTitle = 'Parallel pool:';
            if isempty(p)
                app.ParallelPoolStateLabel.Text = {labelTitle, 'Not started'};
            else
                app.ParallelPoolStateLabel.Text = {labelTitle, ['Ready - ', num2str(p.NumWorkers), ' workers']};
            end
        end
        
        function getTongueTipSessionsTrack(app)
            app.print('Beginning tongue tip tracking for all sessions.');
            dataTable = app.getDataTable();
            sessionDataRoots = dataTable.SessionMaskDirs;
            im_shifts = dataTable.Bot_Spout_X - dataTable.Top_Spout_X;

            verboseFlag = app.VerboseCheckBox.Value;
            makeMovieFlag = app.MakeMoviesCheckBox.Value;
            saveDataFlag = app.SaveTrackingDataCheckBox.Value;
            savePlotsFlag = app.SaveKinematicsPlotsCheckBox.Value;
            plotFlag = app.PlotKinematicsCheckBox.Value;
            
            % set up base params
            baseParams = setTrackParams();
            baseParams.N_pix_min = 100;
            baseParams.figPosition = [1921, 41, 1920, 963];
            
            % If parallel pool hasn't been initialized, initialize it.
            app.StartParallelPoolButtonPushed()

            % loop through session data folders
            for j = 1:numel(sessionDataRoots)
                sessionDataRoot = sessionDataRoots{j};
                if verboseFlag
                    disp(['Processing session #', num2str(j), ': ', sessionDataRoot])
                end
                params(j) = baseParams;
                params(j).im_shift = im_shifts(j);
                
                % Queue for getting stdout from parfeval functions
                queue = parallel.pool.DataQueue();
                afterEach(queue, @app.print);
                
                tip_track_futures = getTongueTipSessionTrack(sessionDataRoot, queue, 'params', params(j), ...
                    'verboseFlag', verboseFlag);

                saveFilePath = fullfile(sessionDataRoot, 'tip_track');

                tip_tracks = [];
                for k = 1:numel(tip_track_futures)
                    app.print(['Processing session from ', sessionDataRoot, '...'])
                    [~, next_tip_tracks] = fetchNext(tip_track_futures(k));
                    tip_tracks = [tip_tracks, next_tip_tracks];
                    
%                     % make movie of raw results?
%                     if makeMovieFlag
%                         makeMoviePlots(next_tip_tracks, params, bot_mask, top_mask,...
%                             vidFilePath, savePlotsFlag, saveFilePath)
%                     end
%                     % plot results?
%                     if plotFlag
%                         [h_3d, h_speed, h_curv, h_tors] = ...
%                             plotLickBoutKinematics(next_tip_tracks, params, saveFilePath, ...
%                             savePlotsFlag);
%                     end
                end

                % save data structure?
                if saveDataFlag
                    [path, fname, ~] = fileparts(saveFilePath) ;
                    save(fullfile(path, [fname '.mat']), 'tip_tracks')
                end

            end
            app.print('Tongue tip tracking completed!');
        end
        
        function saveDataTable(app, filepath)
            dataTable = app.getDataTable(true);
            save(filepath, 'dataTable');
        end
        
        function column = getColumnNum(app, dataField)
            column = find(strcmp(app.getDataTable(true).Properties.VariableNames, dataField));
        end

        function startingTrialNums = alignTDiffs(app, sessionDataRoots, tdiffs_FPGA, tdiffs_Video)
            f = figure('Units', 'normalized', 'Position', [0.1, 0, 0.8, 0.85]);
            % Overwrite function close callback to prevent user from
            % clicking "x", which would destroy data. User must use
            % "Accept" button instead
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
            end
            
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
        end
        
        function [topMaskPath, botMaskPath] = matchMaskToVideo(app, videoName, SessionVideoRoot, SessionMaskRoot)
            % Strip path and extension from videoname, if present.
            [~, videoName, ~] = fileparts(videoName);
            videos = findFilesByRegex(SessionVideoRoot, '.*\.avi$');
            topMasks = findFilesByRegex(SessionMaskRoot, 'Top_[0-9]*\.mat$');
            botMasks = findFilesByRegex(SessionMaskRoot, 'Bot_[0-9]*\.mat$');

            if numel(topMasks) ~= numel(botMasks)
               app.print('Warning: The number of top and bottom masks found do not match...something may be wrong. Check mask file numbering.')
            elseif numel(topMasks) ~= numel(videos)
                app.print('Warning: Number of videos found does not match the number of masks. Check the numbering system, directories, etc.')
            end
            
            videoIndex = NaN;
            for videoNum = 1:numel(videos)
                [~, videoNameCheck, ~] = fileparts(videos{videoNum});
                if strcmp(videoName, videoNameCheck)
                    videoIndex = videoNum;
                    break;
                end
            end
            if isnan(videoIndex)
                app.print('Error finding video in video directory...this shouldn''t happen...');
            end
            if numel(topMasks) >= videoIndex && numel(botMasks) >= videoIndex
                topMaskPath = topMasks{videoIndex};
                botMaskPath = botMasks{videoIndex};
            else
                topMaskPath = '';
                botMaskPath = '';
                app.print('Error - could not find mask that matches selected video - not enough masks in directory')
            end
        end

        function [videoHeight, videoWidth] = getSessionVideoFrameSize(app, sessionVideoDir)
            videos = findFilesByRegex(sessionVideoDir, '.*\.avi$');
            % Set up video reader for first video in directory
            v = VideoReader(videos{1});
            % Get width and height of video (without loading whole video)
            videoHeight = v.Height;
            videoWidth = v.Width;
        end
        
        function [topMaskSize, botMaskSize] = getSessionMaskSizes(app, SessionMaskDir)
            sessionRowNum = app.getDataTableRow(SessionMaskDir);
            dataTable = app.getDataTable(true);
            sessionMaskRoot = dataTable.SessionMaskDirs{sessionRowNum};
            topMasks = findFilesByRegex(sessionMaskRoot, 'Top_[0-9]*\.mat$');
            botMasks = findFilesByRegex(sessionMaskRoot, 'Bot_[0-9]*\.mat$');
            maskDataTop = app.loadMaskData(topMasks{1});
            maskDataBot = app.loadMaskData(botMasks{1});
            topMaskSize = size(maskDataTop);
            botMaskSize = size(maskDataBot);
        end
        
        function maskData = loadMaskData(app, maskPath)
            % Load mask data from file
            loadedData = load(maskPath);
            % Extract data from struct and swap dimensions so time is the
            %   3rd dimension instead of the 1st.
            maskData = permute(loadedData.mask_pred, [2, 3, 1]);
        end
        
        function maskData = loadMaskVideo(app, topMaskPath, botMaskPath, videoSize, pix_shift)
            % Create blank video to load mask data into
            maskData = zeros(videoSize, 'logical');
            maskDataTop = app.loadMaskData(topMaskPath);
            maskDataBot = app.loadMaskData(botMaskPath);
            % Insert bottom and top masks into video data, using pix-shift
            %   to set position of top mask in video coordinates.
            %   Top mask is from pix_shift+1 down, bottom mask is
            [hBot, ~, ~] = size(maskDataBot);
            [hTop, ~, ~] = size(maskDataTop);
            hVid = videoSize(1);
            wVid = videoSize(2);
            maskData((1+pix_shift(1)):(hTop+pix_shift(1)), 1:wVid, :) = maskDataTop;
            maskData((hVid - hBot + 1):hVid, 1:wVid, :) = maskData((hVid - hBot + 1):hVid, 1:wVid, :) + maskDataBot;
        end
        
        function frameNum = getCurrentFrameNum(app)
            frameNum = floor(app.FrameSlider.Value);
        end
        
        function loadCurrentVideoMasks(app)
            if ~exist(app.currentVideo.SessionMaskDir, 'dir')
                app.print('No mask directory provided yet, skipping mask load.');
                return;
            end
            app.print('Loading corresponding masks...')
            dataTable = app.getDataTable(true);
            dataTableRow = app.getDataTableRow(app.currentVideo.SessionMaskDir);
            pix_shift = dataTable.Top_Y0(dataTableRow);
            % Find masks that correspond to this video
            [topMaskPath, botMaskPath] = app.matchMaskToVideo(app.currentVideo.videoName, app.currentVideo.SessionVideoDir, app.currentVideo.SessionMaskDir);
            if ~isempty(topMaskPath) && ~isempty(botMaskPath)
                % Load up mask data
                app.currentVideo.MaskData = app.loadMaskVideo(topMaskPath, botMaskPath, size(app.currentVideo.Data), pix_shift);
            else
                app.currentVideo.MaskData = [];
                app.print('Error - could not load masks associated with video.');
            end
            app.print('    ...done loading corresponding masks.')
        end
        
        function fiducialPoint = getFiducialPoint(app, k)
            % Get the anatomical fiducial point in 3D space for session # k
            dataTable = app.getDataTable();
            [~, botMaskSize] = app.getSessionMaskSizes(dataTable.SessionMaskDirs{k});
            [videoHeight, ~] = app.getSessionVideoFrameSize(dataTable.SessionVideoDirs{k});
            top_pix_shift = dataTable.Top_Y0(k);
            fiducial_ML = app.SessionDataTable.Data.Bot_Fiducial_Y(k) - (videoHeight - botMaskSize(1));
            fiducial_AP = app.SessionDataTable.Data.Fiducial_X(k);
            fiducial_DV = app.SessionDataTable.Data.Top_Fiducial_Y(k) - top_pix_shift;
            fiducialPoint = [fiducial_ML, fiducial_AP, fiducial_DV];
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Set constants
            app.markerColors = struct();
            app.markerColors.topFiducial = [0, 1, 1];
            app.markerColors.botFiducial = [1, 0, 1];
            app.markerColors.topSpoutX = [0, 1, 0];
            app.markerColors.botSpoutX = [0.1, 0.1, 1];
            app.markerColors.topBox = [0.5, 0.5, 1];
            app.markerColors.botBox = [0.5, 1, 0.5];
            
            app.TopFiducialLabel.FontColor = app.markerColors.topFiducial;
            app.BotFiducialLabel.FontColor = app.markerColors.botFiducial;
            app.TopSpoutXLabel.FontColor = app.markerColors.topSpoutX;
            app.BotSpoutXLabel.FontColor = app.markerColors.botSpoutX;

            app.TopFiducialLabel.BackgroundColor = 0.8*[1, 1, 1];
            app.BotFiducialLabel.BackgroundColor = 0.8*[1, 1, 1];
            app.TopSpoutXLabel.BackgroundColor = 0.8*[1, 1, 1];
            app.BotSpoutXLabel.BackgroundColor = 0.8*[1, 1, 1];

            app.dataTableAutoSaveName = 'tongueTrackerDataTableAutoSave.mat';
            
            % Configure image axes
            app.ImageAxes.Visible = 'off';
            app.ImageAxes.Colormap = gray(256);
            axis(app.ImageAxes, 'image');
            app.UIFigure.WindowButtonMotionFcn = @app.mouseMotionHandler;
            
            app.currentVideo = struct();
            app.currentVideo.Data = [];
%            app.currentVideo.Path = '';
            app.currentVideo.videoName = '';
            app.currentVideo.SessionVideoDir = '';
            app.currentVideo.SessionMaskDir = '';
            app.currentVideo.videoNode = [];

            app.imageMarkers = struct.empty;
            
            app.newSessionRow = table(true, {''}, {''}, {''}, -1, -1, -1, -1, -1, 0, 1, 1, 'VariableNames', {'Active', 'SessionMaskDirs', 'SessionVideoDirs', 'SessionFPGADirs', 'Top_Spout_X', 'Bot_Spout_X','Top_Fiducial_Y','Fiducial_X', 'Bot_Fiducial_Y', 'Top_Y0', 'FPGAStartTrial', 'VideoStartTrial'});
            
            app.maxOutputLength = 256;
            
            app.updateParallelPoolStateLabel();
            
            app.updateDataTable(app.newSessionRow, false);
            app.SessionDataTable.ColumnName = app.newSessionRow.Properties.VariableNames;
            app.SessionDataTable.ColumnWidth = {50, 120, 120, 120, 95, 95, 95, 95, 95, 95, 95, 95};
        end

        % Callback function
        function DropDownValueChanged(app, event)
            
            % Update the image and histograms
            updateimage(app, app.FPGAdataformatDropDown.Value);
        end

        % Callback function
        function LoadButtonPushed(app, event)
               
            % Display uigetfile dialog
            filterspec = {'*.jpg;*.tif;*.png;*.gif','All Image Files'};
            [f, p] = uigetfile(filterspec);
            
            % Make sure user didn't cancel uigetfile dialog
            if (ischar(p))
               fname = [p f];
               updateimage(app, fname);
            end
        end

        % Button pushed function: AddSessionButton
        function AddSessionButtonPushed(app, event)
            dataTable = app.getDataTable(true);
            if height(dataTable) == 0
                dataTable = app.newSessionRow;
            else
                dataTable = [dataTable; app.newSessionRow];
            end
            app.updateDataTable(dataTable);
        end

        % Cell edit callback: SessionDataTable
        function SessionDataTableCellEdit(app, event)
            newDataTable = app.getDataTable(true);
%            indices = event.Indices;
%            row = indices(1); column = indices(2);

%            % Delete any rows where "delete" has been checked
%            newDataTable = newDataTable(~newDataTable.Delete, :);
            difference = tdiff(newDataTable, app.currentDataTable);
            if ~isempty(fields(difference))
                % There is an actual change
                [valid, reasons] = app.validateDataTable(newDataTable);
                if ~valid
                    app.print(['Invalid input data:', reasons])
                    warndlg(reasons, 'Invalid input data');
                    % Changed data is not valid. Revert to original
                    app.updateDataTable(app.currentDataTable, false, true);
                else
                    % Changed data is valid. Apply processed data
                    app.updateDataTable(newDataTable, false, true);
                    if isfield(difference, 'Top_Y0')
                        app.print('Re-rendering masks, please wait...')
                        app.loadCurrentVideoMasks();
                        app.updateFrame(app.getCurrentFrameNum());
                        app.print('     ...done re-rendering masks.')
                    end
                    if isfield(difference, 'Top_Spout_X') || isfield(difference, 'Bot_Spout_X') || isfield(difference, 'Top_Fiducial_Y') || isfield(difference, 'Fiducial_X') || isfield(difference, 'Bot_Fiducial_Y')
                        app.updateMarkers();
                    end
                end
            end
        end

        % Button pushed function: FindDirectoryButton
        function FindDirectoryButtonPushed(app, event)
            row = app.sessionDataTableSelection(1);
            column = app.sessionDataTableSelection(2);
            event = [];
            fakeCellEditEvent.Indices = [row, NaN];
            if column == app.getColumnNum('SessionVideoDirs')
                % Video dir is selected, select that
                newDir = uigetdir('.', 'Select session video root folder (where AVI files can be found)');
                if numel(newDir) > 1
                    app.SessionDataTable.Data.SessionVideoDirs{row} = newDir;
                    fakeCellEditEvent.Indices(2) = 2;
                else
                    % Input cancelled, do nothing
                    return
                end
            elseif column == app.getColumnNum('SessionFPGADirs')
                % FPGA dir is selected, select that
                newDir = uigetdir('.', 'Select session FPGA root folder (where .dat files recorded from the FPGA can be found)');
                if numel(newDir) > 1
                    app.SessionDataTable.Data.SessionFPGADirs{row} = newDir;
                    fakeCellEditEvent.Indices(2) = 2;
                else
                    % Input cancelled, do nothing
                    return
                end
            else
                % Neither video nor FPGA dir is not selected, assume user wants to set root
                %   session dir
                newDir = uigetdir('.', 'Select session data root folder (where masks can be found and data will be saved)');
                if numel(newDir) > 1
                    app.SessionDataTable.Data.SessionMaskDirs{row} = newDir;
                    fakeCellEditEvent.Indices(2) = 1;
                else
                    % Input cancelled, do nothing
                    return
                end
            end
            fakeCellEditEvent.NewData = app.SessionDataTable.Data;
            app.SessionDataTableCellEdit(fakeCellEditEvent);
        end

        % Cell selection callback: SessionDataTable
        function SessionDataTableCellSelection(app, event)
            app.sessionDataTableSelection = event.Indices;
        end

        % Selection changed function: VideoBrowser
        function VideoBrowserSelectionChanged(app, event)
            selectedNodes = app.VideoBrowser.SelectedNodes;
            if ~isempty(selectedNodes) && strcmp(selectedNodes.Tag, 'video')
                % A video is selected. Enable "load video" button
                app.LoadVideoButton.Enable = 'on';
            else
                % Either nothing is selected, or a session (rather than a
                %   video in a session) is selected. Disable "load video"
                %   button
                app.LoadVideoButton.Enable = 'off';
            end
            drawnow;
        end

        % Button pushed function: LoadVideoButton
        function LoadVideoButtonPushed(app, event)
            videoNode = app.VideoBrowser.SelectedNodes;
            videoDir = videoNode.Parent.NodeData;
            videoName = videoNode.Text;
            videoPath = fullfile(videoDir, videoName);
            SessionMaskDir = videoNode.Parent.UserData.sessionMaskDir;
            app.print(['Loading video ', videoName, '...'])
            videoData = loadVideoData(videoPath);
            app.print('    ...done loading video')

            app.currentVideo.Data = videoData;
            app.currentVideo.SessionMaskDir = SessionMaskDir;
            app.currentVideo.SessionVideoDir = videoDir;
            app.currentVideo.videoName = videoName;
%            app.currentVideo.Path = videoPath;
            app.currentVideo.videoNode = videoNode;

            app.currentVideo.MaskData = [];
            loadMasks = app.OverlayMasksCheckBox.Value;
            if loadMasks
                app.loadCurrentVideoMasks();
            end
            
            app.FrameSlider.Limits = [1, size(app.currentVideo.Data, 3)];

            app.updateFrame(1);
            
            app.clearMarkers();
            app.updateMarkers();
            
            app.CurrentVideoLabel.Text = {'Current video: ', videoName};
            app.CurrentVideoLabel.Tooltip = videoName;
        end

        % Value changed function: FrameSlider
        function FrameSliderValueChanged(app, event)
            frameNum = app.getCurrentFrameNum();
            app.updateFrame(frameNum);
        end

        % Value changing function: FrameSlider
        function FrameSliderValueChanging(app, event)
            frameNum = floor(event.Value);
            app.updateFrame(frameNum);
        end

        % Callback function
        function SetTopFiducialButtonPushed(app, event)
            app.currentVideo.videoNode.NodeData.topFiducial = [];
        end

        % Key press function: UIFigure
        function UIFigureKeyPress(app, event)
            key = event.Key;
            switch key
                case '1'
                    % Bot fiducial
                    currentPoint = int16(app.ImageAxes.CurrentPoint(1, 1:2));
                    curX = currentPoint(1); 
                    curY = currentPoint(2);
                    app.setDataTableElements({'Fiducial_X', 'Bot_Fiducial_Y'}, [curX, curY]);
                case '2'
                    % Top fiducial
                    currentPoint = int16(app.ImageAxes.CurrentPoint(1, 1:2));
                    curY = currentPoint(2);
                    app.setDataTableElements('Top_Fiducial_Y', curY);
                case '3'
                    % Top spout
                    curX = int16(app.ImageAxes.CurrentPoint(1, 1));
                    app.setDataTableElements('Top_Spout_X', curX);
                case '4'
                    % Bot spout
                    curX = int16(app.ImageAxes.CurrentPoint(1, 1));
                    app.setDataTableElements('Bot_Spout_X', curX);
            end
            drawnow;
        end

        % Value changed function: ShowMarkersCheckBox
        function ShowMarkersCheckBoxValueChanged(app, event)
            value = app.ShowMarkersCheckBox.Value;
            app.updateMarkers();
        end

        % Button pushed function: StartParallelPoolButton
        function StartParallelPoolButtonPushed(app, event)
            if ~isempty(gcp('nocreate'))
                app.print('Parallel pool already exists.')
            else
                app.print('Creating parallel pool...')
                p = gcp();
                app.print('...done creating parallel pool.')
                app.updateParallelPoolStateLabel();
            end
        end

        % Button pushed function: TrackTongueTipsButton
        function TrackTongueTipsButtonPushed(app, event)
            app.getTongueTipSessionsTrack();
        end

        % Button pushed function: SaveDataTableButton
        function SaveDataTableButtonPushed(app, event)
            [name, path] = uiputfile('*.mat', 'Choose a filename and directory to save data table values for later:');
            filepath = fullfile(path, name);
            app.saveDataTable(filepath)
            app.print(['Saved data table to ', filepath]);
        end

        % Button pushed function: LoadDataTableButton
        function LoadDataTableButtonPushed(app, event)
            [name, path] = uigetfile('', 'Choose a file that contains a saved data table to load:');
            if numel(name) > 1
                filepath = fullfile(path, name);
                loadedVars = load(filepath);
                dataTable = app.newSessionRow;
                for variableNum = 1:width(loadedVars.dataTable)
                    variable = loadedVars.dataTable.Properties.VariableNames{variableNum};
                    if any(strcmp(variable, dataTable.Properties.VariableNames))
                        for rowNum = 1:height(loadedVars.dataTable)
                            dataTable.(variable)(rowNum) = loadedVars.dataTable.(variable)(rowNum);
                        end
                    else
                        app.print(['Discarded variable ''', variable, ''' because it didn''t match any valid variables'])
                    end
                end
                app.updateDataTable(dataTable);
                app.print(['Loaded data table from ', filepath]);
            else
                app.print('Cancel data table load');
            end
        end

        % Button pushed function: CleardatatableButton
        function CleardatatableButtonPushed(app, event)
            answer = uiconfirm(app.UIFigure, 'Are you sure you want to clear the data table?', 'Confirm clear', 'Icon', 'warning');
            if strcmp(answer, 'OK')
                app.updateDataTable(app.newSessionRow, false);
                app.print('Cleared data table');
            end
        end

        % Button pushed function: OpenselecteddirectoryButton
        function OpenselecteddirectoryButtonPushed(app, event)
            row = app.sessionDataTableSelection(1);
            column = app.sessionDataTableSelection(2);
            if column == app.getColumnNum('SessionVideoDirs')
                % Video dir is selected, select that
                dirToOpen = app.SessionDataTable.Data.SessionVideoDirs{row};
            elseif column == app.getColumnNum('SessionFPGADirs')
                % FPGA dir is selected, select that
                dirToOpen = app.SessionDataTable.Data.SessionFPGADirs{row};
            else
                % Video dir is not selected, assume user wants to set root
                %   mask dir
                dirToOpen = app.SessionDataTable.Data.SessionMaskDirs{row};
            end
            if ~isempty(dirToOpen)
                try
                    winopen(dirToOpen);
                catch ME
                    warning('Invalid directory, can''t open')
                end
            end
        end

        % Callback function
        function BCalculatemaskpropertiesButtonPushed(app, event)
            app.print('Calculating mask properites...');
            dataTable = app.getDataTable();
            for k = 1:numel(dataTable.SessionMaskDirs)
                [topMaskSize, botMaskSize] = app.getSessionMaskSizes(dataTable.SessionMaskDirs{k});
                [videoHeight, ~] = app.getSessionVideoFrameSize(dataTable.SessionVideoDirs{k});
                top_pix_shift = dataTable.Top_Y0(k);
                fiducials(k).top = [app.SessionDataTable.Data.Fiducial_X(k), app.SessionDataTable.Data.Top_Fiducial_Y(k) - top_pix_shift];
                fiducials(k).bot = [app.SessionDataTable.Data.Fiducial_X(k), app.SessionDataTable.Data.Bot_Fiducial_Y(k) - (videoHeight - botMaskSize(1))];
            end
            
            queue = parallel.pool.DataQueue();
            afterEach(queue, @app.print);

            get_mask_props(dataTable.SessionMaskDirs, fiducials, queue);    
        end

        % Button pushed function: BLabelvideoswcuelaserButton
        function BLabelvideoswcuelaserButtonPushed(app, event)
            dryrun = app.DryrunlabelingCheckBox.Value;
            queue = parallel.pool.DataQueue();
            afterEach(queue, @app.print);
            dataTable = app.getDataTable();
            app.print('Labeling avi files with cue and laser...')
            parfor k = 1:numel(dataTable.SessionVideoDirs)
                sessionVideoDir = dataTable.SessionVideoDirs{k};
                labelTrialsWithCueAndLaser(sessionVideoDir, sessionVideoDir, '.avi', dryrun, queue)
            end
            app.print('...done labeling avi files with cue and laser')            
        end

        % Button pushed function: BGetlicksegmentationandkinematicsButton
        function BGetlicksegmentationandkinematicsButtonPushed(app, event)
            saveFlag = true;
            dataTable = app.getDataTable();
            sessionDataRoots = dataTable.SessionMaskDirs;
            sessionVideoRoots = dataTable.SessionVideoDirs;
            app.print('Calculating lick kinematics, creating t_struct file...');
            % Gathering list of fiducial points
            fiducialPoints = {};
            for sessionNum = 1:length(sessionDataRoots)
                fiducialPoints{sessionNum} = app.getFiducialPoint(sessionNum);
            end
            % Create t_struct.mat file for each session
            make_t_struct(sessionDataRoots, sessionVideoRoots, saveFlag, [], fiducialPoints);
            app.print('     ...done calculating lick kinematics & creating t_struct file');
        end

        % Button pushed function: AConvertCINEstoAVIsButton
        function AConvertCINEstoAVIsButtonPushed(app, event)
            cines = [];
            dataTable = app.getDataTable();
            for k = 1:numel(dataTable.SessionVideoDirs)
                disp(dataTable.SessionVideoDirs{k});
                cines = [cines, findFilesByRegex(dataTable.SessionVideoDirs{k}, '.*\.cine')'];
            end
            queue = parallel.pool.DataQueue();
            afterEach(queue, @app.print);
            convertCinesToAVIs(cines, true, queue);
            app.updateVideoBrowser();
        end

        % Button pushed function: reloadVideoBrowser
        function reloadVideoBrowserButtonPushed(app, event)
            app.updateVideoBrowser();
        end

        % Button pushed function: CAlignFPGAandVideoTrialsButton
        function CAlignFPGAandVideoTrialsButtonPushed(app, event)
            dataTable = app.getDataTable();
            sessionMaskRoots = dataTable.SessionMaskDirs;
            sessionVideoRoots = dataTable.SessionVideoDirs;
            sessionFPGARoots = dataTable.SessionFPGADirs;
            [tdiffs_FPGA, tdiffs_Video, result] = get_tdiff_video(sessionVideoRoots, sessionFPGARoots);
            
            if ~islogical(result) || ~result
                app.print(result);
            end
            app.print('Initiating user alignment of FPGA and video trials...');
            startingTrialNums = app.alignTDiffs(sessionMaskRoots, tdiffs_FPGA, tdiffs_Video);
            if isempty(startingTrialNums)
                app.print('     ...user alignment of FPGA and video trials cancelled.');
                return;
            else
                app.print('     ...user alignment of FPGA and video trials complete.');
            end
            
            % Add 
            properties = {};
            values = {};
            dirs = {};
            for sessionNum = 1:numel(sessionMaskRoots)
                properties = [properties, 'FPGAStartTrial'];
                values = [values, startingTrialNums(sessionNum).FPGA];
                dirs = [dirs, sessionMaskRoots{sessionNum}];
                
                properties = [properties, 'VideoStartTrial'];
                values = [values, startingTrialNums(sessionNum).Video];
                dirs = [dirs, sessionMaskRoots{sessionNum}];
            end
            app.setDataTableElements(properties, values, dirs)
            
        end

        % Button pushed function: ACombineconvertFPGAdatfilesButton
        function ACombineconvertFPGAdatfilesButtonPushed(app, event)
            % Run ppscript for all FPGA data directories
            dataTable = app.getDataTable();
            sessionDataRoots = dataTable.SessionMaskDirs;
            sessionFPGARoots = dataTable.SessionFPGADirs;
            
            processingPipeline = app.FPGAdataformatDropDown.Value;
            
            app.print(['Combining/converting FPGA data for format: ', processingPipeline, '...']);
            for sessionNum = 1:numel(sessionFPGARoots)
                sessionFPGARoot = sessionFPGARoots{sessionNum};
                if ~isempty(sessionFPGARoot)
                    app.print(['Combining/converting FPGA data in ', sessionFPGARoot]);
                    
                    switch processingPipeline
                        case "Classic"
                            [~, result] = ppscript(sessionFPGARoot, '%f %s %s %s %s %s %s', 7);
                        case "2D Fakeout"
                            [~, result] = ppscript(sessionFPGARoot, '%f %f %f %s %s %s %s %s %s', 9);
                    end
                    
                    if ~islogical(result) || ~result
                        app.print(result);
                    end
                else
                    sessionDataRoot = sessionDataRoots{sessionNum};
                    app.print(['No FPGA root given for session', sessionDataRoot])
                end
            end
            app.print('...done combining/converting FPGA data');
        end

        % Button pushed function: BProcessFPGAdataButton
        function BProcessFPGAdataButtonPushed(app, event)
            app.print('Processing FPGA data...')
            dataTable = app.getDataTable();
            sessionDataRoots = dataTable.SessionMaskDirs;
            sessionFPGARoots = dataTable.SessionFPGADirs;
            plotOutput = app.PlotNplickOutputCheckBox.Value;

            processingPipeline = app.FPGAdataformatDropDown.Value;

            app.print(['Processing FPGA data using scripts for format: ', processingPipeline]);
            for sessionNum = 1:numel(sessionFPGARoots)
                sessionFPGARoot = sessionFPGARoots{sessionNum};
                if ~isempty(sessionFPGARoot)
                    app.print(['Processing FPGA data in ', sessionFPGARoot]);

                    switch processingPipeline
                        case "Classic"
                            [nl_struct,raster_struct,result] = nplick_struct(sessionFPGARoot, plotOutput);
                        case "2D Fakeout"
                            [nl_struct,raster_struct,result] = nplick_struct_2D(sessionFPGARoot);                            
                    end
                    
                    if ~islogical(result) || ~result
                        app.print(result);
                    end
                else
                    sessionDataRoot = sessionDataRoots{sessionNum};
                    app.print(['No FPGA root given for session', sessionDataRoot]);
                end
            end
            app.print('...done processing FPGA data');
        end

        % Button pushed function: ClearButton
        function ClearButtonPushed(app, event)
            app.Output.Value = '';
        end

        % Button pushed function: DIncorporateFPGAdataintotiptracksButton
        function DIncorporateFPGAdataintotiptracksButtonPushed(app, event)
            app.print('Incorporating FPGA data into tip tracks...')
            dataTable = app.getDataTable();
            sessionMaskRoots = dataTable.SessionMaskDirs;
            sessionVideoRoots = dataTable.SessionVideoDirs;
            sessionFPGARoots = dataTable.SessionFPGADirs;
            time_aligned_trials = [dataTable.VideoStartTrial, dataTable.FPGAStartTrial];

            processingPipeline = app.FPGAdataformatDropDown.Value;
            switch processingPipeline
                case 'Classic'
                    [vid_ind_arr, result] = align_videos_tolickdata(sessionVideoRoots,sessionMaskRoots,sessionFPGARoots,time_aligned_trials);
                case '2D Fakeout'
                    [vid_ind_arr, result] = align_videos_toFakeOutData_2D(sessionVideoRoots,sessionMaskRoots,sessionFPGARoots,time_aligned_trials);
            end
            
            if ~islogical(result) || ~result
                app.print(result)
            else
                app.print('...finished incorporating FPGA data into tip tracks.')
            end
        end

        % Value changed function: OverlayMasksCheckBox
        function OverlayMasksCheckBoxValueChanged(app, event)
            value = app.OverlayMasksCheckBox.Value;
            if value
                app.loadCurrentVideoMasks()
            end
            app.FrameSliderValueChanged()
        end

        % Button pushed function: HelpButton
        function HelpButtonPushed(app, event)
helpMsg = {...
'This GUI is designed to lead you through the steps of calculating the tongue-tip'
'tracks for a group of headfixed lick sessions.'
''
'You must have a directory with CINE or AVI video files and corresponding XML '
'metadata files, a directory with top and bottom view segmented tongue masks, and'
'a directory containing FPGA data. These may be the same or different'
'directories. The tongue masks must be named ''Top_N.mat'' and ''Bot_N.mat'' with'
'N being a zero-padded number such that alphabetizing the videos, top masks, and '
'bottom masks results in the videos and masks being put in corresponding order.'
''
'This GUI will allow you to execute several processing steps. You should do these'
'steps in the following order: '
''
'0. Set up directories'
'  A. Each session has Select the mask, video, and FPGA data directories using the '
'     ''Find directory'' button while selecting each column for the first session.'
'  B. Add another blank session row with the ''Add Session'' button'
'  C. Repeat for all other sessions you wish to process.'
'1. Video processing'
'  A. Convert CINEs to AVIs - this will loop through all video directories and '
'     convert any CINEs found to AVIs. Click "Dry run" first to check what will'
'     be done first before actually converting.'
'  B. Label videos with cue and laser - this will look for XML files'
'     corresponding to each AVI video in each of the video directories'
'  C. For each session, load a representative video. Navigate to a frame that'
'     shows the tongue well-extended, but not obscuring the spout. Click on the'
'     frame to give it focus. The hover over each of the four markers and press'
'     the 1, 2, 3, and 4 keys to mark each one. As you do so, the marker data'
'     will be incorporated into the session data table.'
'  D. Input ''Top_Y0'' into session data table for each session. When the masks'
'     were generated, some part of the top of the video is often cropped to save'
'     processing time. This results in a top mask that is shifted down from the'
'     top of the video. In the Top_Y0 column, enter the number of pixels that was'
'     cropped from the top of the video. Leave as 0 if there was no top cropping. '
'2. Mask processing'
'  A. Click "Track tongue tips" to process all the masks and generate tongue tip'
'     tracks. The tip tracks will be stored in a file called ''tip_track.mat'' in'
'     each of the session mask directories. This takes a long time, but will be'
'     faster if run on a machine with more CPU cores, as it is parallelized. '
'  B. Get lick segmentation and kinematics - reorganize trajectory data by lick'
'     and calculate and add more kinematic measurements. The resulting data will'
'     be stored in a file called ''t_stats.mat'' in each of the session mask'
'     directories.'
'  C and D. These steps can''t be done until the FPGA data is processed'
'3.  FPGA processing'
'  A. Combine/convert FPGA dat files - run ''ppscript'' to combine and convert the'
'     raw .dat files that LabVIEW generates into .mat files.'
'  B. Process FPGA data - run ''nplick_struct.m'' to perform basic analysis on data'
'     to identify behavioral events'
'2/3 C. Align FPGA and Video trials - since the video recording and FPGA data'
'       recording may not have started at the same time, those two data sets must'
'       be time-aligned with each other before they are combined. For each'
'       session, the intervals between FPGA and video trials will be displayed as'
'       as rectangles. For each session, click on the earliest (leftmost)'
'       rectangle that results in the FPGA and video trial intervals aligning.'
'       when done, click "Accept", and the alignment data will be incorporated'
'       into the session data table.'
'    D. Incorporate FPGA data into tip tracks - incorporate spout contact data'
'       into each t_stats.mat file in the masks directory for each session.'
''
'Developed by Brian Kardon based on data processing scripts written by Teja '
'Bollu, 2020'};
            helpTitle = 'Help';
            f = uifigure('Name', helpTitle);
            h = uitextarea(f, 'Value', helpMsg, 'Position', [10, 10, 600, 400]);
        end

        % Button pushed function: ActivateallButton
        function ActivateallButtonPushed(app, event)
            dataTable = app.getDataTable(true);
            dataTable.Active = dataTable.Active | true;
            app.updateDataTable(dataTable);
        end

        % Button pushed function: DeactivateallButton
        function DeactivateallButtonPushed(app, event)
            dataTable = app.getDataTable(true);
            dataTable.Active = dataTable.Active & false;
            app.updateDataTable(dataTable);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [100 100 1347 749];
            app.UIFigure.Name = 'Tongue Tip Tracker';
            app.UIFigure.Resize = 'off';
            app.UIFigure.KeyPressFcn = createCallbackFcn(app, @UIFigureKeyPress, true);

            % Create ImageAxes
            app.ImageAxes = uiaxes(app.UIFigure);
            app.ImageAxes.XTick = [];
            app.ImageAxes.XTickLabelRotation = 0;
            app.ImageAxes.XTickLabel = {'[ ]'};
            app.ImageAxes.YTick = [];
            app.ImageAxes.YTickLabelRotation = 0;
            app.ImageAxes.ZTickLabelRotation = 0;
            app.ImageAxes.BoxStyle = 'full';
            app.ImageAxes.LineWidth = 1;
            app.ImageAxes.Box = 'on';
            app.ImageAxes.Position = [15 106 223 581];

            % Create SessionDataTable
            app.SessionDataTable = uitable(app.UIFigure);
            app.SessionDataTable.ColumnName = {''};
            app.SessionDataTable.RowName = {};
            app.SessionDataTable.ColumnSortable = true;
            app.SessionDataTable.ColumnEditable = true;
            app.SessionDataTable.CellEditCallback = createCallbackFcn(app, @SessionDataTableCellEdit, true);
            app.SessionDataTable.CellSelectionCallback = createCallbackFcn(app, @SessionDataTableCellSelection, true);
            app.SessionDataTable.Tooltip = {'Session directories and metrics for each session necessary for processing tongue tips. Video directory is optional - leave blank if AVIs are also in the data folder.'};
            app.SessionDataTable.FontSize = 14;
            app.SessionDataTable.Position = [245 18 1087 194];

            % Create FrameLabel
            app.FrameLabel = uilabel(app.UIFigure);
            app.FrameLabel.HorizontalAlignment = 'right';
            app.FrameLabel.Position = [15 18 50 22];
            app.FrameLabel.Text = 'Frame #';

            % Create FrameSlider
            app.FrameSlider = uislider(app.UIFigure);
            app.FrameSlider.ValueChangedFcn = createCallbackFcn(app, @FrameSliderValueChanged, true);
            app.FrameSlider.ValueChangingFcn = createCallbackFcn(app, @FrameSliderValueChanging, true);
            app.FrameSlider.Position = [23 64 203 3];

            % Create AddSessionButton
            app.AddSessionButton = uibutton(app.UIFigure, 'push');
            app.AddSessionButton.ButtonPushedFcn = createCallbackFcn(app, @AddSessionButtonPushed, true);
            app.AddSessionButton.Position = [591 217 73 36];
            app.AddSessionButton.Text = {'Add'; 'Session'};

            % Create VideoBrowser
            app.VideoBrowser = uitree(app.UIFigure);
            app.VideoBrowser.SelectionChangedFcn = createCallbackFcn(app, @VideoBrowserSelectionChanged, true);
            app.VideoBrowser.Tooltip = {'Videos available for each session'};
            app.VideoBrowser.Position = [245 347 220 334];

            % Create VideoBrowserLabel
            app.VideoBrowserLabel = uilabel(app.UIFigure);
            app.VideoBrowserLabel.Position = [245 684 82 22];
            app.VideoBrowserLabel.Text = 'Video browser';

            % Create LoadVideoButton
            app.LoadVideoButton = uibutton(app.UIFigure, 'push');
            app.LoadVideoButton.ButtonPushedFcn = createCallbackFcn(app, @LoadVideoButtonPushed, true);
            app.LoadVideoButton.Enable = 'off';
            app.LoadVideoButton.Position = [247 284 108 54];
            app.LoadVideoButton.Text = 'Load Video';

            % Create FindDirectoryButton
            app.FindDirectoryButton = uibutton(app.UIFigure, 'push');
            app.FindDirectoryButton.ButtonPushedFcn = createCallbackFcn(app, @FindDirectoryButtonPushed, true);
            app.FindDirectoryButton.Position = [402 217 77 36];
            app.FindDirectoryButton.Text = {'Find'; 'Directory'};

            % Create ShowCrosshairCheckBox
            app.ShowCrosshairCheckBox = uicheckbox(app.UIFigure);
            app.ShowCrosshairCheckBox.Text = 'Show crosshair';
            app.ShowCrosshairCheckBox.Position = [363 300 104 22];
            app.ShowCrosshairCheckBox.Value = true;

            % Create MarkerInstructionLabel
            app.MarkerInstructionLabel = uilabel(app.UIFigure);
            app.MarkerInstructionLabel.FontWeight = 'bold';
            app.MarkerInstructionLabel.Position = [477 502 185 22];
            app.MarkerInstructionLabel.Text = 'C. Set measurement markers';

            % Create ShowMarkersCheckBox
            app.ShowMarkersCheckBox = uicheckbox(app.UIFigure);
            app.ShowMarkersCheckBox.ValueChangedFcn = createCallbackFcn(app, @ShowMarkersCheckBoxValueChanged, true);
            app.ShowMarkersCheckBox.Text = 'Show markers';
            app.ShowMarkersCheckBox.Position = [363 321 104 22];
            app.ShowMarkersCheckBox.Value = true;

            % Create CurrentVideoLabel
            app.CurrentVideoLabel = uilabel(app.UIFigure);
            app.CurrentVideoLabel.Position = [23 684 215 37];
            app.CurrentVideoLabel.Text = {'Current video: '; 'None'};

            % Create OutputLabel_2
            app.OutputLabel_2 = uilabel(app.UIFigure);
            app.OutputLabel_2.HorizontalAlignment = 'right';
            app.OutputLabel_2.Position = [946 678 42 22];
            app.OutputLabel_2.Text = 'Output';

            % Create Output
            app.Output = uitextarea(app.UIFigure);
            app.Output.Editable = 'off';
            app.Output.FontSize = 10;
            app.Output.Tooltip = {'Notifications'; ' progress'; ' and warnings'};
            app.Output.Position = [946 220 386 459];

            % Create TongueTipTrackerLabel
            app.TongueTipTrackerLabel = uilabel(app.UIFigure);
            app.TongueTipTrackerLabel.FontSize = 24;
            app.TongueTipTrackerLabel.FontWeight = 'bold';
            app.TongueTipTrackerLabel.Position = [518 716 226 29];
            app.TongueTipTrackerLabel.Text = 'Tongue Tip Tracker';

            % Create AConvertCINEstoAVIsButton
            app.AConvertCINEstoAVIsButton = uibutton(app.UIFigure, 'push');
            app.AConvertCINEstoAVIsButton.ButtonPushedFcn = createCallbackFcn(app, @AConvertCINEstoAVIsButtonPushed, true);
            app.AConvertCINEstoAVIsButton.Tooltip = {'Convert all CINEs in the chosen session video directories to AVIs.'};
            app.AConvertCINEstoAVIsButton.Position = [478 579 184 39];
            app.AConvertCINEstoAVIsButton.Text = {'A. Convert '; 'CINEs to AVIs'};

            % Create ParallelPoolStateLabel
            app.ParallelPoolStateLabel = uilabel(app.UIFigure);
            app.ParallelPoolStateLabel.Position = [477 264 103 35];
            app.ParallelPoolStateLabel.Text = {'Parallel pool:'; 'None'};

            % Create StartParallelPoolButton
            app.StartParallelPoolButton = uibutton(app.UIFigure, 'push');
            app.StartParallelPoolButton.ButtonPushedFcn = createCallbackFcn(app, @StartParallelPoolButtonPushed, true);
            app.StartParallelPoolButton.Tooltip = {'Starting a parallel pool takes a while. Click here to get a head start by preparing the pool beforehand.'};
            app.StartParallelPoolButton.Position = [477 302 103 33];
            app.StartParallelPoolButton.Text = 'Start parallel pool';

            % Create TiptrackprocessingLabel
            app.TiptrackprocessingLabel = uilabel(app.UIFigure);
            app.TiptrackprocessingLabel.Position = [673 596 137 22];
            app.TiptrackprocessingLabel.Text = 'Tip track processing';

            % Create VerboseCheckBox
            app.VerboseCheckBox = uicheckbox(app.UIFigure);
            app.VerboseCheckBox.Text = 'Verbose processing';
            app.VerboseCheckBox.Position = [671 575 137 22];
            app.VerboseCheckBox.Value = true;

            % Create MakeMoviesCheckBox
            app.MakeMoviesCheckBox = uicheckbox(app.UIFigure);
            app.MakeMoviesCheckBox.Text = 'Make movies';
            app.MakeMoviesCheckBox.Position = [671 491 137 22];

            % Create PlotKinematicsCheckBox
            app.PlotKinematicsCheckBox = uicheckbox(app.UIFigure);
            app.PlotKinematicsCheckBox.Text = 'Plot kinematics';
            app.PlotKinematicsCheckBox.Position = [671 533 137 22];

            % Create SaveTrackingDataCheckBox
            app.SaveTrackingDataCheckBox = uicheckbox(app.UIFigure);
            app.SaveTrackingDataCheckBox.Text = 'Save tracking data';
            app.SaveTrackingDataCheckBox.Position = [671 554 137 22];
            app.SaveTrackingDataCheckBox.Value = true;

            % Create SaveKinematicsPlotsCheckBox
            app.SaveKinematicsPlotsCheckBox = uicheckbox(app.UIFigure);
            app.SaveKinematicsPlotsCheckBox.Text = 'Save kinematics plots';
            app.SaveKinematicsPlotsCheckBox.Position = [671 512 137 22];

            % Create TrackTongueTipsButton
            app.TrackTongueTipsButton = uibutton(app.UIFigure, 'push');
            app.TrackTongueTipsButton.ButtonPushedFcn = createCallbackFcn(app, @TrackTongueTipsButtonPushed, true);
            app.TrackTongueTipsButton.Position = [671 444 130 42];
            app.TrackTongueTipsButton.Text = 'A. Track tongue tips';

            % Create SaveDataTableButton
            app.SaveDataTableButton = uibutton(app.UIFigure, 'push');
            app.SaveDataTableButton.ButtonPushedFcn = createCallbackFcn(app, @SaveDataTableButtonPushed, true);
            app.SaveDataTableButton.Tooltip = {'Save directories and marker locations for later use.'};
            app.SaveDataTableButton.Position = [698 217 73 36];
            app.SaveDataTableButton.Text = {'Save data'; 'table'};

            % Create LoadDataTableButton
            app.LoadDataTableButton = uibutton(app.UIFigure, 'push');
            app.LoadDataTableButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataTableButtonPushed, true);
            app.LoadDataTableButton.Tooltip = {'Load a previously created data table from a file.'};
            app.LoadDataTableButton.Position = [784 217 73 36];
            app.LoadDataTableButton.Text = {'Load data'; 'table'};

            % Create CleardatatableButton
            app.CleardatatableButton = uibutton(app.UIFigure, 'push');
            app.CleardatatableButton.ButtonPushedFcn = createCallbackFcn(app, @CleardatatableButtonPushed, true);
            app.CleardatatableButton.Tooltip = {'Delete all values in data table!'};
            app.CleardatatableButton.Position = [870 217 73 36];
            app.CleardatatableButton.Text = {'Clear data'; 'table'};

            % Create TopFiducialLabel
            app.TopFiducialLabel = uilabel(app.UIFigure);
            app.TopFiducialLabel.Position = [478 402 186 22];
            app.TopFiducialLabel.Text = '2 = Top fiducial (y coord.)';

            % Create BotFiducialLabel
            app.BotFiducialLabel = uilabel(app.UIFigure);
            app.BotFiducialLabel.Position = [478 421 186 22];
            app.BotFiducialLabel.Text = '1 = Bot. fiducial (x and y coord.)';

            % Create TopSpoutXLabel
            app.TopSpoutXLabel = uilabel(app.UIFigure);
            app.TopSpoutXLabel.Position = [478 382 186 22];
            app.TopSpoutXLabel.Text = '3 = Top spout reference (x coord.)';

            % Create BotSpoutXLabel
            app.BotSpoutXLabel = uilabel(app.UIFigure);
            app.BotSpoutXLabel.Position = [478 362 186 22];
            app.BotSpoutXLabel.Text = '4 = Bot..spout reference (x coord.)';

            % Create OpenselecteddirectoryButton
            app.OpenselecteddirectoryButton = uibutton(app.UIFigure, 'push');
            app.OpenselecteddirectoryButton.ButtonPushedFcn = createCallbackFcn(app, @OpenselecteddirectoryButtonPushed, true);
            app.OpenselecteddirectoryButton.Position = [486 217 94 36];
            app.OpenselecteddirectoryButton.Text = {'Open selected'; 'directory'};

            % Create BGetlicksegmentationandkinematicsButton
            app.BGetlicksegmentationandkinematicsButton = uibutton(app.UIFigure, 'push');
            app.BGetlicksegmentationandkinematicsButton.ButtonPushedFcn = createCallbackFcn(app, @BGetlicksegmentationandkinematicsButtonPushed, true);
            app.BGetlicksegmentationandkinematicsButton.Position = [671 395 130 42];
            app.BGetlicksegmentationandkinematicsButton.Text = {'B. Get lick segmentation'; 'and kinematics'};

            % Create BLabelvideoswcuelaserButton
            app.BLabelvideoswcuelaserButton = uibutton(app.UIFigure, 'push');
            app.BLabelvideoswcuelaserButton.ButtonPushedFcn = createCallbackFcn(app, @BLabelvideoswcuelaserButtonPushed, true);
            app.BLabelvideoswcuelaserButton.Tooltip = {'Label all .avi videos found in all SessionVideoDirs'; ' and label them with the cue frame and whether or not an "event" (laser) was marked. Requires that xml metadata files with corresponding names are present for each avi.'};
            app.BLabelvideoswcuelaserButton.Position = [478 533 101 39];
            app.BLabelvideoswcuelaserButton.Text = {'B. Label videos '; 'w/ cue & laser'};

            % Create DryrunlabelingCheckBox
            app.DryrunlabelingCheckBox = uicheckbox(app.UIFigure);
            app.DryrunlabelingCheckBox.Text = {'Dry run'; 'labeling'};
            app.DryrunlabelingCheckBox.Position = [588 533 74 39];

            % Create reloadVideoBrowser
            app.reloadVideoBrowser = uibutton(app.UIFigure, 'push');
            app.reloadVideoBrowser.ButtonPushedFcn = createCallbackFcn(app, @reloadVideoBrowserButtonPushed, true);
            app.reloadVideoBrowser.Icon = 'Refresh_icon.png';
            app.reloadVideoBrowser.IconAlignment = 'center';
            app.reloadVideoBrowser.Position = [337 684 25 23];
            app.reloadVideoBrowser.Text = '';

            % Create CAlignFPGAandVideoTrialsButton
            app.CAlignFPGAandVideoTrialsButton = uibutton(app.UIFigure, 'push');
            app.CAlignFPGAandVideoTrialsButton.ButtonPushedFcn = createCallbackFcn(app, @CAlignFPGAandVideoTrialsButtonPushed, true);
            app.CAlignFPGAandVideoTrialsButton.Position = [669 364 268 22];
            app.CAlignFPGAandVideoTrialsButton.Text = 'C. Align FPGA and Video Trials';

            % Create ACombineconvertFPGAdatfilesButton
            app.ACombineconvertFPGAdatfilesButton = uibutton(app.UIFigure, 'push');
            app.ACombineconvertFPGAdatfilesButton.ButtonPushedFcn = createCallbackFcn(app, @ACombineconvertFPGAdatfilesButtonPushed, true);
            app.ACombineconvertFPGAdatfilesButton.Tooltip = {'Runs ppscript on all FPGA data directories specified'};
            app.ACombineconvertFPGAdatfilesButton.Position = [809 444 130 42];
            app.ACombineconvertFPGAdatfilesButton.Text = {'A. Combine/convert '; 'FPGA dat files'};

            % Create BProcessFPGAdataButton
            app.BProcessFPGAdataButton = uibutton(app.UIFigure, 'push');
            app.BProcessFPGAdataButton.ButtonPushedFcn = createCallbackFcn(app, @BProcessFPGAdataButtonPushed, true);
            app.BProcessFPGAdataButton.Tooltip = {'Runs nplick_struct on all FPGA data directories specified. Must combine/convert dat files first.'};
            app.BProcessFPGAdataButton.Position = [809 395 77 42];
            app.BProcessFPGAdataButton.Text = {'B. Process '; 'FPGA data'};

            % Create PlotNplickOutputCheckBox
            app.PlotNplickOutputCheckBox = uicheckbox(app.UIFigure);
            app.PlotNplickOutputCheckBox.Text = {'Plot'; 'output'};
            app.PlotNplickOutputCheckBox.Position = [890 395 55 41];

            % Create ClearButton
            app.ClearButton = uibutton(app.UIFigure, 'push');
            app.ClearButton.ButtonPushedFcn = createCallbackFcn(app, @ClearButtonPushed, true);
            app.ClearButton.Position = [1008 680 41 22];
            app.ClearButton.Text = 'Clear';

            % Create DIncorporateFPGAdataintotiptracksButton
            app.DIncorporateFPGAdataintotiptracksButton = uibutton(app.UIFigure, 'push');
            app.DIncorporateFPGAdataintotiptracksButton.ButtonPushedFcn = createCallbackFcn(app, @DIncorporateFPGAdataintotiptracksButtonPushed, true);
            app.DIncorporateFPGAdataintotiptracksButton.Position = [669 334 268 22];
            app.DIncorporateFPGAdataintotiptracksButton.Text = 'D. Incorporate FPGA data into tip tracks';

            % Create OverlayMasksCheckBox
            app.OverlayMasksCheckBox = uicheckbox(app.UIFigure);
            app.OverlayMasksCheckBox.ValueChangedFcn = createCallbackFcn(app, @OverlayMasksCheckBoxValueChanged, true);
            app.OverlayMasksCheckBox.Text = 'Overlay Masks';
            app.OverlayMasksCheckBox.Position = [363 277 104 22];
            app.OverlayMasksCheckBox.Value = true;

            % Create VideoprocessingLabel
            app.VideoprocessingLabel = uilabel(app.UIFigure);
            app.VideoprocessingLabel.HorizontalAlignment = 'center';
            app.VideoprocessingLabel.FontSize = 16;
            app.VideoprocessingLabel.FontWeight = 'bold';
            app.VideoprocessingLabel.Position = [478 639 184 40];
            app.VideoprocessingLabel.Text = {'1. Video '; 'processing'};

            % Create MaskprocessingLabel
            app.MaskprocessingLabel = uilabel(app.UIFigure);
            app.MaskprocessingLabel.HorizontalAlignment = 'center';
            app.MaskprocessingLabel.FontSize = 16;
            app.MaskprocessingLabel.FontWeight = 'bold';
            app.MaskprocessingLabel.Position = [668.5 639 132 40];
            app.MaskprocessingLabel.Text = {'2. Mask '; 'processing'};

            % Create FPGAdataprocessingLabel
            app.FPGAdataprocessingLabel = uilabel(app.UIFigure);
            app.FPGAdataprocessingLabel.HorizontalAlignment = 'center';
            app.FPGAdataprocessingLabel.FontSize = 16;
            app.FPGAdataprocessingLabel.FontWeight = 'bold';
            app.FPGAdataprocessingLabel.Position = [809 639 130 40];
            app.FPGAdataprocessingLabel.Text = {'3. FPGA data '; 'processing'};

            % Create HoverovertheimageandpressLabel
            app.HoverovertheimageandpressLabel = uilabel(app.UIFigure);
            app.HoverovertheimageandpressLabel.Position = [478 444 184 59];
            app.HoverovertheimageandpressLabel.Text = {'Load a representative video from '; 'the session. Pick a frame with the'; 'tongue extended and click on it.'; 'Hover over each point and press:'};

            % Create cursorPositionLabel
            app.cursorPositionLabel = uilabel(app.UIFigure);
            app.cursorPositionLabel.Position = [165 85 61 22];
            app.cursorPositionLabel.Text = '';

            % Create HelpButton
            app.HelpButton = uibutton(app.UIFigure, 'push');
            app.HelpButton.ButtonPushedFcn = createCallbackFcn(app, @HelpButtonPushed, true);
            app.HelpButton.Position = [1232 720 100 22];
            app.HelpButton.Text = 'Help';

            % Create SetupsessiondirectoriesLabel
            app.SetupsessiondirectoriesLabel = uilabel(app.UIFigure);
            app.SetupsessiondirectoriesLabel.HorizontalAlignment = 'center';
            app.SetupsessiondirectoriesLabel.FontSize = 16;
            app.SetupsessiondirectoriesLabel.FontWeight = 'bold';
            app.SetupsessiondirectoriesLabel.Position = [245 256 225 22];
            app.SetupsessiondirectoriesLabel.Text = '0. Set up session directories';

            % Create ActivateallButton
            app.ActivateallButton = uibutton(app.UIFigure, 'push');
            app.ActivateallButton.ButtonPushedFcn = createCallbackFcn(app, @ActivateallButtonPushed, true);
            app.ActivateallButton.Position = [245 217 64 36];
            app.ActivateallButton.Text = {'Activate'; 'all'};

            % Create DeactivateallButton
            app.DeactivateallButton = uibutton(app.UIFigure, 'push');
            app.DeactivateallButton.ButtonPushedFcn = createCallbackFcn(app, @DeactivateallButtonPushed, true);
            app.DeactivateallButton.Position = [318 217 76 36];
            app.DeactivateallButton.Text = {'Deactivate'; 'all'};

            % Create FPGAdataformatDropDownLabel
            app.FPGAdataformatDropDownLabel = uilabel(app.UIFigure);
            app.FPGAdataformatDropDownLabel.HorizontalAlignment = 'right';
            app.FPGAdataformatDropDownLabel.Position = [811 617 102 22];
            app.FPGAdataformatDropDownLabel.Text = 'FPGA data format';

            % Create FPGAdataformatDropDown
            app.FPGAdataformatDropDown = uidropdown(app.UIFigure);
            app.FPGAdataformatDropDown.Items = {'Classic', '2D Fakeout'};
            app.FPGAdataformatDropDown.Position = [811 596 100 22];
            app.FPGAdataformatDropDown.Value = 'Classic';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = tongueTipTrackerApp_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end