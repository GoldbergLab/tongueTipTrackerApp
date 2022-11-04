classdef LickBrowser < VideoBrowser
    properties (Access = private)
        top_plot                matlab.graphics.chart.primitive.Line
        bot_plot                matlab.graphics.chart.primitive.Line
        top_marker              matlab.graphics.chart.primitive.Scatter
        bot_marker              matlab.graphics.chart.primitive.Scatter
        cue_time                double = 1001         
    end
    properties
        t_stats                 struct                               % t_stats rows
        top_mask                logical
        bot_mask                logical
    end
    methods
        function obj = LickBrowser(mask_dir, video_dir, trial_num)
            disp('Loading video...')
            video_paths = findFilesByRegex(video_dir, '.*\.avi', false, false);
            video_path = video_paths{trial_num};
            [~, video_name, ~] = fileparts(video_path);
            videoData = permute(loadVideoData(video_path), [3, 1, 2]);
            disp('...done');

            disp('Loading masks...')
            top_mask_filename = sprintf('Top_%03d.mat', trial_num-1);
            bot_mask_filename = sprintf('Bot_%03d.mat', trial_num-1);
            top_mask_path = fullfile(mask_dir, top_mask_filename);
            bot_mask_path = fullfile(mask_dir, bot_mask_filename);

            s = load(top_mask_path);
            top_mask = s.mask_pred;
            s = load(bot_mask_path);
            bot_mask = s.mask_pred;

            combined_mask = false(size(videoData));
            combined_mask(:, 1:size(top_mask, 2), :) = top_mask;
            combined_mask(:, size(videoData, 2) - size(bot_mask, 2) + 1:end, :) = bot_mask;
            disp('...done');

            disp('Overlaying masks...');
            videoData = overlayMask(videoData, combined_mask, [1, 0, 0], 0.8);
            disp('...done');

            title = sprintf('%s Trial #%d', video_name, trial_num);

            obj@VideoBrowser(videoData, 'sum', [], [], title);

            obj.VideoAxes.Title.Interpreter = 'none';

            obj.top_mask = top_mask;
            obj.bot_mask = bot_mask;

            t_stats_path = fullfile(mask_dir, 't_stats.mat');
            s = load(t_stats_path);
            obj.t_stats = s.t_stats([s.t_stats.trial_num] == trial_num);
            obj.updateVideoFrame();
        end
        function createDisplayArea(obj)
            createDisplayArea@VideoBrowser(obj);
            obj.MainFigure.Name = 'Lick Browser';
        end
        function updateVideoFrame(obj)
            updateVideoFrame@VideoBrowser(obj);

            if isempty(obj.t_stats)
                return;
            end

            [lick_idx, lick_time] = obj.getCurrentLick();
            
            if isnan(lick_idx)
                delete(obj.top_plot);
                delete(obj.bot_plot);
                delete(obj.top_marker);
                delete(obj.bot_marker);
            else
                top_x = obj.t_stats(lick_idx).tip_y;
                top_y = (size(obj.top_mask, 2) + 1) - obj.t_stats(lick_idx).tip_z;
                bot_x = obj.t_stats(lick_idx).tip_y;
                bot_y = (size(obj.VideoData, 2) - size(obj.bot_mask, 2)) + obj.t_stats(lick_idx).tip_x;

                if isempty(obj.top_plot) || ~isvalid(obj.top_plot) || isempty(obj.bot_plot) || ~isvalid(obj.bot_plot)
                    hold_val = ishold(obj.VideoAxes);
                    hold(obj.VideoAxes, 'on');
                    obj.top_plot = plot(obj.VideoAxes, top_x, top_y, 'b');
                    obj.bot_plot = plot(obj.VideoAxes, bot_x, bot_y, 'g');
                    if hold_val
                        hold(obj.VideoAxes, 'on');
                    else
                        hold(obj.VideoAxes, 'off');
                    end
                else
                    obj.top_plot.XData = top_x;
                    obj.top_plot.YData = top_y;
                    obj.bot_plot.XData = bot_x;
                    obj.bot_plot.YData = bot_y;
                end

                if isempty(obj.top_marker) || ~isvalid(obj.top_marker) || isempty(obj.bot_marker) || ~isvalid(obj.bot_marker)
                    hold_val = ishold(obj.VideoAxes);
                    hold(obj.VideoAxes, 'on');
                    obj.top_marker = scatter(obj.VideoAxes, top_x(lick_time), top_y(lick_time), 'b');
                    obj.bot_marker = scatter(obj.VideoAxes, bot_x(lick_time), bot_y(lick_time), 'g');
                    if hold_val
                        hold(obj.VideoAxes, 'on');
                    else
                        hold(obj.VideoAxes, 'off');
                    end
                else
                    obj.top_marker.XData = top_x(lick_time);
                    obj.top_marker.YData = top_y(lick_time);
                    obj.bot_marker.XData = bot_x(lick_time);
                    obj.bot_marker.YData = bot_y(lick_time);
                end
            end
        end
        function [lick_idx, lick_time] = getCurrentLick(obj)
            frameSinceCue = obj.CurrentFrameNum - obj.cue_time + 1;
            lick_idx = find([obj.t_stats.time_rel_cue] - frameSinceCue < 0, 1, 'last');
            if isempty(lick_idx)
                lick_idx = NaN;
                lick_time = NaN;
                return
            end
            lick_length = numel(obj.t_stats(lick_idx).tip_x);
            if frameSinceCue - obj.t_stats(lick_idx).time_rel_cue >= lick_length 
                % Current frame is after lick end, but before next lick
                % start
                lick_idx = NaN;
                lick_time = NaN;
                return
            end
            lick_time = frameSinceCue - obj.t_stats(lick_idx).time_rel_cue + 1;
        end
        function KeyPressHandler(obj, src, evt)
            KeyPressHandler@VideoBrowser(obj, src, evt);
        end
        function MouseMotionHandler(obj, src, evt)
            MouseMotionHandler@VideoBrowser(obj, src, evt);
        end
        function MouseDownHandler(obj, src, evt)
            MouseDownHandler@VideoBrowser(obj, src, evt)
        end
        function MouseUpHandler(obj, src, evt)
            MouseUpHandler@VideoBrowser(obj, src, evt)
        end
    end
end