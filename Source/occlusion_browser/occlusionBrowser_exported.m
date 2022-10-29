classdef occlusionBrowser_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        OpenviewerButton               matlab.ui.control.Button
        SessionVideoDirEditField       matlab.ui.control.EditField
        SessionVideoDirEditFieldLabel  matlab.ui.control.Label
        Button_2                       matlab.ui.control.Button
        LoadsessionButton              matlab.ui.control.Button
        Button                         matlab.ui.control.Button
        SessionMaskDirEditField        matlab.ui.control.EditField
        SessionMaskDirEditFieldLabel   matlab.ui.control.Label
        DeletebothealButton            matlab.ui.control.Button
        ShowimageCheckBox              matlab.ui.control.CheckBox
        ShowmasksCheckBox              matlab.ui.control.CheckBox
        ShowpatchesCheckBox            matlab.ui.control.CheckBox
        OcclusionEditorLabel           matlab.ui.control.Label
        DeletetophealButton            matlab.ui.control.Button
        TrialstatsTextArea             matlab.ui.control.TextArea
        TrialstatsTextAreaLabel        matlab.ui.control.Label
        TrialbrowserListBox            matlab.ui.control.ListBox
        TrialbrowserListBoxLabel       matlab.ui.control.Label
    end

    
    properties (Access = private)
        sessionMaskRoot % root dir for masks
        sessionVideoRoot % root dir for videos
        reports % Description
        paths
        topMasks logical = []           % Loaded top mask data (patched, if a patch was needed)
        botMasks logical = []           % Loaded bottom mask data (patched, if a patch was needed)
        topMasksOriginal logical = []   % Loaded original top mask data (empty if no patch was needed)
        botMasksOriginal logical = []   % Loaded original bottom mask data (empty if no patch was needed)
        topPatchMasks logical = []         % A mask stack consisting only of the top patch itself.
        botPatchMasks logical = []         % A mask stack consisting only of the bot patch itself.
        rawVideoData
        maskedVideoData                 % Video data with masks overlayed (patched, if a patch was needed)
        maskedOriginalVideoData         % Video data with masks overlayed (unpatched, empty if no patch was needed)
        cueFrame
        image
        updating = false
        frameMarker = matlab.graphics.primitive.Line.empty()
        videoBrowser    VideoBrowser
    end
    
    methods (Access = private)
        
        function sessionMaskRoot = getSessionMaskRoot(app)
            sessionMaskRoot = strtrim(app.SessionMaskDirEditField.Value);
        end
        function sessionVideoRoot = getSessionVideoRoot(app)
            sessionVideoRoot = strtrim(app.SessionVideoDirEditField.Value);
        end
        function setSessionMaskRoot(app, sessionMaskRoot)
            app.SessionMaskDirEditField.Value = sessionMaskRoot;
        end
        function setSessionVideoRoot(app, sessionVideoRoot)
            app.SessionVideoDirEditField.Value = sessionVideoRoot;
        end
        function trialNum = getCurrentTrialNumber(app)
            trialNum = app.TrialbrowserListBox.Value;
        end
        function setCurrentTrialNumber(app, trialNum)
            app.TrialbrowserListBox = trialNum;
        end
        function reports = loadReports(app, occlusionRoot)
            % Load all reports into an unordered array
            reportPaths = findFilesByRegex(occlusionRoot, '(Bot|Top)_[0-9]{3}_occ-report-[0-9]{4}\.mat');
            for k = 1:length(reportPaths)
%                 t = regexp(reportPaths{k}, '_([0-9]{3})_', 'tokens');
%                 trialNum = t{1}{1};
%                 trialIdx = trialNum + 1;
                S = load(reportPaths{k});
                reports(k) = S.report;
%                 reports(trialIdx) = S.report;
            end
        end
        function reports = loadOcclusionReports(app, occlusionRoot)
            % Load all occlusion reports from this occlusion root directory
            % Returns a struct containing all reports
            
            reports = [];

            allReports = app.loadReports(occlusionRoot);
            
            for k = 1:length(allReports)
                report = allReports(k);
                if isempty(report.view)
                    continue;
                end
                trialNum = report.trial_num;
                trialIdx = report.trial_idx;  % trialNum is zero-indexed, trialIdx is one-indexed
                view = report.view;
                timestamp = report.heal_timestamp;
                if length(reports) >= trialIdx
                    if ~isempty(reports(trialIdx)) && isfield(reports(trialIdx), view) && ~isempty(reports(trialIdx).(view))
                        % Uh oh, we've already processed a report for this
                        % view/trialNum. Must be duplicates
                        warning('Found duplicate occlusion report: trial %d %s view. Using most recent report', trialNum, view);
                        if timestamp < reports(trialIdx).(view).heal_timestamp
                            % This is an older report - skip it.
                            continue;
                        end
                    end
                end
                fprintf('Found report: trial %d, view %s\n', trialNum, view);
                reports(trialIdx).(view) = report;
            end
        end
        function occlusionReportRoot = getOcclusionReportRoot(app)
            maskRoot = app.getSessionMaskRoot();
            [occlusionReportRoot, ~] = getOcclusionsDirs(maskRoot);
        end
        function occlusionOriginalRoot = getOcclusionOriginalRoot(app)
            maskRoot = app.getSessionMaskRoot();
            [~, occlusionOriginalRoot] = getOcclusionsDirs(maskRoot);
        end
        function updateStats(app, trialNum)
            if ~exist('trialNum', 'var')
                trialNum = app.getCurrentTrialNumber();
            end
            trialIdx = trialNum + 1;
            views = {'Top', 'Bot'};
            statsText = '';
            if trialIdx > length(app.reports)
                statsText = 'No reports for this trial.';
            else
                for k = 1:length(views)
                    view = views{k};
                    if ~isfield(app.reports(trialIdx), view) || isempty(app.reports(trialIdx).(view))
                        reportText = sprintf('View: %s\n   No report for this view.', view);
                    else
                        report = app.reports(trialIdx).(view);
                        reportPattern = ['', ...
                            'View: %s\n', ...
                            '   Timestamp:           %s\n', ...
                            '   # of patched frames: %d / %d\n', ...
                            '\n', ...
                            ];
                        reportText = sprintf(reportPattern, report.view, datestr(report.heal_timestamp), report.num_patched, length(report.data));
                    end
                    statsText = [statsText, reportText];
                end
            end
            app.TrialstatsTextArea.Value = statsText;
        end
        function loadMasks(app, trialNum)
            if ~exist('trialNum', 'var')
                trialNum = app.getCurrentTrialNumber();
            end
            trialIdx = trialNum + 1;
            if ~isempty(app.paths(trialIdx).topMask)
                s = load(app.paths(trialIdx).topMask);
                app.topMasks = s.mask_pred(app.cueFrame:end, :, :);
            else
                app.topMasks = [];
            end
            if ~isempty(app.paths(trialIdx).botMask)
                s = load(app.paths(trialIdx).botMask);
                app.botMasks = s.mask_pred(app.cueFrame:end, :, :);
            else
                app.botMasks = [];
            end
            if ~isempty(app.paths(trialIdx).topMaskOriginal)
                s = load(app.paths(trialIdx).topMaskOriginal);
                app.topMasksOriginal = s.mask_pred(app.cueFrame:end, :, :);
                app.topPatchMasks = app.topMasks & ~app.topMasksOriginal;
            else
                app.topMasksOriginal = [];
                app.topPatchMasks = [];
            end
            if ~isempty(app.paths(trialIdx).botMaskOriginal)
                s = load(app.paths(trialIdx).botMaskOriginal);
                app.botMasksOriginal = s.mask_pred(app.cueFrame:end, :, :);
                app.botPatchMasks = app.botMasks & ~app.botMasksOriginal;
            else
                app.botMasksOriginal = [];
                app.botPatchMasks = [];
            end
                
        end
        function loadVideo(app, trialNum)
            if ~exist('trialNum', 'var')
                trialNum = app.getCurrentTrialNumber();
            end
            trialIdx = trialNum + 1;
            app.rawVideoData = loadVideoData(app.paths(trialIdx).video);
            app.rawVideoData = app.rawVideoData(:, :, app.cueFrame:end);
            app.rawVideoData = permute(app.rawVideoData, [3, 1, 2]);
        end
        function createCompositeVideoData(app)
            hVideo = size(app.rawVideoData, 2);
            hBotMask = size(app.botMasksOriginal, 2);
            if ~isempty(app.rawVideoData) && ~isempty(app.topMasks) && ~isempty(app.botMasks)
                disp('Overlaying patched mask...')
                if ~isempty(app.topMasksOriginal) && ~isempty(app.botMasksOriginal)
                    origin = {[1, 1], [1, hVideo-hBotMask+1], [1, 1], [1, hVideo-hBotMask+1]};
                    color = {[1, 1, 0], [0, 1, 1], [1, 0, 0], [1, 0, 0]};
                    app.maskedVideoData = overlayMask(app.rawVideoData, {app.topMasksOriginal, app.botMasksOriginal, app.topPatchMasks, app.botPatchMasks}, color, 0.8, origin);
                else
                    origin = {[1, 1], [1, hVideo-hBotMask+1]};
                    app.maskedVideoData = overlayMask(app.rawVideoData, {app.topMasks, app.botMasks}, {[1, 1, 0], [0, 1, 1]}, 0.8, origin);
                end
                disp('...done.')
            end
            if ~isempty(app.rawVideoData) && ~isempty(app.topMasksOriginal) && ~isempty(app.botMasksOriginal)
                disp('Overlaying unpatched mask...')
                origin = {[1, 1], [1, hVideo-hBotMask+1]};
                app.maskedOriginalVideoData =   overlayMask(app.rawVideoData, {app.topMasksOriginal, app.botMasksOriginal}, {[1, 1, 0], [0, 1, 1]}, 0.8, origin);
                disp('...done.')
            end
        end
        function loadTrial(app, trialNum)
            if ~exist('trialNum', 'var')
                trialNum = app.getCurrentTrialNumber();
            end
            app.loadMasks(trialNum);
            app.loadVideo(trialNum);
            app.createCompositeVideoData();
            app.createVideoBrowser(trialNum);
            app.updateStats(trialNum);
            app.videoBrowser.CurrentFrameNum = 1;
        end
        function createVideoBrowser(app, trialNum)
            if ~exist('trialNum', 'var')
                trialNum = app.getCurrentTrialNumber();
            end
            trialIdx = trialNum + 1;
            delete(app.videoBrowser);
            if trialIdx <= length(app.reports) && ~isempty(app.reports(trialIdx)) && ~isempty(app.reports(trialIdx).Top)
                patched = [app.reports(trialIdx).Top.data.patch_size] > 0 | [app.reports(trialIdx).Bot.data.patch_size] > 0;    % Used for coloring points
            else
                patched = false;
            end
            if app.ShowpatchesCheckBox.Value && ~isempty(app.maskedOriginalVideoData)
                app.videoBrowser = VideoBrowser(app.maskedOriginalVideoData, 'sum');
            elseif ~isempty(app.maskedVideoData)
                app.videoBrowser = VideoBrowser(app.maskedVideoData, 'sum');
            end
            
            highlight_plot(app.videoBrowser.NavigationAxes, [], patched, [1, 0, 0, 0.5]);

            screenSize = get(0, 'screensize');
            app.videoBrowser.MainFigure.Position(1) = (app.UIFigure.Position(1) + app.UIFigure.Position(3)) / screenSize(3);
            app.videoBrowser.MainFigure.Position(2) = app.UIFigure.Position(2) / screenSize(4);
            app.videoBrowser.MainFigure.Position(4) = app.UIFigure.Position(4) / screenSize(4);
        end
        function populateTrialBrowserListBox(app, trialNums)
            trialIdxs = trialNums + 1;
            topPatched = false(size(trialNums));
            botPatched = false(size(trialNums));
            
            itemLabels = cell(1, length(trialNums));

            for trialIdx = trialIdxs
                if trialIdx <= length(app.reports) && ~isempty(app.reports(trialIdx).Top)
                    topPatched(trialIdx) = (app.reports(trialIdx).Top.num_patched > 0);
                    botPatched(trialIdx) = (app.reports(trialIdx).Bot.num_patched > 0);
                else
                    topPatched(trialIdx) = false;
                    botPatched(trialIdx) = false;
                end
                trialNum = trialIdx - 1;
                if topPatched(trialIdx) || botPatched(trialIdx)
                    itemLabels{trialIdx} = sprintf('%03d (%d+%d patched)', trialNum, app.reports(trialIdx).Top.num_patched, app.reports(trialIdx).Bot.num_patched);
                else
                    itemLabels{trialIdx} = sprintf('%03d', trialNum);
                end
            end
            
            app.TrialbrowserListBox.Items =     itemLabels;
            app.TrialbrowserListBox.ItemsData = trialNums;
            app.TrialbrowserListBox.Value = trialNums(1);
        end
        function loadSession(app)
            maskRoot = app.getSessionMaskRoot();
            videoRoot = app.getSessionVideoRoot();
            occlusionReportRoot = app.getOcclusionReportRoot();
            
            % Collect occlusion reports in mask dir into a struct
            app.reports = app.loadOcclusionReports(occlusionReportRoot);
            
            % Get list of videos and masks in session
            videoPaths = findFilesByRegex(videoRoot, '.*\.avi$');
            topMasksPaths = findFilesByRegex(maskRoot, 'Top_[0-9]*\.mat$');
            botMasksPaths = findFilesByRegex(maskRoot, 'Bot_[0-9]*\.mat$');
            
            topTrialNums = cellfun(@(t)str2double(t{1}), regexp(topMasksPaths, 'Top_([0-9]+)', 'tokens'));
            botTrialNums = cellfun(@(t)str2double(t{1}), regexp(botMasksPaths, 'Bot_([0-9]+)', 'tokens'));
            trialNums = union(topTrialNums, botTrialNums);
            for trialNum = trialNums
                trialIdx = trialNum + 1;
                topMaskPath = fullfile(maskRoot, sprintf('Top_%03d.mat', trialNum));
                botMaskPath = fullfile(maskRoot, sprintf('Bot_%03d.mat', trialNum));
                if trialIdx <= length(app.reports) && ~isempty(app.reports(trialIdx))
                    app.paths(trialIdx).topMaskOriginal = app.reports(trialIdx).Top.unmodified_mask_path;
                    app.paths(trialIdx).botMaskOriginal = app.reports(trialIdx).Bot.unmodified_mask_path;
                else
                    app.paths(trialIdx).topMaskOriginal = '';
                    app.paths(trialIdx).botMaskOriginal = '';
                end
                app.paths(trialIdx).topMask = topMaskPath;
                app.paths(trialIdx).botMask = botMaskPath;
                app.paths(trialIdx).video = videoPaths{trialIdx};
            end
            
            app.populateTrialBrowserListBox(trialNums);
            
            trialNum = app.getCurrentTrialNumber();
            app.loadTrial(trialNum);

%             app.stats.trial_nums = reshape(repmat(1:length(videos), [framesPerTrial, 1]), [1, length(videos)*framesPerTrial]);
%             app.stats.frame_nums = repmat(1:framesPerTrial, [1, length(videos)]);
%             app.stats.bot_patch_sizes = zeros([1, framesPerTrial*length(videos)]);
%             app.stats.top_patch_sizes = zeros([1, framesPerTrial*length(videos)]);
%             app.stats.bot_tongue_sizes = zeros([1, framesPerTrial*length(videos)]);
%             app.stats.top_tongue_sizes = zeros([1, framesPerTrial*length(videos)]);

        end

    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, sessionMaskRoot, sessionVideoRoot)
            app.updating = false;
            if exist('sessionMaskRoot', 'var')
                app.setSessionMaskRoot(sessionMaskRoot);
            end
            if exist('sessionVideoRoot', 'var')
                app.setSessionVideoRoot(sessionVideoRoot);
            end
            app.UIFigure.BusyAction = 'cancel';
            app.cueFrame = 1001;
            
            if ~isempty(app.getSessionMaskRoot()) && ~isempty(app.getSessionVideoRoot())
                app.loadSession();
            end
        

        end

        % Value changed function: TrialbrowserListBox
        function TrialbrowserListBoxValueChanged(app, event)
%             value = app.TrialbrowserListBox.Value;
            app.loadTrial()
        end

        % Button pushed function: LoadsessionButton
        function LoadsessionButtonPushed(app, event)
            app.loadSession();
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            delete(app.videoBrowser)
            delete(app)
            
        end

        % Button pushed function: OpenviewerButton
        function OpenviewerButtonPushed(app, event)
            app.createVideoBrowser()
        end

        % Value changed function: ShowpatchesCheckBox
        function ShowpatchesCheckBoxValueChanged(app, event)
            value = app.ShowpatchesCheckBox.Value;
            app.createVideoBrowser();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 517 495];
            app.UIFigure.Name = 'UI Figure';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create TrialbrowserListBoxLabel
            app.TrialbrowserListBoxLabel = uilabel(app.UIFigure);
            app.TrialbrowserListBoxLabel.HorizontalAlignment = 'right';
            app.TrialbrowserListBoxLabel.Position = [20 348 75 22];
            app.TrialbrowserListBoxLabel.Text = 'Trial browser';

            % Create TrialbrowserListBox
            app.TrialbrowserListBox = uilistbox(app.UIFigure);
            app.TrialbrowserListBox.Items = {};
            app.TrialbrowserListBox.ValueChangedFcn = createCallbackFcn(app, @TrialbrowserListBoxValueChanged, true);
            app.TrialbrowserListBox.Position = [20 21 178 328];
            app.TrialbrowserListBox.Value = {};

            % Create TrialstatsTextAreaLabel
            app.TrialstatsTextAreaLabel = uilabel(app.UIFigure);
            app.TrialstatsTextAreaLabel.HorizontalAlignment = 'right';
            app.TrialstatsTextAreaLabel.Position = [224 237 57 22];
            app.TrialstatsTextAreaLabel.Text = 'Trial stats';

            % Create TrialstatsTextArea
            app.TrialstatsTextArea = uitextarea(app.UIFigure);
            app.TrialstatsTextArea.Editable = 'off';
            app.TrialstatsTextArea.Position = [224 21 277 218];

            % Create DeletetophealButton
            app.DeletetophealButton = uibutton(app.UIFigure, 'push');
            app.DeletetophealButton.Position = [351 324 134 22];
            app.DeletetophealButton.Text = 'Delete top heal';

            % Create OcclusionEditorLabel
            app.OcclusionEditorLabel = uilabel(app.UIFigure);
            app.OcclusionEditorLabel.FontSize = 18;
            app.OcclusionEditorLabel.Position = [199 464 136 22];
            app.OcclusionEditorLabel.Text = 'Occlusion Editor';

            % Create ShowpatchesCheckBox
            app.ShowpatchesCheckBox = uicheckbox(app.UIFigure);
            app.ShowpatchesCheckBox.ValueChangedFcn = createCallbackFcn(app, @ShowpatchesCheckBoxValueChanged, true);
            app.ShowpatchesCheckBox.Text = 'Show patches';
            app.ShowpatchesCheckBox.Position = [224 324 111 22];

            % Create ShowmasksCheckBox
            app.ShowmasksCheckBox = uicheckbox(app.UIFigure);
            app.ShowmasksCheckBox.Text = 'Show masks';
            app.ShowmasksCheckBox.Position = [224 297 111 22];

            % Create ShowimageCheckBox
            app.ShowimageCheckBox = uicheckbox(app.UIFigure);
            app.ShowimageCheckBox.Text = 'Show image';
            app.ShowimageCheckBox.Position = [224 271 111 22];

            % Create DeletebothealButton
            app.DeletebothealButton = uibutton(app.UIFigure, 'push');
            app.DeletebothealButton.Position = [350 297 134 22];
            app.DeletebothealButton.Text = 'Delete bot heal';

            % Create SessionMaskDirEditFieldLabel
            app.SessionMaskDirEditFieldLabel = uilabel(app.UIFigure);
            app.SessionMaskDirEditFieldLabel.HorizontalAlignment = 'right';
            app.SessionMaskDirEditFieldLabel.Position = [20 428 99 22];
            app.SessionMaskDirEditFieldLabel.Text = 'Session Mask Dir';

            % Create SessionMaskDirEditField
            app.SessionMaskDirEditField = uieditfield(app.UIFigure, 'text');
            app.SessionMaskDirEditField.Position = [128 428 240 22];

            % Create Button
            app.Button = uibutton(app.UIFigure, 'push');
            app.Button.Position = [379 428 25 22];
            app.Button.Text = '📂';

            % Create LoadsessionButton
            app.LoadsessionButton = uibutton(app.UIFigure, 'push');
            app.LoadsessionButton.ButtonPushedFcn = createCallbackFcn(app, @LoadsessionButtonPushed, true);
            app.LoadsessionButton.Position = [129 367 275 22];
            app.LoadsessionButton.Text = 'Load session';

            % Create Button_2
            app.Button_2 = uibutton(app.UIFigure, 'push');
            app.Button_2.Position = [379 397 25 22];
            app.Button_2.Text = '📂';

            % Create SessionVideoDirEditFieldLabel
            app.SessionVideoDirEditFieldLabel = uilabel(app.UIFigure);
            app.SessionVideoDirEditFieldLabel.HorizontalAlignment = 'right';
            app.SessionVideoDirEditFieldLabel.Position = [20 397 100 22];
            app.SessionVideoDirEditFieldLabel.Text = 'Session Video Dir';

            % Create SessionVideoDirEditField
            app.SessionVideoDirEditField = uieditfield(app.UIFigure, 'text');
            app.SessionVideoDirEditField.Position = [128 397 240 22];

            % Create OpenviewerButton
            app.OpenviewerButton = uibutton(app.UIFigure, 'push');
            app.OpenviewerButton.ButtonPushedFcn = createCallbackFcn(app, @OpenviewerButtonPushed, true);
            app.OpenviewerButton.Position = [350.5 271 134 22];
            app.OpenviewerButton.Text = 'Open viewer';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = occlusionBrowser_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

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