classdef occlusionBrowser_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        CommitEditsButton              matlab.ui.control.Button
        OpenViewerButton               matlab.ui.control.Button
        SessionVideoDirEditField       matlab.ui.control.EditField
        SessionVideoDirEditFieldLabel  matlab.ui.control.Label
        SessionVideoDirBrowse          matlab.ui.control.Button
        LoadsessionButton              matlab.ui.control.Button
        sessionMaskDirBrowse           matlab.ui.control.Button
        SessionMaskDirEditField        matlab.ui.control.EditField
        SessionMaskDirEditFieldLabel   matlab.ui.control.Label
        RevertselectedpatchesButton    matlab.ui.control.Button
        ShowimageCheckBox              matlab.ui.control.CheckBox
        ShowmasksCheckBox              matlab.ui.control.CheckBox
        ShowpatchesCheckBox            matlab.ui.control.CheckBox
        OcclusionEditorLabel           matlab.ui.control.Label
        DeleteselectedpatchesButton    matlab.ui.control.Button
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
        patchMasks logical = []            % A mask stack consisting of the top and bottom patches together
        rawVideoData
        maskedPatchedVideoData                 % Video data with masks overlayed (patched, if a patch was needed)
        maskedOriginalVideoData         % Video data with masks overlayed (unpatched, empty if no patch was needed)
        cueFrame
        image
        updating = false
        topColor double = [1, 1, 0]
        botColor double = [0, 1, 1]
        frameMarker = matlab.graphics.primitive.Line.empty()
        videoBrowser    VideoPainter
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
        function saveReport(app, trialNum)
            trialIdx = trialNum + 1;
            numChangedFrames = app.getNumChangedFrames();
            app.reports(trialIdx).Top.lastEdit = char(datetime('now'));
            app.reports(trialIdx).Bot.lastEdit = char(datetime('now'));

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
                modifiedPattern = ['', ...
                    '# of edited frames:  %d / %d\n'
                    ];
                numChangedFrames = app.getNumChangedFrames();
                modifiedText = sprintf(modifiedPattern, numChangedFrames, length(report.data));
                statsText = [statsText, modifiedText];
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
                app.topMasks = s.mask_pred; %(app.cueFrame:end, :, :);
            else
                app.topMasks = [];
            end
            if ~isempty(app.paths(trialIdx).botMask)
                s = load(app.paths(trialIdx).botMask);
                app.botMasks = s.mask_pred; %(app.cueFrame:end, :, :);
            else
                app.botMasks = [];
            end
            app.patchMasks = false(size(app.rawVideoData));
            if ~isempty(app.paths(trialIdx).topMaskOriginal)
                s = load(app.paths(trialIdx).topMaskOriginal);
                app.topMasksOriginal = s.mask_pred; %(app.cueFrame:end, :, :);
                app.topPatchMasks = app.topMasks & ~app.topMasksOriginal;
                app.patchMasks(:, 1:size(app.topPatchMasks, 2), :) = app.topPatchMasks;
            else
                app.topMasksOriginal = [];
                app.topPatchMasks = [];
            end
            if ~isempty(app.paths(trialIdx).botMaskOriginal)
                s = load(app.paths(trialIdx).botMaskOriginal);
                app.botMasksOriginal = s.mask_pred; %(app.cueFrame:end, :, :);
                app.botPatchMasks = app.botMasks & ~app.botMasksOriginal;
                y1 = size(app.rawVideoData, 2) - size(app.botPatchMasks, 2) + 1;
                app.patchMasks(:, y1:end, :) = app.botPatchMasks;
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
            %app.rawVideoData = app.rawVideoData(:, :, app.cueFrame:end);
            app.rawVideoData = permute(app.rawVideoData, [3, 1, 2]);
        end
        function createCompositeVideoData(app)
            hVideo = size(app.rawVideoData, 2);
            hBotMask = size(app.botMasksOriginal, 2);
            if ~isempty(app.rawVideoData) && ~isempty(app.topMasksOriginal) && ~isempty(app.botMasksOriginal)
                disp('Overlaying masks...')
                origin = {[1, 1], [1, hVideo-hBotMask+1]};
                app.maskedOriginalVideoData = overlayMask(app.rawVideoData, {app.topMasksOriginal, app.botMasksOriginal}, {app.topColor, app.botColor}, 0.8, origin);
                disp('...done.')
            end
        end
        function loadTrial(app, trialNum)
            if ~exist('trialNum', 'var')
                trialNum = app.getCurrentTrialNumber();
            end
            app.loadVideo(trialNum);
            app.loadMasks(trialNum);
            app.createCompositeVideoData();
            app.createVideoBrowser(trialNum);
            app.updateStats(trialNum);
            app.videoBrowser.CurrentFrameNum = 1;
        end
        function changedFramesMask = getChangeFramesMask(app)
            changedFramesMask = sum(app.videoBrowser.PaintMask ~= app.patchMasks, [2, 3]);
        end
        function numChangedFrames = getNumChangedFrames(app)
            numChangedFrames = sum(app.getChangeFramesMask() > 0);
        end
        function MaskChangeHandler(app)
            trialNum = app.getCurrentTrialNumber();
            app.updateStats(trialNum);
        end
        function createVideoBrowser(app, trialNum)
            if ~exist('trialNum', 'var')
                trialNum = app.getCurrentTrialNumber();
            end
            trialIdx = trialNum + 1;
            delete(app.videoBrowser);
            if ~isempty(app.maskedOriginalVideoData)
                app.videoBrowser = VideoPainter(app.maskedOriginalVideoData, 'sum');
                app.videoBrowser.StrokeEndHandler = @app.MaskChangeHandler;
                app.videoBrowser.PaintMask = app.patchMasks;
                if ~app.ShowpatchesCheckBox.Value
                    % Don't show patches
                    app.videoBrowser.PaintMaskImage.Visible = 'off';
                end
            end

            if trialIdx <= length(app.reports) && ~isempty(app.reports(trialIdx)) && ~isempty(app.reports(trialIdx).Top)
                topPatched = [zeros(1, app.cueFrame), app.reports(trialIdx).Top.data.patch_size] > 0;
                botPatched = [zeros(1, app.cueFrame), app.reports(trialIdx).Bot.data.patch_size] > 0;

                disp('Highlighting:');
                size(topPatched)
                size(app.rawVideoData)

                % Add highlight bars indicating which frames have been patched
                highlight_plot(app.videoBrowser.NavigationAxes, topPatched, [app.topColor, 0.5]);
                highlight_plot(app.videoBrowser.NavigationAxes, botPatched, [app.botColor, 0.5]);
            end


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
        function fullFrameMask = embedViewMask(app, viewMask, viewType)
            hVideo = size(app.rawVideoData, 2);
            fullFrameMask = false(size(app.rawVideoData));
            switch viewType
                case 'Top'
                    hTopMask = size(app.topMasksOriginal, 2);
                    fullFrameMask(:, 1:hTopMask, :) = viewMask;
                case 'Bot'
                    hBotMask = size(app.botMasksOriginal, 2);
                    fullFrameMask(:, (hVideo-hBotMask+1):end, :) = viewMask;
            end
        end
        function [topMask, botMask] = extractViewMasks(app, fullFrameMask)
            hVideo = size(app.rawVideoData, 2);
            hTopMask = size(app.topMasksOriginal, 2);
            hBotMask = size(app.botMasksOriginal, 2);
            topMask = fullFrameMask(:, 1:hTopMask, :);
            botMask = fullFrameMask(:, (hVideo-hBotMask+1):end, :);
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

        % Button pushed function: OpenViewerButton
        function OpenViewerButtonPushed(app, event)
            app.createVideoBrowser()
        end

        % Value changed function: ShowpatchesCheckBox
        function ShowpatchesCheckBoxValueChanged(app, event)
            if app.ShowpatchesCheckBox.Value
                % Show patches, enable patch painting
                app.videoBrowser.PaintEnabled = true;
                app.videoBrowser.PaintMaskImage.Visible = 'on';
            else
                % Hide patches, disable patch painting
                app.videoBrowser.PaintEnabled = false;
                app.videoBrowser.PaintMaskImage.Visible = 'off';
            end
        end

        % Button pushed function: DeleteselectedpatchesButton
        function DeleteselectedpatchesButtonPushed(app, event)
            app.videoBrowser.PaintMask(app.videoBrowser.FrameSelection, :, :) = false;
            app.updateStats();
        end

        % Button pushed function: RevertselectedpatchesButton
        function RevertselectedpatchesButtonPushed(app, event)
            app.videoBrowser.PaintMask(app.videoBrowser.FrameSelection, :, :) = app.patchMasks(app.videoBrowser.FrameSelection, :, :);
            app.updateStats();
        end

        % Button pushed function: CommitEditsButton
        function CommitEditsButtonPushed(app, event)
            trialNum = app.getCurrentTrialNumber();
            trialIdx = trialNum + 1;

            disp('Committing patch edits...');

            % Extract edited top and bot masks from paint mask in
            % VideoPainter
            [app.topPatchMasks, app.botPatchMasks] = app.extractViewMasks(app.videoBrowser.PaintMask);

            % Get path to save to from current trial's report
            top_patched_mask_dir = fileparts(app.reports(trialIdx).Top.patched_mask_path);
            bot_patched_mask_dir = fileparts(app.reports(trialIdx).Bot.patched_mask_path);

            % Save edited masks, overwriting patched masks
            top_healed_masks = app.topMasksOriginal | app.topPatchMasks;
            bot_healed_masks = app.botMasksOriginal | app.botPatchMasks;

            % Get directory where reports and originals are stored
            % Top and bot directories are almost certainly the same, but
            % may as well retrieve them separately anyways.
            [top_occlusion_reports_dir, top_occlusion_originals_dir] = getOcclusionsDirs(top_patched_mask_dir);
            [bot_occlusion_reports_dir, bot_occlusion_originals_dir] = getOcclusionsDirs(bot_patched_mask_dir);

            % Formulate new reports to save
            heal_timestamp = char(datetime('now'));

            % Copy old report data to new report structures
            top_report_data = app.reports(trialIdx).Top.data;
            bot_report_data = app.reports(trialIdx).Bot.data;
            % Calculate updated patch sizes
            top_patch_sizes = num2cell(sum(app.topPatchMasks & ~app.topMasksOriginal, [2, 3]));
            bot_patch_sizes = num2cell(sum(app.botPatchMasks & ~app.botMasksOriginal, [2, 3]));
            % Set report patch_size field to new patch sizes
            [top_report_data.patch_size] = top_patch_sizes{:};
            [bot_report_data.patch_size] = bot_patch_sizes{:};

            % Save report with an edit time notification
            saveOcclusionResults(top_report_data, top_healed_masks, ...
                top_patched_mask_dir, top_occlusion_reports_dir, ...
                top_occlusion_originals_dir, 'Top', heal_timestamp, ...
                app.reports(trialIdx).Top.patched_mask_path, trialIdx, ...
                false);
            saveOcclusionResults(bot_report_data, bot_healed_masks, ...
                bot_patched_mask_dir, bot_occlusion_reports_dir, ...
                bot_occlusion_originals_dir, 'Bot', heal_timestamp, ...
                app.reports(trialIdx).Bot.patched_mask_path, trialIdx, ...
                false);

            disp('Done committing patch edits');

            app.loadMasks(trialNum);
            app.createVideoBrowser(trialNum)

        end

        % Button pushed function: sessionMaskDirBrowse
        function sessionMaskDirBrowseButtonPushed(app, event)
            path = uigetdir([], 'Choose directory to search for mask .mat files');
            if ~isempty(path)
                app.SessionMaskDirEditField.Value = path;
            end
        end

        % Button pushed function: SessionVideoDirBrowse
        function SessionVideoDirBrowseButtonPushed(app, event)
            path = uigetdir([], 'Choose directory to search for video files');
            if ~isempty(path)
                app.SessionVideoDirEditField.Value = path;
            end   
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

            % Create DeleteselectedpatchesButton
            app.DeleteselectedpatchesButton = uibutton(app.UIFigure, 'push');
            app.DeleteselectedpatchesButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteselectedpatchesButtonPushed, true);
            app.DeleteselectedpatchesButton.Tooltip = {'Delete all patches within selected frames in the viewer (left/right click and drag on the navigation axes to select/deselect frames)'};
            app.DeleteselectedpatchesButton.Position = [347 323 144 23];
            app.DeleteselectedpatchesButton.Text = 'Delete selected patches';

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
            app.ShowpatchesCheckBox.Value = true;

            % Create ShowmasksCheckBox
            app.ShowmasksCheckBox = uicheckbox(app.UIFigure);
            app.ShowmasksCheckBox.Text = 'Show masks';
            app.ShowmasksCheckBox.Position = [224 297 111 22];

            % Create ShowimageCheckBox
            app.ShowimageCheckBox = uicheckbox(app.UIFigure);
            app.ShowimageCheckBox.Text = 'Show image';
            app.ShowimageCheckBox.Position = [224 271 111 22];

            % Create RevertselectedpatchesButton
            app.RevertselectedpatchesButton = uibutton(app.UIFigure, 'push');
            app.RevertselectedpatchesButton.ButtonPushedFcn = createCallbackFcn(app, @RevertselectedpatchesButtonPushed, true);
            app.RevertselectedpatchesButton.Tooltip = {'Revert all patches within selected frames in the viewer to saved patches (left/right click and drag on the navigation axes to select/deselect frames)'};
            app.RevertselectedpatchesButton.Position = [347 297 144 23];
            app.RevertselectedpatchesButton.Text = 'Revert selected patches';

            % Create SessionMaskDirEditFieldLabel
            app.SessionMaskDirEditFieldLabel = uilabel(app.UIFigure);
            app.SessionMaskDirEditFieldLabel.HorizontalAlignment = 'right';
            app.SessionMaskDirEditFieldLabel.Position = [20 428 99 22];
            app.SessionMaskDirEditFieldLabel.Text = 'Session Mask Dir';

            % Create SessionMaskDirEditField
            app.SessionMaskDirEditField = uieditfield(app.UIFigure, 'text');
            app.SessionMaskDirEditField.Position = [128 428 240 22];

            % Create sessionMaskDirBrowse
            app.sessionMaskDirBrowse = uibutton(app.UIFigure, 'push');
            app.sessionMaskDirBrowse.ButtonPushedFcn = createCallbackFcn(app, @sessionMaskDirBrowseButtonPushed, true);
            app.sessionMaskDirBrowse.Position = [379 428 25 22];
            app.sessionMaskDirBrowse.Text = '📂';

            % Create LoadsessionButton
            app.LoadsessionButton = uibutton(app.UIFigure, 'push');
            app.LoadsessionButton.ButtonPushedFcn = createCallbackFcn(app, @LoadsessionButtonPushed, true);
            app.LoadsessionButton.Position = [129 367 275 22];
            app.LoadsessionButton.Text = 'Load session';

            % Create SessionVideoDirBrowse
            app.SessionVideoDirBrowse = uibutton(app.UIFigure, 'push');
            app.SessionVideoDirBrowse.ButtonPushedFcn = createCallbackFcn(app, @SessionVideoDirBrowseButtonPushed, true);
            app.SessionVideoDirBrowse.Position = [379 397 25 22];
            app.SessionVideoDirBrowse.Text = '📂';

            % Create SessionVideoDirEditFieldLabel
            app.SessionVideoDirEditFieldLabel = uilabel(app.UIFigure);
            app.SessionVideoDirEditFieldLabel.HorizontalAlignment = 'right';
            app.SessionVideoDirEditFieldLabel.Position = [20 397 100 22];
            app.SessionVideoDirEditFieldLabel.Text = 'Session Video Dir';

            % Create SessionVideoDirEditField
            app.SessionVideoDirEditField = uieditfield(app.UIFigure, 'text');
            app.SessionVideoDirEditField.Position = [128 397 240 22];

            % Create OpenViewerButton
            app.OpenViewerButton = uibutton(app.UIFigure, 'push');
            app.OpenViewerButton.ButtonPushedFcn = createCallbackFcn(app, @OpenViewerButtonPushed, true);
            app.OpenViewerButton.Position = [347 245 144 23];
            app.OpenViewerButton.Text = 'Open viewer';

            % Create CommitEditsButton
            app.CommitEditsButton = uibutton(app.UIFigure, 'push');
            app.CommitEditsButton.ButtonPushedFcn = createCallbackFcn(app, @CommitEditsButtonPushed, true);
            app.CommitEditsButton.Tooltip = {'Save edited patches to file'};
            app.CommitEditsButton.Position = [347 271 144 23];
            app.CommitEditsButton.Text = 'Commit edits';

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