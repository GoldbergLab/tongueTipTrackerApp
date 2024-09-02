function t_stats = assign_fakeout_type_1D(t_stats, l_sp_struct, vid_indices)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% assign_fakeout_type_1D: assign the "spout fakeout type" to t_stats rwos
% usage:  [t_stats] = assign_fakeout_type_1D(t_stats, l_sp_struct, 
%                       vid_indices)
%
% where,
%    t_stats is a t_stats structure, such as that produced by make_t_struct
%    l_sp_struct is a lick_struct structure, such as that produced by 
%       nplick_struct_1D, and packaged in the t_stats file make_t_struct
%    vid_indices is a list of video indices to assign fakeout type to
%    t_stats is the modified t_stats file
%
% This function adds a 'fakeout_trial' field to an existing t_stats
%   structure, indicating what kind of spout movement is present for each
%   trial (repeated for each lick row in the t_stats file).
%
% See also: make_t_struct, nplick_struct_1D, assign_fakeout_type_2D
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize the 'fakeout_trial' field
for trial_num=1:numel(t_stats)
    t_stats(trial_num).fakeout_trial = nan;
end

% Find all unique spout positions
unique_spout_positions = sort(unique([l_sp_struct.actuator1_AP]))';

% Loop over trials in the lick_struct
for trial_num = 1:numel(l_sp_struct)
    vid_trial = find(vid_indices==trial_num);
    
    % If the trial number matches one of the requested video indices ...
    if ~isempty(vid_trial)
        % Get a list of lick indices in this trial number
        lick_indices = find([t_stats.trial_num] == vid_trial);

        % Find which fakeout spout position occurred in this trial
        spout_position_index = find(unique_spout_positions == l_sp_struct(trial_num).actuator1_AP);
        % Assign fakeout spout position value to all corresponding licks
        [t_stats(lick_indices).fakeout_trial] = deal(spout_position_index); %#ok<FNDSB> 
    end
    
end