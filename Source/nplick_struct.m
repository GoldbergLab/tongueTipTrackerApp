function [nl_struct,raster_struct, result] = nplick_struct(dirlist_root, varargin)
    % Result is either a logical true if the process completed successfully or a char array describing the error
    result = true;

    if nargin < 2
        plotOutput = false;
    else
        plotOutput = varargin{1};
    end

    try
        dirlist = rdir(strcat(dirlist_root,'\comb\*.mat'));
    catch e
        result = ['nplick_struct could''nt find combined/converted files in ', dirlist_root, '. Make sure you combine/convert FPGA files first using ppscript'];
    end

    % Loop over combined dat files (typically 5000 ms FPGA data chunks)
    for chunk_num=1:numel(dirlist)     
       load(dirlist(chunk_num).name,'working_buff','start_frame','real_time');
              
       y = [medfilt1(working_buff(:,5),3)];
       
       nl_struct(chunk_num).start_frame = start_frame;
       nl_struct(chunk_num).np_pairs = sensor_on_off_times(working_buff(:,2));
       nl_struct(chunk_num).dispense = sensor_on_off_times(working_buff(:,3));
       nl_struct(chunk_num).laser_on = sensor_on_off_times(working_buff(:,4));  % 'laser_on' is a N x 2 array, representing pairs of laser on and off times within this data chunk
       nl_struct(chunk_num).lick_pairs = sensor_on_off_times(y);
       nl_struct(chunk_num).rw_live = sensor_on_off_times(working_buff(:,6));
       nl_struct(chunk_num).real_time = real_time;
       
       temperature = working_buff(:,1);
       
       try
           % Find rw_live on/off times, and store them in nl_struct.rw_cue
           %    such that nl_struct(k).rw_cue(j, 1) is the start time of 
           %    the jth cue within the kth combined data chunk file
           nl_struct(chunk_num).rw_cue = sensor_on_off_times(working_buff(:,7));
           if numel(nl_struct(chunk_num).rw_cue)>0
               rw_cue_onsets  = nl_struct(chunk_num).rw_cue(:,1);
               rw_cue_offsets = nl_struct(chunk_num).rw_cue(:,2);
               % Loop over cues within this combined data chunk file
               for cue_num = 1:numel(rw_cue_onsets)
                   rw_cue_onset = rw_cue_onsets(cue_num);
                   rw_cue_offset = rw_cue_offsets(cue_num);
                   %% Determine if Rw_Cue has a Laser On within 5 ms of cue
                   try
                       if sum(abs(nl_struct(chunk_num).laser_on(:,1) - rw_cue_onset)<5)>0
                           nl_struct(chunk_num).laser_cue(cue_num) = 1;
                       else
                           nl_struct(chunk_num).laser_cue(cue_num) = 0;
                       end
                   catch
                       nl_struct(chunk_num).laser_cue(cue_num) = 0;
                   end
                   %% Determine if Rw_Cue has a Laser On any time during rw_live period
                   % Loop over laser on times found in this combined data chunk
                   nl_struct(chunk_num).laser_post_cue(cue_num, :) = [NaN, NaN];
                   for laser_num = 1:size(nl_struct(chunk_num).laser_on, 1)
                       laser_on_time =  nl_struct(chunk_num).laser_on(laser_num,1);
                       laser_off_time = nl_struct(chunk_num).laser_on(laser_num,2);
                       % Check if a laser on falls between cue onset & offset
                       found_laser_on_post_cue = rw_cue_onset <= laser_on_time && laser_on_time <= rw_cue_offset;
                       % Check if a laser off falls between cue onset & offset
                       found_laser_off_post_cue = rw_cue_onset <= laser_off_time && laser_on_time <= rw_cue_offset;
                       % Check the laser on and off completely encompass a cue onset
                       found_cue_in_laser = laser_on_time < rw_cue_onset && rw_cue_onset < laser_off_time;
                       laser_post_cue = found_laser_on_post_cue || found_laser_off_post_cue || found_cue_in_laser;
                       if laser_post_cue
                           % Found a laser on/off pair that falls within
                           % the rw_live period. Log it.
                           nl_struct(chunk_num).laser_post_cue(cue_num, :) = [laser_on_time, laser_off_time] - rw_cue_onset;
                           break;
                       end
                   end
               %% Determine Temperature within the Rw_Cue
               try
                   nl_struct(chunk_num).temp(cue_num) = mean(temperature(rw_cue_onset:(rw_cue_onset+1300)));
               catch
                   temp_error=1;
               end
               end                   
           end        
       catch ME
           getReport(ME)
       end       
    end
save(strcat(dirlist_root,'\nl_struct.mat'),'nl_struct');
    
% raster_struct = 1;
       [rw_lick_onset,laser_index,ind_difflow,ili,iri,dispense_onset] = raster_lick(nl_struct,plotOutput);
       
       raster_struct.rw_lick = rw_lick_onset;
       raster_struct.laser_index = laser_index;
       raster_struct.ind_difflow = ind_difflow;
       raster_struct.ili = ili;
       
       rw_lick_nl = rw_lick_onset(laser_index==0);
       rw_dispense_nl = dispense_onset(laser_index==0);
       
       for cue_num=1:length(rw_lick_nl)
           if sum(rw_lick_nl{cue_num}>0 & rw_lick_nl{cue_num}<1300)>0
                rw_lick_resp(cue_num) = 1;
           else
                rw_lick_resp(cue_num) = 0;
           end                      
       end
       
       for cue_num=1:length(rw_dispense_nl)
           if sum(rw_dispense_nl{cue_num}>0)>0
               disp_resp(cue_num) = 1;
           else
               disp_resp(cue_num) = 0;
           end                      
       end
       
       raster_struct.rw_lick_resp = rw_lick_resp;
       
       raster_struct.iri = iri;
       raster_struct.iri_with_resp = iri(rw_lick_resp == 1);
       if plotOutput
           figure;plot(1:numel(raster_struct.iri_with_resp),raster_struct.iri_with_resp/1000,'bx');
           ylim([-2 15]);

           y = filtfilt(ones(1,1)/1,1,rw_lick_resp);
           figure;plot(y)
           ylim([0 1.2]);
           title('Lick Response to cue');
           xlabel('Trial Number');
           ylabel('Responded');

           y1 = filtfilt(ones(5,1)/5,1,disp_resp);
           figure;plot(y1)
           ylim([0 1.2]);
           title('Rewarded on Cue');

           c = raster_struct.laser_index;
           d(c==0)=1;
           figure;plot(cumsum(d));
           ylabel('Control Trials');
           xlabel('Total Trials');
       end

       lick_struct = make_rw_struct(nl_struct);
       
save(strcat(dirlist_root,'\raster_struct.mat'),'raster_struct');
save(strcat(dirlist_root,'\lick_struct.mat'),'lick_struct');
   