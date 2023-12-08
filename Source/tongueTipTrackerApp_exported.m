classdef tongueTipTrackerApp_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        AutorevertoldhealsCheckBox      matlab.ui.control.CheckBox
        C2OcclusioneditorButton         matlab.ui.control.Button
        CHealSpoutOcclusionsButton      matlab.ui.control.Button
        RelabelCheckBox                 matlab.ui.control.CheckBox
        DeleteSessionButton             matlab.ui.control.Button
        AddDataTableButton              matlab.ui.control.Button
        SpoutWidthLabel                 matlab.ui.control.Label
        MeasuringRulerCheckBox          matlab.ui.control.CheckBox
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
        GIncorporateFPGAdataintotiptracksButton  matlab.ui.control.Button
        ClearButton                     matlab.ui.control.Button
        PlotNplickOutputCheckBox        matlab.ui.control.CheckBox
        BProcessFPGAdataButton          matlab.ui.control.Button
        ACombineconvertFPGAdatfilesButton  matlab.ui.control.Button
        FAlignFPGAandVideoTrialsButton  matlab.ui.control.Button
        reloadVideoBrowser              matlab.ui.control.Button
        DryrunCheckBox                  matlab.ui.control.CheckBox
        BLabelvideoswcuelaserButton     matlab.ui.control.Button
        EGetlicksegmentationandkinematicsButton  matlab.ui.control.Button
        OpenselecteddirectoryButton     matlab.ui.control.Button
        BotSpoutLabel                   matlab.ui.control.Label
        TopSpoutLabel                   matlab.ui.control.Label
        BotFiducialLabel                matlab.ui.control.Label
        TopFiducialLabel                matlab.ui.control.Label
        CleartableButton                matlab.ui.control.Button
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
        sessionDataTableSelection   uint16
        currentVideo                struct
        currentFrame                matlab.graphics.primitive.Image
        crosshair                   matlab.graphics.primitive.Line
        currentDataTable            table
        imageMarkers                struct
        maxOutputLength             uint16
        markerColors                struct
        dataTableAutoSaveName       char
        measuringRuler              images.roi.Line
        maxSpoutPoints           uint16
    end

    methods (Access = private)

        function updateFrame(app, frameNum)
            if isempty(app.currentVideo.Data)
                % No video loaded
                return;
            end
            frame = app.currentVideo.Data(:, :, frameNum);
            app.FrameLabel.Text = ['#', num2str(frameNum)];
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
            
        function addVideoBrowserSession(app, sessionMaskDir, sessionVideoDir, lazy)
            % Add a node representing a session in the video browser
            %   sessionMaskDir - session mask directory
            %   sessionVideoDir - session video directory
            %   lazy - do not populate the video directory with video nodes
            %       yet - wait for it to be expanded.
            if ~exist('lazy', 'var') || isempty(lazy)
                lazy = false;
            end
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
%                 app.videoBrowserSessionNodes = [app.videoBrowserSessionNodes, newSessionNode];
                if lazy
                    % Just add a placeholder - don't bother adding the
                    % video nodes yet. We can add the actual nodes when/if
                    % the user actually expands the session.
                    uitreenode(newSessionNode, 'Text', 'Loading...please wait...', 'NodeData', 'unloaded');
                else
                    % Actually populate the whole node with video nodes.
                    app.populateVideoSessionNode(newSessionNode);
                end
            end
        end
        
        function populateVideoSessionNode(app, sessionNode)
            videoDir = sessionNode.NodeData;
            videos = findSessionVideos(videoDir, 'avi', @parsePCCFilenameTimestamp);
            for j = 1:numel(videos)
                [~, videoName, videoExt] = fileparts(videos{j});
                videoFileName = [videoName, videoExt];
                uitreenode(sessionNode, 'Text', videoFileName, 'Tag', 'video', 'NodeData', struct());
            end
        end
        
        function getVideoBrowserSession(app, sessionMaskDir)
            sessionMaskDirs = cellfun(@(ud)ud.sessionMaskDir, {app.VideoBrowser.Children.UserData}, 'UniformOutput', true);
            app.VideoBrowser.Children(strcmp(sessionMaskDir, sessionMaskDirs));
        end
        
        function deleteVideoBrowserSession(app, sessionMaskDir)
            delete(app.getVideoBrowserSession(sessionMaskDir));
        end

        function videoNode = getVideoNode(app, sessionMaskDir, sessionVideoDir, videoName)
            % Find a video node in the video tree by session dirs and filename
            % Loop over video session nodes:
            for s = 1:numel(app.VideoBrowser.Children)
                sessionNode = app.VideoBrowser.Children(s);
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
        
        function sessionDirs = getVideoBrowserSessionDirs(app)
            if isempty(app.VideoBrowser.Children)
                sessionDirs = {};
            else
                dirStructs = [app.VideoBrowser.Children.UserData];
                sessionDirs = {dirStructs.sessionMaskDir};
            end
        end
        
        function updateVideoBrowser(app, forceUpdate, lazy)
        %   Update video browser tree with current sessions. Attempts to do
        %       this parsimoniously, only updating nodes that need updating,
        %       to cut down on the ridiculous UI computation time.
        %           forceUpdate - if true, deletes *all* nodes. Default:
        %               false
        %           lazy - if true, do not actually load videos, just add a
        %               placeholder node, and load them when/if the user
        %               expands the session node. Default: true
            app.print('Updating video browser');
            if ~exist('forceUpdate', 'var') || isempty(forceUpdate)
                forceUpdate = false;
            end
            if ~exist('lazy', 'var') || isempty(lazy)
                lazy = true;
            end
            dataTable = app.getDataTable();

            % Update all session mask dirs to match UI table, and videos to
            %   match directory contents.
            if forceUpdate
                % We're doing a full refresh - delete all video session
                % nodes first, then we'll recreate the current set.
                delete(app.VideoBrowser.Children);
%                 app.videoBrowserSessionNodes = matlab.ui.container.TreeNode.empty;
            end
            % Check for video nodes that need to be deleted (or changed)
            videoBrowserNodes = app.VideoBrowser.Children;
            for k = 1:numel(videoBrowserNodes)
                videoBrowserNode = videoBrowserNodes(k);
                sessionMatchIndex = find(strcmp(videoBrowserNode.UserData.sessionMaskDir, dataTable.SessionMaskDirs));
                if isempty(sessionMatchIndex)
                    % This video browser session is not in data table -
                    % delete it
                    delete(videoBrowserNode);
                elseif ~strcmp(videoBrowserNode.UserData.sessionVideoDir, dataTable.SessionVideoDirs{sessionMatchIndex})
                    % Video directory doesn't match - delete it so it
                    % can be recreated.
                    delete(videoBrowserNode);
                end
            end
            % Check for video nodes that need to be added
            videoBrowserSessionDirs = app.getVideoBrowserSessionDirs();
            for k = 1:numel(dataTable.SessionMaskDirs)
                sessionMaskDir = dataTable.SessionMaskDirs{k};
                if ~any(strcmp(sessionMaskDir, videoBrowserSessionDirs))
                    % This session is missing from the browser - add it
                    sessionVideoDir = dataTable.SessionVideoDirs{k};
                    app.addVideoBrowserSession(sessionMaskDir, sessionVideoDir, lazy);
                end
            end
            % Get updated list of sessions in video browser
            videoBrowserSessionDirs = app.getVideoBrowserSessionDirs();
            % Reorder video nodes to match table
            order = getReordering(videoBrowserSessionDirs, dataTable.SessionMaskDirs);
            orderTreeNodes(app.VideoBrowser, order);
            
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
                    app.crosshair(1) = line(app.ImageAxes, [minX, maxX], [curY, curY], 'LineStyle', '--', 'Color', [1, 0, 0, 0.7], 'LineWidth', 1, 'HitTest', 'off');
                    app.crosshair(2) = line(app.ImageAxes, [curX, curX], [minY, maxY], 'LineStyle', '--', 'Color', [1, 0, 0, 0.7], 'LineWidth', 1, 'HitTest', 'off');
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
%             profile on
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


                diffs = tdiff(oldDataTable, newDataTable);
                if isfield(diffs, 'SessionVideoDirs') || isfield(diffs, 'SessionMaskDirs')
                    % One or more of the video directories has been changed.
                    % Update video browser
                    app.updateVideoBrowser();
                end

%                 if ~isempty(oldDataTable) && ~isempty(newDataTable)
%                     diffs = tdiff(oldDataTable, newDataTable);
%                     if isfield(diffs, 'SessionVideoDirs') || isfield(diffs, 'SessionMaskDirs')
%                         % One or more of the video directories has been changed.
%                         % Update video browser
%                         app.updateVideoBrowser();
%                     end
%                 else
%                     app.updateVideoBrowser();
%                 end

                % Update image markers
                app.updateMarkers()
%                 drawnow;
            else
                app.print(['Invalid data:', reasons])
                warndlg(reasons, 'Invalid data');
            end
            if autosave
                app.saveDataTable(app.dataTableAutoSaveName);
            end
            app.SessionDataTable.ColumnEditable = true;
%             profile viewer
%             profile off
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
        
        function [valid, reasons, fixed, newDataTable] = validateDataTable(app, newDataTable, attemptFix, offerPathSwap)
            if ~exist('attemptFix', 'var') || isempty(attemptFix)
                attemptFix = false;
            end
            if ~exist('offerPathSwap', 'var') || isempty(offerPathSwap)
                offerPathSwap = false;
            end
            valid = true;
            fixed = false;
            reasons = {};

            % Any extra variables?
            newTableFields = newDataTable.Properties.VariableNames;
            for k = 1:length(newTableFields)
                newField = newTableFields{k};
                if ~any(strcmp(newField, app.newSessionRow.Properties.VariableNames))
                    % We've got an extraneous field.
                    valid = false;
                    fixed = false;
                    reasons = [reasons, sprintf('Unknown field name %s', newField)];
                    if attemptFix
                        newDataTable.(newField) = [];
                        fixed = true;
                    end
                end
            end
                
            n = numel(newDataTable.SessionMaskDirs);
            m = numel(unique(newDataTable.SessionMaskDirs));
            if (n ~= m)
                valid = false;
                fixed = false;
                reasons = [reasons, 'Duplicate session mask dirs'];
                if attemptFix
                    % Remove duplicates
                    rowsToRemove = [];
                    uniqueSessionMaskDirs = unique(newDataTable.SessionMaskDirs);
                    for k = 1:length(uniqueSessionMaskDirs)
                        uniqueSessionMaskDir = uniqueSessionMaskDirs{k};
                        row = getDataTableRow(app, uniqueSessionMaskDir, newDataTable);
                        % If there's more than one row match, we're going
                        % to delete all but the first.
                        rowsToRemove = [rowsToRemove, row(2:end)];
                    end
                    newDataTable(rowsToRemove, :) = [];
                    n = numel(newDataTable.SessionMaskDirs);
                    m = numel(unique(newDataTable.SessionMaskDirs));
                    if (n == m)
                        fixed = true;
                    end
                end
            end
            if ~all(newDataTable.Top_Y0 >= 0)
                % Top Y0 can't be negative
                valid = false;
                fixed = false;
                reasons = [reasons, 'Top box Y0 must be greater than or equal to zero'];
                if attemptFix
                    newDataTable.Top_Y0(newDataTable.Top_Y0 < 0) = 0;
                    if all(newDataTable.Top_Y0 >= 0)
                        fixed = true;
                    end
                end
            end
            spoutCoordFields = {'Bot_Spout_X', 'Bot_Spout_Y', 'Top_Spout_X', 'Top_Spout_Y'};
            for j = 1:length(spoutCoordFields)
                spoutCoordField = spoutCoordFields{j};
                % Loop over spout coordinate fields (they should all be
                % validated the same way)
                if any(strcmp(spoutCoordField, newDataTable.Properties.VariableNames))
                    % Spout coord field is a numeric array - this is a
                    % legacy format. Convert to comma separated string.
                    if isnumeric(newDataTable.(spoutCoordField))
                        valid = false;
                        fixed = false;
                        if attemptFix
                            newDataTable.(spoutCoordField) = arrayfun(@num2str, newDataTable.(spoutCoordField), 'UniformOutput', false);
                            fixed = true;
                        end
                    end
                else
                    % Spout coordinate field missing
                    valid = false;
                    fixed = false;
                    reasons = [reasons, sprintf('Spout coordinate field %s missing', spoutCoordField)];
                    if attemptFix
                        newDataTable.(spoutCoordField) = repmat({''}, [height(newDataTable), 1]);
                        fixed = true;
                    end
                end
                for k = 1:height(newDataTable)
                    try
                        % Check that spout coordinates are valid
                        coords = app.commaUnSeparateNums(newDataTable.(spoutCoordField){k});
                    catch ME
                        valid = false;
                        fixed = false;
                        reasons = [reasons, 'Spout coordinates contain an invalid list of coordinates. Coordinates should be a comma separated list of numbers.'];
                        if attemptFix
                            newDataTable.(spoutCoordField){k} = '';
                            fixed = true;
                        end
                    end
                    if length(coords) > app.maxSpoutPoints
                        valid = false;
                        fixed = false;
                        reasons = [reasons, sprintf('Maximum # of spout coordinates is %d.', app.maxSpoutPoints)];
                        if attemptFix
                            coordsFixed = coords(1:min([app.maxSpoutPoints, length(coords)]));
                            newDataTable.(spoutCoordField){k} = app.commaSeparateNums(coordsFixed);
                            coords = app.commaUnSeparateNums(newDataTable.(spoutCoordField){k});
                            if length(coords) <= app.maxSpoutPoints
                                fixed = true;
                            end
                        end
                    end
                    if any(isnan(coords))
                        valid = false;
                        fixed = false;
                        reasons = [reasons, 'Comma separated lists of spout coordinates contain an invalid coordinate. All coordinates must be numbers.'];
                        if attemptFix
                            coordsFixed = coords;
                            coordsFixed(isnan(coords)) = -1;
                            newDataTable.(spoutCoordField){k} = app.commaSeparateNums(coordsFixed);
                            coords = app.commaUnSeparateNums(newDataTable.(spoutCoordField){k});
                            if ~any(isnan(coords))
                                fixed = true;
                            end
                        end
                    end
                end
            end
            %             if ~all((newDataTable.Top_Y0 < newDataTable.Top_Y1) | (newDataTable.TopY1 == -1)) || ~all((newDataTable.Bot_Y0 < newDataTable.Bot_Y1) | (newDataTable.Bot_Y1 == -1))
%                 % Some Y0 is not smaller than Y1
%                 valid = false;
%                 reasons = [reasons, 'Box Y''s must be smaller than corresponding Y1''s'];
%             end
            if ~any(strcmp('SessionFPGADirs', newDataTable.Properties.VariableNames))
                valid = false;
                fixed = false;
                reasons = [reasons, 'SessionFPGADirs field missing'];
                if attemptFix
                    newDataTable.SessionFPGADirs = repmat({''}, height(newDataTable), 1);
                    fixed = true;
                end
            end
            if offerPathSwap
                % Give user opportunity to swap drive letter if paths are
                % not valid
                numMD = length(newDataTable.SessionMaskDirs);
                numVD = length(newDataTable.SessionVideoDirs);
                numFD = length(newDataTable.SessionFPGADirs);
                allDirs = [newDataTable.SessionMaskDirs; newDataTable.SessionVideoDirs; newDataTable.SessionFPGADirs];
                allDirs = validatePaths(allDirs, true, true);
                newDataTable.SessionMaskDirs = allDirs(1:numMD);
                newDataTable.SessionVideoDirs = allDirs((numMD+1):(numMD+numVD));
                newDataTable.SessionFPGADirs = allDirs((numMD+numVD+1):(numMD+numVD+numFD));
            end
            for k = 1:height(newDataTable)
                if app.isTableRowBlank(newDataTable(k, :))
                    % kth row is just a  blank row. Ignore it.
                    continue;
                end
                sessionMaskDir = newDataTable.SessionMaskDirs{k};
                sessionVideoDir = newDataTable.SessionVideoDirs{k};
                if ~isempty(sessionMaskDir) && ~exist(sessionMaskDir, 'file')
                    valid = false;
                fixed = false;
                    reasons = [reasons, ['Invalid mask directory: ', sessionMaskDir]];
                else
                    if ~isempty(sessionMaskDir) && ~exist(sessionMaskDir, 'dir')
                        valid = false;
                        fixed = false;
                        reasons = [reasons, ['Mask directory must be a directory, not a file: ', sessionMaskDir]];
                    end
                end
                if ~isempty(sessionVideoDir) && ~exist(sessionVideoDir, 'file')
                    valid = false;
                    fixed = false;
                    reasons = [reasons, ['Invalid video directory: ', sessionVideoDir]];
                    if attemptFix
                        newDataTable.sessionVideoDir{k} = '';
                        fixed = true;
                    end
                else
                    if ~isempty(sessionVideoDir) && ~exist(sessionVideoDir, 'dir')
                        valid = false;
                        fixed = false;
                        reasons = [reasons, ['Video directory must be a directory, not a file: ', sessionVideoDir]];
                        if attemptFix
                            newDataTable.sessionVideoDir{k} = '';
                            fixed = true;
                        end
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
        
        function [newRowNum, dataTable] = addNewDataTableRow(app, sessionMaskDir, dataTable)
            % Create a new data table row, and if optional sessionMaskDir
            % is provided, assign that dir. Return the row number of the
            % new row.
            if ~exist('dataTable', 'var')
                % we're doing this for the GUI data table
                dataTable = app.getDataTable(true);
                gui = true;
            else
                gui = false;
            end
            newTableRow = app.newSessionRow;
            if exist('sessionMaskDir', 'var') && ~isempty(sessionMaskDir)
                % If sessionMaskDir is provided, assign it to the new row
                newTableRow.sessionMaskDirs = sessionMaskDir;
            end
            if height(dataTable) == 0
                dataTable = app.newSessionRow;
            else
                dataTable = [dataTable; app.newSessionRow];
            end
            newRowNum = height(dataTable);
            if gui
                app.updateDataTable(dataTable);
            end
        end
        
        function row = getDataTableRow(app, sessionMaskDir, dataTable)
            % Find row index by session mask dir. This will only return one
            % index, as session mask dirs are guaranteed to be unique. If
            % it does find more than one row match, it will raise an error.
            if ~exist('dataTable', 'var')
                % User can pass in data table to save time, otherwise just
                % get the GUI data table.
                dataTable = app.getDataTable(true);
            end
            numRows = height(dataTable);
            idx = 1:numRows;
            row = idx(strcmp(sessionMaskDir, dataTable.SessionMaskDirs));
            if isempty(row)
                error('Nonexistent sessionMaskDir %s was supplied for getDataTableRow.', sessionMaskDir)
            elseif numel(row) > 1
                warning('Duplicate sesionMaskDirs detected.')
            end
        end
        
        function dataTable = setDataTableElements(app, properties, values, sessionMaskDirsOrRows, dataTable)
            % Flexible setter for data table elements.
            % If properties is
            %   char array => values should be a single value to set
            %   cell array => values should be a cell array of values to set
            % If sessionMaskDirs is
            %   not provided, set the property values for the current video session
            %   a char array, set the property values for the corresponding session
            %   a cell array of char arrays, properties should also be a cell array
            %       of the same length, and each property will be assigned in the
            %       corresponding sessionMaskDirs
            %   an (array of) doubles, properties should be a cell array
            %       of the same length, and each property will be assgned to
            %       the corresponding table row
            if ~exist('sessionMaskDirsOrRows', 'var') || isempty(sessionMaskDirsOrRows)
                % No session mask dir given
                if ~isempty(app.currentVideo.videoNode)
                    % use the one associated with the current video.
                    sessionMaskDirsOrRows = app.currentVideo.videoNode.Parent.UserData.sessionMaskDir;
                else
                    % Default to first row.
                    sessionMaskDirsOrRows = 1;
                end
            end
            if ~exist('dataTable', 'var')
                dataTable = app.getDataTable(true);
                gui = true;
            else
                gui = false;
            end
            if ~iscell(properties)
                properties = {properties};
            end
            for k = 1:numel(properties)
                % Figure out which data table row number(s) the user wants
                if iscell(sessionMaskDirsOrRows)
                    sessionMaskDir = sessionMaskDirsOrRows{k};
                    row = app.getDataTableRow(sessionMaskDir, dataTable);
                elseif ischar(sessionMaskDirsOrRows)
                    sessionMaskDir = sessionMaskDirsOrRows;
                    row = app.getDataTableRow(sessionMaskDirsOrRows, dataTable);
                elseif isnumeric(sessionMaskDirsOrRows)
                    if length(sessionMaskDirsOrRows) == 1
                        row = sessionMaskDirsOrRows;
                    else
                        row = sessionMaskDirsOrRows(k);
                    end
                end
                % Catch missing/duplicate row problems
                if isempty(row) || row > height(dataTable)
                    % Add a new row
                    if exist('sessionMaskDir', 'var')
                        % Create a new row with the specified mask dir
                        [row, dataTable] = app.addNewDataTableRow(sessionMaskDir, dataTable);
                    else
                        % No mask dir specified, add a blank row
                        [row, dataTable] = app.addNewDataTableRow([], dataTable);
                    end
                elseif numel(row) > 1
                    error('Duplicate sesionMaskDirs detected. That should not be possible.')
                end

                property = properties{k};
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
                elseif numel(values) == numel(properties)
                    % Value is not a char array or a cell array, and there's
                    % more than one element - index it.
                    value = values(k);
                else
                    % Value is not a char array or a cell array, and
                    % there's only one element.
                    value = values;
                end

                % Property specific behavior:
                defaultNeeded = false;
                switch property
                    case {'Bot_Spout_X', 'Bot_Spout_Y', 'Top_Spout_X', 'Top_Spout_Y'}
                        if isnumeric(value) && isvector(value)
                            % bot_spout_x and y are stored as comma-separated lists of coordinates
                            value = app.commaSeparateNums(value);
                        elseif ischar(value)
                            % Hopefully this is a correctly formatted
                            % comma-separated list. Leave it alone.
                        else
                            defaultNeeded = true;
                        end
                    case {'SessionMaskDirs', 'SessionVideoDirs', 'SessionFPGADirs'}
                        if ~ischar(value)
                            defaultNeeded = true;
                        end
                    case {'Top_Fiducial_Y','Fiducial_X', 'Bot_Fiducial_Y', 'Top_Y0', 'FPGAStartTrial', 'VideoStartTrial'}
                        if ~isnumeric(value) || ~isscalar(value)
                            defaultNeeded = true;
                        end
                end
                if defaultNeeded
                    % Value was not appropraite - set to default
                    warning('Could not set %s to given value because it was not the correct type.', property)
                    value = app.newSessionRow.(property);
                end
                
                if iscell(dataTable.(property)) && ~iscell(value)
                    value = {value};
                end
                dataTable.(property)(row) = value;
            end
            if gui
                app.updateDataTable(dataTable, true, true);
            end
        end

        function varargout = getDataTableElements(app, properties, sessionMaskDirsOrRows, dataTable)
            % Flexible getter for data table elements.
            % If properties is
            %   char array => values will be a single value
            %   cell array => values will be a cell array of values
            % If sessionMaskDirs is
            %   not provided, get the property values for the current video session
            %   a char array, get the property values for the corresponding session
            %   a cell array of char arrays, properties should also be a cell array
            %       of the same length, and each value will be gotten from the
            %       corresponding sessionMaskDirs
            %   an (array of) doubles, properties should be a cell array
            %       of the same length, and each value will be gotten from 
            %       the corresponding table row
            if ~exist('sessionMaskDirsOrRows', 'var') || isempty(sessionMaskDirsOrRows)
                % No session mask dir given, use the one associated with the
                %   current video.
                sessionMaskDirsOrRows = app.currentVideo.videoNode.Parent.UserData.sessionMaskDir;
            end
            if ~exist('dataTable', 'var')
               dataTable = app.getDataTable(true);
            end
            if ~iscell(properties)
                properties = {properties};
            end
            values = {};
            for k = 1:numel(properties)
                % Figure out which data table row number(s) the user wants
                if iscell(sessionMaskDirsOrRows)
                    row = app.getDataTableRow(sessionMaskDirsOrRows{k});
                elseif ischar(sessionMaskDirsOrRows)
                    row = app.getDataTableRow(sessionMaskDirsOrRows);
                elseif isnumeric(sessionMaskDirsOrRows)
                    if length(sessionMaskDirsOrRows) == 1
                        row = sessionMaskDirsOrRows;
                    else
                        row = sessionMaskDirsOrRows(k);
                    end
                end
                % Catch missing/duplicate row problems
                if isempty(row)
                    error('Nonexistent sessionMaskDir or row was supplied for setDataTableElements.')
                elseif numel(row) > 1
                    error('Duplicate sesionMaskDirs detected. That should not be possible.')
                end

                property = properties{k};
                value = dataTable.(property)(row);

                % Property specific getters:
                switch property
                    case {'Bot_Spout_X', 'Bot_Spout_Y', 'Top_Spout_X', 'Top_Spout_Y'}
                        value = app.commaUnSeparateNums(dataTable.(property)(row));
                end
                values{k} = value;
            end
            varargout = values;
        end
        
        function clearMarkers(app)
            % Clear any measurement markers on the image axes.
            if ~isempty(app.imageMarkers)
                delete(app.imageMarkers.topSpout);
                delete(app.imageMarkers.botSpout);
                delete(app.imageMarkers.spoutWidth);
                delete(app.imageMarkers.topFiducial);
                delete(app.imageMarkers.botFiducial);
%                 delete(app.imageMarkers.topBox);
%                 delete(app.imageMarkers.botBox);
                app.imageMarkers = struct.empty;
            end
        end
        
        function updateMarkers(app)
            app.print('Updating markers');
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
                topSpoutXs = app.getDataTableElements('Top_Spout_X', row, dataTable); % dataTable.Top_Spout_X(row);
                topSpoutYs = app.getDataTableElements('Top_Spout_Y', row, dataTable); % dataTable.Top_Spout_X(row);
                botSpoutXs = app.getDataTableElements('Bot_Spout_X', row, dataTable); % dataTable.Bot_Spout_X(row);
                botSpoutYs = app.getDataTableElements('Bot_Spout_Y', row, dataTable); % dataTable.Bot_Spout_X(row);
                spoutWidth = app.getDataTableElements('Spout_Width', row, dataTable);
                topSpoutNum = min([length(topSpoutXs), length(topSpoutYs)]);
                if topSpoutNum > 0
                    topSpoutXs = topSpoutXs(1:topSpoutNum);
                    topSpoutYs = topSpoutYs(1:topSpoutNum);
                else
                    topSpoutXs = [-1];
                    topSpoutYs = [-1];
                end
                botSpoutNum = min([length(botSpoutXs), length(botSpoutYs)]);
                if botSpoutNum > 0
                    botSpoutXs = botSpoutXs(1:botSpoutNum);
                    botSpoutYs = botSpoutYs(1:botSpoutNum);
                else
                    botSpoutXs = [-1];
                    botSpoutYs = [-1];
                end
                
                topFiducialY = dataTable.Top_Fiducial_Y(row);
                botFiducialY = dataTable.Bot_Fiducial_Y(row);
                fiducialX = dataTable.Fiducial_X(row);
%                 topY0 = dataTable.Top_Y0(row);
%                 topY1 = dataTable.Top_Y1(row);
%                 botY0 = dataTable.Bot_Y0(row);
%                 botY1 = dataTable.Bot_Y1(row);
                
%                 minX = 0; maxX = app.ImageAxes.XLim(1); maxX = app.ImageAxes.XLim(2);
%                 minY = app.ImageAxes.YLim(1); maxY = app.ImageAxes.YLim(2);
%                 [maxX, maxY] = size(app.currentVideo.Data);
%                 minY = 0;

                if isempty(app.imageMarkers)
                    app.imageMarkers(1).topSpout = line(app.ImageAxes, topSpoutXs, topSpoutYs, 'Marker', '+', 'MarkerSize', 10, 'LineStyle', 'none', 'Color', app.markerColors.topSpout, 'HitTest', 'off');
                    app.imageMarkers(1).botSpout = line(app.ImageAxes, botSpoutXs, botSpoutYs, 'Marker', '+', 'MarkerSize', 10, 'LineStyle', 'none', 'Color', app.markerColors.botSpout, 'HitTest', 'off');
                    app.imageMarkers(1).topFiducial = line(app.ImageAxes, fiducialX, topFiducialY, 'Marker', 'x', 'MarkerSize', 10, 'LineStyle', 'none', 'Color', app.markerColors.topFiducial, 'HitTest', 'off');
                    app.imageMarkers(1).botFiducial = line(app.ImageAxes, fiducialX, botFiducialY, 'Marker', 'x', 'MarkerSize', 10, 'LineStyle', 'none', 'Color', app.markerColors.botFiducial, 'HitTest', 'off');
                    app.imageMarkers(1).spoutWidth = quiver(app.ImageAxes, botSpoutXs, botSpoutYs, zeros(size(botSpoutXs)), -spoutWidth*ones(size(botSpoutYs)), 0, '.-', 'Color', app.markerColors.spoutWidth, 'HitTest', 'off');
%                     app.imageMarkers(1).topBox = rectangle(app.ImageAxes, 'Position', [minX, topY0, maxX-minX, topY1-topY0], 'LineStyle', ':', 'EdgeColor', [0.5, 0.5, 1], 'LineWidth', 2);
%                     app.imageMarkers(1).botBox = rectangle(app.ImageAxes, 'Position', [minX, botY0, maxX-minX, botY1-botY0], 'LineStyle', ':', 'EdgeColor', [0.5, 1, 0.5], 'LineWidth', 2);
                else
                    app.imageMarkers.topSpout.XData = topSpoutXs;
                    app.imageMarkers.topSpout.YData = topSpoutYs;
                    app.imageMarkers.botSpout.XData = botSpoutXs;
                    app.imageMarkers.botSpout.YData = botSpoutYs;
                    app.imageMarkers.spoutWidth.XData = botSpoutXs;
                    app.imageMarkers.spoutWidth.YData = botSpoutYs;
                    app.imageMarkers.spoutWidth.UData = zeros(size(botSpoutXs));
                    app.imageMarkers.spoutWidth.VData = -spoutWidth*ones(size(botSpoutYs));
                    app.imageMarkers.topFiducial.XData = fiducialX;
                    app.imageMarkers.topFiducial.YData = topFiducialY;
                    app.imageMarkers.botFiducial.XData = fiducialX;
                    app.imageMarkers.botFiducial.YData = botFiducialY;
%                     app.imageMarkers.topBox.Position = [minX, topY0, maxX-minX, topY1-topY0];
%                     app.imageMarkers.botBox.Position = [minX, botY0, maxX-minX, botY1-botY0];
                end
                if all(topSpoutXs < 0)
                    app.imageMarkers.topSpout.Visible = 'off';
                else
                    app.imageMarkers.topSpout.Visible = 'on';
                end
                if all(botSpoutXs < 0)
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
%                 drawnow;
            else
                app.clearMarkers();
            end
        end
        
        function print(app, msg)
%             disp(msg);
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
%             drawnow;
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

        function im_shifts = getImShifts(app, dataTable)
            % Calulate a list of im_shifts from the data table
            % im_shift is a measure of how much the top view is shifted
            %   relative to the bottom view due to mirror misalignment, 
            %   measured in pixels..

            if ~exist('dataTable', 'var')
                dataTable = app.getDataTable();
            end
            im_shifts = cell2mat(cellfun(@str2num, dataTable.Bot_Spout_X, 'UniformOutput', false)) - cell2mat(cellfun(@str2num, dataTable.Top_Spout_X, 'UniformOutput', false));
        end

        function getTongueTipSessionsTrack(app)
            app.print('Beginning tongue tip tracking for all sessions.');
            dataTable = app.getDataTable();
            sessionDataRoots = dataTable.SessionMaskDirs;
            im_shifts = app.getImShifts(dataTable);

            verboseFlag = app.VerboseCheckBox.Value;
%             makeMovieFlag = app.MakeMoviesCheckBox.Value;
            saveDataFlag = app.SaveTrackingDataCheckBox.Value;
%             savePlotsFlag = app.SaveKinematicsPlotsCheckBox.Value;
%             plotFlag = app.PlotKinematicsCheckBox.Value;
            
            % If parallel pool hasn't been initialized, initialize it.
            app.StartParallelPoolButtonPushed()

            % loop through session data folders
            for j = 1:numel(sessionDataRoots)
                sessionDataRoot = sessionDataRoots{j};
                if verboseFlag
                    app.print(['Processing session #', num2str(j), ': ', sessionDataRoot])
                end
                % set up tongue tip tracking params
                params(j) = setTTTTrackParams(im_shifts(j));
                
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
        
        function [topMaskPath, botMaskPath] = matchMaskToVideo(app, videoName, SessionVideoRoot, SessionMaskRoot)
            % Strip path and extension from videoname, if present.
            [~, videoName, ~] = fileparts(videoName);
            videos = findSessionVideos(SessionVideoRoot, 'avi', @parsePCCFilenameTimestamp);
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
            videos = findSessionVideos(sessionVideoDir, 'avi', @parsePCCFilenameTimestamp);
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
        
        function [ML, AP] = getBotMaskCoordinates(app, xVid, yVid, k, dataTable)
            % Translate between video coordinates and anatomical/mask
            % coordinates for session # k
            if ~exist('dataTable', 'var')
                dataTable = app.getDataTable();
            end
            [~, botMaskSize] = app.getSessionMaskSizes(dataTable.SessionMaskDirs{k});
            [videoHeight, ~] = app.getSessionVideoFrameSize(dataTable.SessionVideoDirs{k});
            ML = yVid - (videoHeight - botMaskSize(1));
            AP = xVid;
        end
        
        function [AP, DV] = getTopMaskCoordinates(app, xVid, yVid, k, dataTable)
            % Translate between video coordinates and anatomical/mask
            % coordinates for session # k
            if ~exist('dataTable', 'var')
                dataTable = app.getDataTable();
            end
            [topMaskSize, ~] = app.getSessionMaskSizes(dataTable.SessionMaskDirs{k});
            top_pix_shift = dataTable.Top_Y0(k);
            AP = xVid;
            DV = topMaskSize(1) - (yVid - top_pix_shift);
        end
        
        function fiducialPoint = getFiducialPoint(app, k)
            % Get the anatomical fiducial point in 3D space for session # k
            dataTable = app.getDataTable();
%             [topMaskSize, botMaskSize] = app.getSessionMaskSizes(dataTable.SessionMaskDirs{k});
%             [videoHeight, ~] = app.getSessionVideoFrameSize(dataTable.SessionVideoDirs{k});
%             top_pix_shift = dataTable.Top_Y0(k);
            [fiducial_ML, fiducial_AP] = app.getBotMaskCoordinates(dataTable.Fiducial_X(k), dataTable.Bot_Fiducial_Y(k), k, dataTable);
            [~, fiducial_DV] = app.getTopMaskCoordinates([], dataTable.Top_Fiducial_Y(k), k, dataTable);

%             fiducial_ML = app.SessionDataTable.Data.Bot_Fiducial_Y(k) - (videoHeight - botMaskSize(1));
%             fiducial_AP = app.SessionDataTable.Data.Fiducial_X(k);
%             fiducial_DV = topMaskSize(2) - (app.SessionDataTable.Data.Top_Fiducial_Y(k) - top_pix_shift);
            fiducialPoint = [fiducial_ML, fiducial_AP, fiducial_DV];
        end
        
        function spoutPositionCalibration = getSpoutPositionCalibration(app, k)
            dataTable = app.getDataTable();
            % Get spout position calibration struct for session # k
            spoutPositionCalibration = []; % ADD GUI DATATABLE GETTER CODE HERE
%             topSpoutXs = app.getDataTableElements('Top_Spout_X', row, dataTable); % dataTable.Top_Spout_X(row);
            topSpoutYs = app.getDataTableElements('Top_Spout_Y', k, dataTable); % dataTable.Top_Spout_X(row);
            botSpoutXs = app.getDataTableElements('Bot_Spout_X', k, dataTable); % dataTable.Bot_Spout_X(row);
            botSpoutYs = app.getDataTableElements('Bot_Spout_Y', k, dataTable); % dataTable.Bot_Spout_X(row);
            % Convert spout calibration video coordinates to mask coordinates
            [cal_MLs, cal_APs] = app.getBotMaskCoordinates(botSpoutXs, botSpoutYs, k, dataTable);
            [~, cal_DVs] = app.getTopMaskCoordinates([], topSpoutYs, k, dataTable);
            spoutPositionCalibration.x = cal_MLs;
            spoutPositionCalibration.y = cal_APs;
            spoutPositionCalibration.z = cal_DVs;
            spoutPositionCalibration.speed = app.getMotorSpeed(k, dataTable);
            spoutPositionCalibration.latency = app.getMotorLatency(k, dataTable);
            spoutPositionCalibration.width = app.getDataTableElements('Spout_Width', k, dataTable);
        end
        
        function motorSpeed = getMotorSpeed(app, k, dataTable)
            % Get motor speed for session # k
            if ~exist('dataTable', 'var')
                dataTable = app.getDataTable();
            end
            motorSpeed = app.getDataTableElements('MotorSpeed', k, dataTable);
%             motorSpeed = 0.45;  % ADD GUI DATATABLE GETTER CODE HERE
        end
        function motorLatency= getMotorLatency(app, k, dataTable)
            % Get motor latency (ms before motor responds) for session # k
            if ~exist('dataTable', 'var')
                dataTable = app.getDataTable();
            end
            motorLatency = app.getDataTableElements('MotorLatency', k, dataTable);
%             motorLatency= 27;  % ADD GUI DATATABLE GETTER CODE HERE
        end
        
        function updateRulerLength(app)
            if isempty(app.measuringRuler)
                return;
            end
            p = app.measuringRuler.Position;
            x1 = p(1, 1);
            y1 = p(1, 2);
            x2 = p(2, 1);
            y2 = p(2, 2);
            len = sqrt((x2 - x1)^2 + (y2 - y1)^2);
            app.measuringRuler.Label(sprintf('%f0.1', len));
        end
        
        function cs = commaSeparateNums(app, nums)
            cs = join(arrayfun(@(x)num2str(x), nums, 'UniformOutput', false), ',');
            if length(cs) == 1
                cs = cs{1};
            end
        end
        function nums = commaUnSeparateNums(app, cs)
            if isempty(cs) || (iscell(cs) && isempty(cs{1}))
                nums = [];
            else
                nums = cellfun(@(x)str2double(x), split(cs, ','));
            end
        end
        function valid = isValidCommaSeparatedString(app, cs)
            try
                nums = app.commaUnSeparateNums(cs);
                valid = true;
            catch ME
                valid = false;
            end
        end
        
        function clearDataTable(app)
            app.currentVideo.Data = [];
            app.updateDataTable(app.newSessionRow, false);
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
            app.markerColors.topSpout = [0, 1, 0];
            app.markerColors.botSpout = [0, 0.4, 1];
            app.markerColors.topBox = [0.5, 0.5, 1];
            app.markerColors.botBox = [0.5, 1, 0.5];
            app.markerColors.spoutWidth = [0, 0.4, 1];
            
            app.TopFiducialLabel.FontColor = app.markerColors.topFiducial;
            app.BotFiducialLabel.FontColor = app.markerColors.botFiducial;
            app.TopSpoutLabel.FontColor = app.markerColors.topSpout;
            app.BotSpoutLabel.FontColor = app.markerColors.botSpout;
            app.SpoutWidthLabel.FontColor = app.markerColors.spoutWidth;

            app.TopFiducialLabel.BackgroundColor = 0.8*[1, 1, 1];
            app.BotFiducialLabel.BackgroundColor = 0.8*[1, 1, 1];
            app.TopSpoutLabel.BackgroundColor = 0.8*[1, 1, 1];
            app.BotSpoutLabel.BackgroundColor = 0.8*[1, 1, 1];
            app.SpoutWidthLabel.BackgroundColor = 0.8*[1, 1, 1];
            
            app.maxSpoutPoints = 4;  % If the user tries to enter more than this, the list will clear and start over automaticaly

            app.dataTableAutoSaveName = 'tongueTrackerDataTableAutoSave.mat';
            
            % Configure image axes
            hold(app.ImageAxes, 'on');
            app.ImageAxes.Visible = 'off';
            app.ImageAxes.Colormap = gray(256);
            axis(app.ImageAxes, 'image');
            app.UIFigure.WindowButtonMotionFcn = @app.mouseMotionHandler;
            
           
            % Configure measuring ruler
            try
                app.measuringRuler = images.roi.Line(app.ImageAxes,'Position',[50, 50; 100, 50], 'Visible', 'off');
                addlistener(app.measuringRuler, 'MovingROI', @app.updateRulerLength);
            catch ME
                app.print('Sorry, ruler does not appear to be available in this version of MATLAB. Upgrade to 2020 or later.')
                app.measuringRuler = images.roi.Line.empty();
            end
            
            app.currentVideo = struct();
            app.currentVideo.Data = [];
%            app.currentVideo.Path = '';
            app.currentVideo.videoName = '';
            app.currentVideo.SessionVideoDir = '';
            app.currentVideo.SessionMaskDir = '';
            app.currentVideo.videoNode = [];

            app.imageMarkers = struct.empty;
            
            app.newSessionRow = table(true, {''}, {''}, {''}, {''}, {''}, {''}, {''}, NaN, -1, -1, -1, 0, 1, 1, 0.45, 27, ...
                'VariableNames', {'Active', 'SessionMaskDirs', 'SessionVideoDirs', 'SessionFPGADirs', 'Bot_Spout_X', 'Bot_Spout_Y', 'Top_Spout_X', 'Top_Spout_Y', 'Spout_Width', 'Fiducial_X', 'Bot_Fiducial_Y', 'Top_Fiducial_Y', 'Top_Y0', 'FPGAStartTrial', 'VideoStartTrial', 'MotorSpeed', 'MotorLatency'});
            
            app.maxOutputLength = 256;
            
            app.updateParallelPoolStateLabel();
            
            app.updateDataTable(app.newSessionRow, false);
            app.SessionDataTable.ColumnName = app.newSessionRow.Properties.VariableNames;
            app.SessionDataTable.ColumnWidth = {50, 100, 100, 100, 95, 95, 95, 95, 95, 95, 95, 95, 95, 95, 95};
            app.SessionDataTable.ColumnEditable = true;
%             dataTableContextMenu = uicontextmenu();
%             app.SessionDataTable.ContextMenu = dataTableContextMenu;
            
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
            app.addNewDataTableRow();
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
%             drawnow;
        end

        % Button pushed function: LoadVideoButton
        function LoadVideoButtonPushed(app, event)
            videoNode = app.VideoBrowser.SelectedNodes;
            videoDir = videoNode.Parent.NodeData;
            videoName = videoNode.Text;
            videoPath = fullfile(videoDir, videoName);
            SessionMaskDir = videoNode.Parent.UserData.sessionMaskDir;
            app.print(['Loading video ', videoName, '...'])
            app.currentVideo.Data = loadVideoData(videoPath);
            app.print('    ...done loading video')
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
            modifier = event.Modifier;
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
                    currentPoint = round(double(app.ImageAxes.CurrentPoint(1, 1:2)));
                    curX = currentPoint(1); 
                    curY = currentPoint(2);
                    dataTable = app.getDataTable();
                    topSpoutXs = app.getDataTableElements('Top_Spout_X', [], dataTable);
                    topSpoutYs = app.getDataTableElements('Top_Spout_Y', [], dataTable);
                    if length(topSpoutXs) + 1 > app.maxSpoutPoints
                        topSpoutXs = curX;
                        topSpoutYs = curY;
                    else
                        topSpoutXs = [topSpoutXs; curX];
                        topSpoutYs = [topSpoutYs; curY];
                    end
                    dataTable = app.setDataTableElements('Top_Spout_X', topSpoutXs, [], dataTable);
                    dataTable = app.setDataTableElements('Top_Spout_Y', topSpoutYs, [], dataTable);
                    app.updateDataTable(dataTable);
                case '4'
                    % Bot spout
                    currentPoint = round(double(app.ImageAxes.CurrentPoint(1, 1:2)));
                    curX = currentPoint(1); 
                    curY = currentPoint(2);
                    dataTable = app.getDataTable();
                    botSpoutXs = app.getDataTableElements('Bot_Spout_X', [], dataTable);
                    botSpoutYs = app.getDataTableElements('Bot_Spout_Y', [], dataTable);
                    if length(botSpoutXs) + 1 > app.maxSpoutPoints
                        botSpoutXs = curX;
                        botSpoutYs = curY;
                    else
                        botSpoutXs = [botSpoutXs; curX];
                        botSpoutYs = [botSpoutYs; curY];
                    end
                    dataTable = app.setDataTableElements('Bot_Spout_X', botSpoutXs, [], dataTable);
                    dataTable = app.setDataTableElements('Bot_Spout_Y', botSpoutYs, [], dataTable);
                    app.updateDataTable(dataTable);
                case '5'
                    dataTable = app.getDataTable();
                    botSpoutXs = app.getDataTableElements('Bot_Spout_X', [], dataTable);
                    botSpoutYs = app.getDataTableElements('Bot_Spout_Y', [], dataTable);
                    if ~isempty(botSpoutXs) && ~isempty(botSpoutYs)
                        currentPoint = round(double(app.ImageAxes.CurrentPoint(1, 1:2)));
                        curX = currentPoint(1);
                        curY = currentPoint(2);
                        [~, idx] = min(abs(botSpoutXs - curX));
                        width = botSpoutYs(idx) - curY;
                        dataTable = app.setDataTableElements('Spout_Width', width, [], dataTable);
                        app.updateDataTable(dataTable);
                    else
                        app.print('Please mark at least one bottom spout location before marking spout width')
                    end
                case 'leftarrow'
                    if any(strcmp(modifier, 'shift'))
                        delta = -10;
                    else
                        delta = -1;
                    end
                    app.FrameSlider.Value = mod(floor(app.FrameSlider.Value)+delta-1, size(app.currentVideo.Data, 3))+1;
                    app.updateFrame(app.FrameSlider.Value);
                case 'rightarrow'
                    if any(strcmp(modifier, 'shift'))
                        delta = 10;
                    else
                        delta = 1;
                    end
                    app.FrameSlider.Value = mod(floor(app.FrameSlider.Value)+delta-1, size(app.currentVideo.Data, 3))+1;
                    app.updateFrame(app.FrameSlider.Value);
            end
%             drawnow;
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
                app.clearDataTable();
                dataTable = app.getDataTable(true);
                filepath = fullfile(path, name);
                loadedVars = load(filepath);
%                dataTable = app.newSessionRow;
                [valid, reasons, fixed, loadedVars.dataTable] = app.validateDataTable(loadedVars.dataTable, true, true);
                for variableNum = 1:width(loadedVars.dataTable)
                    variable = loadedVars.dataTable.Properties.VariableNames{variableNum};
                    if any(strcmp(variable, app.newSessionRow.Properties.VariableNames))
                        dataTable = app.setDataTableElements(repmat({variable}, [1, height(loadedVars.dataTable)]), loadedVars.dataTable.(variable), 1:height(loadedVars.dataTable), dataTable);
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

        % Button pushed function: CleartableButton
        function CleartableButtonPushed(app, event)
            answer = uiconfirm(app.UIFigure, 'Are you sure you want to clear the data table?', 'Confirm clear', 'Icon', 'warning');
            if strcmp(answer, 'OK')
                app.clearDataTable();
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
                fiducials(k).top = [dataTable.Fiducial_X(k), dataTable.Top_Fiducial_Y(k) - top_pix_shift];
                fiducials(k).bot = [dataTable.Fiducial_X(k), dataTable.Bot_Fiducial_Y(k) - (videoHeight - botMaskSize(1))];
            end
            
            queue = parallel.pool.DataQueue();
            afterEach(queue, @app.print);

            get_mask_props(dataTable.SessionMaskDirs, fiducials, queue);    
        end

        % Button pushed function: BLabelvideoswcuelaserButton
        function BLabelvideoswcuelaserButtonPushed(app, event)
            dryrun = app.DryrunCheckBox.Value;
            queue = parallel.pool.DataQueue();
            afterEach(queue, @app.print);
            dataTable = app.getDataTable();
            app.print('Labeling avi files with cue and laser...')
            relabel = app.RelabelCheckBox.Value;
            parfor k = 1:numel(dataTable.SessionVideoDirs)
                sessionVideoDir = dataTable.SessionVideoDirs{k};
                labelTrialsWithCueAndLaser(sessionVideoDir, sessionVideoDir, '.avi', dryrun, queue, 'relabel', relabel);
            end
            app.print('...done labeling avi files with cue and laser')            
        end

        % Button pushed function: EGetlicksegmentationandkinematicsButton
        function EGetlicksegmentationandkinematicsButtonPushed(app, event)
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
                cines = [cines, findSessionVideos(dataTable.SessionVideoDirs{k}, 'cine', @parsePCCFilenameTimestamp)'];
            end
            queue = parallel.pool.DataQueue();
            afterEach(queue, @app.print);
            convertCinesToAVIs(cines, true, queue);
            app.updateVideoBrowser();
        end

        % Button pushed function: reloadVideoBrowser
        function reloadVideoBrowserButtonPushed(app, event)
            forceUpdate = true;
            lazy = true;
            app.updateVideoBrowser(forceUpdate, lazy);
        end

        % Button pushed function: FAlignFPGAandVideoTrialsButton
        function FAlignFPGAandVideoTrialsButtonPushed(app, event)
            dataTable = app.getDataTable();
            sessionMaskRoots = dataTable.SessionMaskDirs;
            sessionVideoRoots = dataTable.SessionVideoDirs;
            sessionFPGARoots = dataTable.SessionFPGADirs;
            [tdiffs_FPGA, tdiffs_Video, result] = get_tdiff_video(sessionVideoRoots, sessionFPGARoots, @parsePCCFilenameTimestamp);
            
            if ~islogical(result) || ~result
                app.print(result);
            end
            app.print('Initiating user alignment of FPGA and video trials...');
            app.print('FPGA == green | Video == cyan');
            startingTrialNums = alignTDiffs(sessionMaskRoots, tdiffs_FPGA, tdiffs_Video);
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
                        case "1D Fakeout"
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
                        case "1D Fakeout"
                            [nl_struct,raster_struct,result] = nplick_struct_1D(sessionFPGARoot, plotOutput);
                        case "2D Fakeout"
                            [nl_struct,raster_struct,result] = nplick_struct_2D(sessionFPGARoot, plotOutput);                            
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

        % Button pushed function: GIncorporateFPGAdataintotiptracksButton
        function GIncorporateFPGAdataintotiptracksButtonPushed(app, event)
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
                case '1D Fakeout'
                    [vid_ind_arr, result] = align_videos_toFakeOutData_1D(sessionVideoRoots,sessionMaskRoots,sessionFPGARoots,time_aligned_trials);
                case '2D Fakeout'
                    % Get calibration for spout position
                    spoutCalibrations = {};

                    % Calculate im_shift for each session
                    im_shifts = app.getImShifts(dataTable);

                    for sessionNum = 1:length(sessionMaskRoots)
                        spoutCalibrations{sessionNum} = app.getSpoutPositionCalibration(sessionNum);
                        params(sessionNum) = setTTTTrackParams(im_shifts(sessionNum));
                    end
                    motorSpeeds = [];
                    [vid_ind_arr, result] = align_videos_toFakeOutData_2D(sessionVideoRoots,sessionMaskRoots,sessionFPGARoots,time_aligned_trials, spoutCalibrations, motorSpeeds, params);
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
'     will be incorporated into the session data table. Note that after clicking'
'     on the image, pressing left/right arrow will go back/forwards 1 frame, and'
'     clicking shift-left/shift-right will go back/forwards 10 frames.'
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

        % Value changed function: MeasuringRulerCheckBox
        function MeasuringRulerCheckBoxValueChanged(app, event)
            if isempty(app.measuringRuler)
                return;
            end
            visible = app.MeasuringRulerCheckBox.Value;
            if visible
                app.measuringRuler.Visible = 'on';
            else
                app.measuringRuler.Visible = 'off';
            end

        end

        % Node expanded function: VideoBrowser
        function VideoBrowserNodeExpanded(app, event)
            node = event.Node;
            if length(node.Children) == 1
                if strcmp(node.Children(1).NodeData, 'unloaded')
                % This is a placeholder - video session node has not been populated - delete placeholder and populate it now
                delete(node.Children(1));
                app.populateVideoSessionNode(node);
                end
            end
        end

        % Button pushed function: AddDataTableButton
        function AddDataTableButtonPushed(app, event)
           [name, path] = uigetfile('', 'Choose a file that contains a saved data table to append to the current table:');
            if numel(name) > 1
                oldDataTable = app.getDataTable(true);
                dataTable = oldDataTable;
                dataTable(:, :) = []; % Clear rows
                filepath = fullfile(path, name);
                loadedVars = load(filepath);
%                dataTable = app.newSessionRow;
                [valid, reasons, fixed, loadedVars.dataTable] = app.validateDataTable(loadedVars.dataTable, true, true);
                for variableNum = 1:width(loadedVars.dataTable)
                    variable = loadedVars.dataTable.Properties.VariableNames{variableNum};
                    if any(strcmp(variable, app.newSessionRow.Properties.VariableNames))
                        dataTable = app.setDataTableElements(repmat({variable}, [1, height(loadedVars.dataTable)]), loadedVars.dataTable.(variable), 1:height(loadedVars.dataTable), dataTable);
                    else
                        app.print(['Discarded variable ''', variable, ''' because it didn''t match any valid variables'])
                    end
                end
                newDataTable = [oldDataTable; dataTable];
                [valid, reasons, fixed, newDataTable] = app.validateDataTable(newDataTable, true);
                if valid
                    app.updateDataTable(newDataTable);
                    app.print(['Appended data table from ', filepath]);
                else
                    app.print('Error when appending loaded table:');
                    for k = 1:length(reasons)
                        app.print(['    ', reasons{k}]);
                    end
                    if fixed
                        app.print('Resolved errors.')
                        app.updateDataTable(newDataTable);
                    end
                end
            else
                app.print('Cancel data table add');
            end 
        end

        % Button pushed function: DeleteSessionButton
        function DeleteSessionButtonPushed(app, event)
            row = app.sessionDataTableSelection(1);
            if ~isempty(row) && row > 0
                dataTable = app.getDataTable(true);
                dataTable(row, :) = [];
                app.updateDataTable(dataTable);
            end
        end

        % Button pushed function: CHealSpoutOcclusionsButton
        function CHealSpoutOcclusionsButtonPushed(app, event)
            dataTable = app.getDataTable();
            sessionMaskRoots = dataTable.SessionMaskDirs;
            sessionVideoRoots = dataTable.SessionVideoDirs;
            sessionFPGARoots = dataTable.SessionFPGADirs;
            
            time_aligned_trials = [dataTable.VideoStartTrial, dataTable.FPGAStartTrial];
            
            for session_num = 1:length(sessionMaskRoots)
                spout_calibration = app.getSpoutPositionCalibration(session_num);
                sessionMaskRoot = sessionMaskRoots{session_num};
                sessionVideoRoot = sessionVideoRoots{session_num};
                sessionFPGARoot = sessionFPGARoots{session_num};
                time_aligned_trial = time_aligned_trials(session_num, :);
                cue_frame = 1001;  % This is typically the cue frame

%                      viewSpoutTracking(sessionMaskRoot, sessionVideoRoot, sessionFPGARoot, time_aligned_trial, spout_calibration, cue_frame)

                auto_revert_old_healing = app.AutorevertoldhealsCheckBox.Value;
                if ~auto_revert_old_healing
                    % Check if this directory has preexisting occlusion
                    % healing files
                    [~, ~, overwrite_warning] = getOcclusionsDirs(sessionMaskRoot);
                    if overwrite_warning
                        yesChoice = 'Yes, revert now';
                        noChoice = 'No, continue (not recommended)';
                        cancelChoice = 'Cancel occlusion healing session';
                        answer = questdlg( ...
                            sprintf(['This directory (%s) appears to already have occlusion healing results'...
                                '- it is recommended to revert to the original state before re-healing '...
                                'occlusions. Revert now?'], sessionMaskRoot), ... 
                                'Revert previous occlusion healing?', ...
                                yesChoice, noChoice, cancelChoice, yesChoice);
                        switch answer
                            case yesChoice
                                % Revert, then continue
                                revertOcclusionHealing(sessionMaskRoot);
                            case noChoice
                                % Continue without reverting
                            case {cancelChoice, ''}
                                % Cancel processing
                                break;
                        end
                    end
                end
                app.print(sprintf('Healing occlusions in masks for session %s...', sessionMaskRoot));
                tic
                heal_occlusion_session(sessionMaskRoot, sessionVideoRoot, sessionFPGARoot, time_aligned_trial, spout_calibration, cue_frame);
                toc
                app.print('...done healing occlusions');
            end
        end

        % Button pushed function: C2OcclusioneditorButton
        function C2OcclusioneditorButtonPushed(app, event)
            dataTable = app.getDataTable();
            sessionMaskRoots = dataTable.SessionMaskDirs;
            sessionVideoRoots = dataTable.SessionVideoDirs;

            if isempty(app.sessionDataTableSelection)
                session_num = 1;
            else
                session_num = app.sessionDataTableSelection(1);
            end
            app.print('Opening occlusion browser')
            occlusionBrowser(sessionMaskRoots{session_num}, sessionVideoRoots{session_num});
        end

        % Value changed function: FPGAdataformatDropDown
        function FPGAdataformatDropDownValueChanged(app, event)
            value = app.FPGAdataformatDropDown.Value;
            
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
            app.ImageAxes.Position = [15 180 223 507];

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
            app.FrameLabel.Position = [15 126 50 22];
            app.FrameLabel.Text = 'Frame #';

            % Create FrameSlider
            app.FrameSlider = uislider(app.UIFigure);
            app.FrameSlider.ValueChangedFcn = createCallbackFcn(app, @FrameSliderValueChanged, true);
            app.FrameSlider.ValueChangingFcn = createCallbackFcn(app, @FrameSliderValueChanging, true);
            app.FrameSlider.Position = [23 172 203 3];

            % Create AddSessionButton
            app.AddSessionButton = uibutton(app.UIFigure, 'push');
            app.AddSessionButton.ButtonPushedFcn = createCallbackFcn(app, @AddSessionButtonPushed, true);
            app.AddSessionButton.Position = [591 217 51 36];
            app.AddSessionButton.Text = {'Add'; 'Session'};

            % Create VideoBrowser
            app.VideoBrowser = uitree(app.UIFigure);
            app.VideoBrowser.SelectionChangedFcn = createCallbackFcn(app, @VideoBrowserSelectionChanged, true);
            app.VideoBrowser.NodeExpandedFcn = createCallbackFcn(app, @VideoBrowserNodeExpanded, true);
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
            app.ShowCrosshairCheckBox.Position = [23 74 104 22];
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
            app.ShowMarkersCheckBox.Position = [23 95 104 22];
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
            app.TiptrackprocessingLabel.Position = [675 604 137 22];
            app.TiptrackprocessingLabel.Text = 'Tip track processing';

            % Create VerboseCheckBox
            app.VerboseCheckBox = uicheckbox(app.UIFigure);
            app.VerboseCheckBox.Text = 'Verbose processing';
            app.VerboseCheckBox.Position = [673 583 137 22];
            app.VerboseCheckBox.Value = true;

            % Create MakeMoviesCheckBox
            app.MakeMoviesCheckBox = uicheckbox(app.UIFigure);
            app.MakeMoviesCheckBox.Text = 'Make movies';
            app.MakeMoviesCheckBox.Position = [673 499 137 22];

            % Create PlotKinematicsCheckBox
            app.PlotKinematicsCheckBox = uicheckbox(app.UIFigure);
            app.PlotKinematicsCheckBox.Text = 'Plot kinematics';
            app.PlotKinematicsCheckBox.Position = [673 541 137 22];

            % Create SaveTrackingDataCheckBox
            app.SaveTrackingDataCheckBox = uicheckbox(app.UIFigure);
            app.SaveTrackingDataCheckBox.Text = 'Save tracking data';
            app.SaveTrackingDataCheckBox.Position = [673 562 137 22];
            app.SaveTrackingDataCheckBox.Value = true;

            % Create SaveKinematicsPlotsCheckBox
            app.SaveKinematicsPlotsCheckBox = uicheckbox(app.UIFigure);
            app.SaveKinematicsPlotsCheckBox.Text = 'Save kinematics plots';
            app.SaveKinematicsPlotsCheckBox.Position = [673 520 137 22];

            % Create TrackTongueTipsButton
            app.TrackTongueTipsButton = uibutton(app.UIFigure, 'push');
            app.TrackTongueTipsButton.ButtonPushedFcn = createCallbackFcn(app, @TrackTongueTipsButtonPushed, true);
            app.TrackTongueTipsButton.Tooltip = {'Run tip tracking on masks to produce tip_track files (each row in struct is a trial)'};
            app.TrackTongueTipsButton.Position = [669 372 130 42];
            app.TrackTongueTipsButton.Text = 'D. Track tongue tips';

            % Create SaveDataTableButton
            app.SaveDataTableButton = uibutton(app.UIFigure, 'push');
            app.SaveDataTableButton.ButtonPushedFcn = createCallbackFcn(app, @SaveDataTableButtonPushed, true);
            app.SaveDataTableButton.Tooltip = {'Save directories and marker locations for later use.'};
            app.SaveDataTableButton.Position = [853 217 42 36];
            app.SaveDataTableButton.Text = {'Save'; 'table'};

            % Create LoadDataTableButton
            app.LoadDataTableButton = uibutton(app.UIFigure, 'push');
            app.LoadDataTableButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDataTableButtonPushed, true);
            app.LoadDataTableButton.Tooltip = {'Load a previously created data table from a file'; ' replacing the existing table.'};
            app.LoadDataTableButton.Position = [759 217 42 36];
            app.LoadDataTableButton.Text = {'Load'; 'table'};

            % Create CleartableButton
            app.CleartableButton = uibutton(app.UIFigure, 'push');
            app.CleartableButton.ButtonPushedFcn = createCallbackFcn(app, @CleartableButtonPushed, true);
            app.CleartableButton.Tooltip = {'Delete all values in data table!'};
            app.CleartableButton.Position = [901 217 42 36];
            app.CleartableButton.Text = {'Clear'; 'table'};

            % Create TopFiducialLabel
            app.TopFiducialLabel = uilabel(app.UIFigure);
            app.TopFiducialLabel.Position = [478 402 186 22];
            app.TopFiducialLabel.Text = '2 = Top fiducial (y coord.)';

            % Create BotFiducialLabel
            app.BotFiducialLabel = uilabel(app.UIFigure);
            app.BotFiducialLabel.Position = [478 421 186 22];
            app.BotFiducialLabel.Text = '1 = Bot. fiducial (x and y coord.)';

            % Create TopSpoutLabel
            app.TopSpoutLabel = uilabel(app.UIFigure);
            app.TopSpoutLabel.Position = [478 382 186 22];
            app.TopSpoutLabel.Text = '3 = Top spout LL corner positions';

            % Create BotSpoutLabel
            app.BotSpoutLabel = uilabel(app.UIFigure);
            app.BotSpoutLabel.Position = [478 362 186 22];
            app.BotSpoutLabel.Text = '4 = Bot..spout LL corner positions';

            % Create OpenselecteddirectoryButton
            app.OpenselecteddirectoryButton = uibutton(app.UIFigure, 'push');
            app.OpenselecteddirectoryButton.ButtonPushedFcn = createCallbackFcn(app, @OpenselecteddirectoryButtonPushed, true);
            app.OpenselecteddirectoryButton.Position = [486 217 94 36];
            app.OpenselecteddirectoryButton.Text = {'Open selected'; 'directory'};

            % Create EGetlicksegmentationandkinematicsButton
            app.EGetlicksegmentationandkinematicsButton = uibutton(app.UIFigure, 'push');
            app.EGetlicksegmentationandkinematicsButton.ButtonPushedFcn = createCallbackFcn(app, @EGetlicksegmentationandkinematicsButtonPushed, true);
            app.EGetlicksegmentationandkinematicsButton.Tooltip = {'Segment tip_track files into separate licks, and calculate various kinematic measures. Store results in t_stats file (each row in struct is a lick)'};
            app.EGetlicksegmentationandkinematicsButton.Position = [669 321 130 42];
            app.EGetlicksegmentationandkinematicsButton.Text = {'E. Get lick segmentation'; 'and kinematics'};

            % Create BLabelvideoswcuelaserButton
            app.BLabelvideoswcuelaserButton = uibutton(app.UIFigure, 'push');
            app.BLabelvideoswcuelaserButton.ButtonPushedFcn = createCallbackFcn(app, @BLabelvideoswcuelaserButtonPushed, true);
            app.BLabelvideoswcuelaserButton.Tooltip = {'Label all .avi videos found in all SessionVideoDirs'; ' and label them with the cue frame and whether or not an "event" (laser) was marked. Requires that xml metadata files with corresponding names are present for each avi.'};
            app.BLabelvideoswcuelaserButton.Position = [478 533 101 39];
            app.BLabelvideoswcuelaserButton.Text = {'B. Label videos '; 'w/ cue & laser'};

            % Create DryrunCheckBox
            app.DryrunCheckBox = uicheckbox(app.UIFigure);
            app.DryrunCheckBox.Text = 'Dry run';
            app.DryrunCheckBox.Position = [588 554 74 18];

            % Create reloadVideoBrowser
            app.reloadVideoBrowser = uibutton(app.UIFigure, 'push');
            app.reloadVideoBrowser.ButtonPushedFcn = createCallbackFcn(app, @reloadVideoBrowserButtonPushed, true);
            app.reloadVideoBrowser.Icon = 'Refresh_icon.png';
            app.reloadVideoBrowser.IconAlignment = 'center';
            app.reloadVideoBrowser.Position = [337 684 25 23];
            app.reloadVideoBrowser.Text = '';

            % Create FAlignFPGAandVideoTrialsButton
            app.FAlignFPGAandVideoTrialsButton = uibutton(app.UIFigure, 'push');
            app.FAlignFPGAandVideoTrialsButton.ButtonPushedFcn = createCallbackFcn(app, @FAlignFPGAandVideoTrialsButtonPushed, true);
            app.FAlignFPGAandVideoTrialsButton.Tooltip = {'Align FPGA and video trials to produce a mapping between FPGA trial number and video number (sometimes the FPGA may start recording before the video, or vice versa)'};
            app.FAlignFPGAandVideoTrialsButton.Position = [669 291 268 23];
            app.FAlignFPGAandVideoTrialsButton.Text = 'F. Align FPGA and Video Trials';

            % Create ACombineconvertFPGAdatfilesButton
            app.ACombineconvertFPGAdatfilesButton = uibutton(app.UIFigure, 'push');
            app.ACombineconvertFPGAdatfilesButton.ButtonPushedFcn = createCallbackFcn(app, @ACombineconvertFPGAdatfilesButtonPushed, true);
            app.ACombineconvertFPGAdatfilesButton.Tooltip = {'Runs ppscript on all FPGA data directories specified'};
            app.ACombineconvertFPGAdatfilesButton.Position = [809 531 130 42];
            app.ACombineconvertFPGAdatfilesButton.Text = {'A. Combine/convert '; 'FPGA dat files'};

            % Create BProcessFPGAdataButton
            app.BProcessFPGAdataButton = uibutton(app.UIFigure, 'push');
            app.BProcessFPGAdataButton.ButtonPushedFcn = createCallbackFcn(app, @BProcessFPGAdataButtonPushed, true);
            app.BProcessFPGAdataButton.Tooltip = {'Runs nplick_struct on all FPGA data directories specified. Must combine/convert dat files first. Produces lick_struct files'};
            app.BProcessFPGAdataButton.Position = [809 482 78 42];
            app.BProcessFPGAdataButton.Text = {'B. Process '; 'FPGA data'};

            % Create PlotNplickOutputCheckBox
            app.PlotNplickOutputCheckBox = uicheckbox(app.UIFigure);
            app.PlotNplickOutputCheckBox.Text = {'Plot'; 'output'};
            app.PlotNplickOutputCheckBox.Position = [890 482 55 41];

            % Create ClearButton
            app.ClearButton = uibutton(app.UIFigure, 'push');
            app.ClearButton.ButtonPushedFcn = createCallbackFcn(app, @ClearButtonPushed, true);
            app.ClearButton.Position = [1008 680 41 22];
            app.ClearButton.Text = 'Clear';

            % Create GIncorporateFPGAdataintotiptracksButton
            app.GIncorporateFPGAdataintotiptracksButton = uibutton(app.UIFigure, 'push');
            app.GIncorporateFPGAdataintotiptracksButton.ButtonPushedFcn = createCallbackFcn(app, @GIncorporateFPGAdataintotiptracksButtonPushed, true);
            app.GIncorporateFPGAdataintotiptracksButton.Tooltip = {'Incorporate FPGA data into the t_stats file'};
            app.GIncorporateFPGAdataintotiptracksButton.Position = [669 261 268 23];
            app.GIncorporateFPGAdataintotiptracksButton.Text = 'G. Incorporate FPGA data into tip tracks';

            % Create OverlayMasksCheckBox
            app.OverlayMasksCheckBox = uicheckbox(app.UIFigure);
            app.OverlayMasksCheckBox.ValueChangedFcn = createCallbackFcn(app, @OverlayMasksCheckBoxValueChanged, true);
            app.OverlayMasksCheckBox.Text = 'Overlay Masks';
            app.OverlayMasksCheckBox.Position = [23 51 104 22];
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
            app.FPGAdataformatDropDownLabel.Position = [809 603 102 22];
            app.FPGAdataformatDropDownLabel.Text = 'FPGA data format';

            % Create FPGAdataformatDropDown
            app.FPGAdataformatDropDown = uidropdown(app.UIFigure);
            app.FPGAdataformatDropDown.Items = {'Classic', '1D Fakeout', '2D Fakeout'};
            app.FPGAdataformatDropDown.ValueChangedFcn = createCallbackFcn(app, @FPGAdataformatDropDownValueChanged, true);
            app.FPGAdataformatDropDown.Position = [809 582 130 22];
            app.FPGAdataformatDropDown.Value = '2D Fakeout';

            % Create MeasuringRulerCheckBox
            app.MeasuringRulerCheckBox = uicheckbox(app.UIFigure);
            app.MeasuringRulerCheckBox.ValueChangedFcn = createCallbackFcn(app, @MeasuringRulerCheckBoxValueChanged, true);
            app.MeasuringRulerCheckBox.Text = 'Measuring Ruler';
            app.MeasuringRulerCheckBox.Position = [23 30 110 22];

            % Create SpoutWidthLabel
            app.SpoutWidthLabel = uilabel(app.UIFigure);
            app.SpoutWidthLabel.Position = [478 341 186 22];
            app.SpoutWidthLabel.Text = '5 = Bot. spout width';

            % Create AddDataTableButton
            app.AddDataTableButton = uibutton(app.UIFigure, 'push');
            app.AddDataTableButton.ButtonPushedFcn = createCallbackFcn(app, @AddDataTableButtonPushed, true);
            app.AddDataTableButton.Tooltip = {'Load a previously created data table from a file'; ' appending to the existing table.'};
            app.AddDataTableButton.Position = [807 217 42 36];
            app.AddDataTableButton.Text = {'Add'; 'table'};

            % Create DeleteSessionButton
            app.DeleteSessionButton = uibutton(app.UIFigure, 'push');
            app.DeleteSessionButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteSessionButtonPushed, true);
            app.DeleteSessionButton.Position = [648 217 59 36];
            app.DeleteSessionButton.Text = {'Delete'; 'Session'};

            % Create RelabelCheckBox
            app.RelabelCheckBox = uicheckbox(app.UIFigure);
            app.RelabelCheckBox.Tooltip = {'Relabel already-labeled videos?'};
            app.RelabelCheckBox.Text = 'Relabel';
            app.RelabelCheckBox.Position = [588 531 74 22];

            % Create CHealSpoutOcclusionsButton
            app.CHealSpoutOcclusionsButton = uibutton(app.UIFigure, 'push');
            app.CHealSpoutOcclusionsButton.ButtonPushedFcn = createCallbackFcn(app, @CHealSpoutOcclusionsButtonPushed, true);
            app.CHealSpoutOcclusionsButton.Tooltip = {'Go through masks and attempt to '};
            app.CHealSpoutOcclusionsButton.Position = [669 449 268 23];
            app.CHealSpoutOcclusionsButton.Text = 'C. Heal Spout Occlusions';

            % Create C2OcclusioneditorButton
            app.C2OcclusioneditorButton = uibutton(app.UIFigure, 'push');
            app.C2OcclusioneditorButton.ButtonPushedFcn = createCallbackFcn(app, @C2OcclusioneditorButtonPushed, true);
            app.C2OcclusioneditorButton.Position = [669 422 132 23];
            app.C2OcclusioneditorButton.Text = 'C2. Occlusion editor';

            % Create AutorevertoldhealsCheckBox
            app.AutorevertoldhealsCheckBox = uicheckbox(app.UIFigure);
            app.AutorevertoldhealsCheckBox.Tooltip = {'If a session has been healed in the past, automatically revert to the original state before re-healing? If this is unchecked, the process will pause to wait for confirmation before reverting.'};
            app.AutorevertoldhealsCheckBox.Text = 'Auto-revert old heals';
            app.AutorevertoldhealsCheckBox.Position = [807 423 133 22];
            app.AutorevertoldhealsCheckBox.Value = true;

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