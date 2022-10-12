function t_stats = mapSpoutCommandToPosition(t_stats, spoutCalibration)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% mapSpoutCommandToPosition: Map the spout motor commands to a pixel
%   position in video.c
% usage:  t_stats = mapSpoutCommandToPosition(t_stats, spoutCalibration)
%
% where,
%    t_stats is a t_stats file that has already been aligned to FPGA data.
%    spoutCalibration is a structure containing a mapping between motor
%       command space and video pixel space. It should have the following
%       structure:
%       spoutCalibration
%           .x(1)  = <x pixel coordinate for spout in initial position>
%           .x(2)  = <x pixel coordinate for spout in next position>
%               ...
%           .x(N)  = <x pixel coordinate for spout in Nth position>
%           .y(1)  = <y pixel coordinate for spout in initial position>
%           .y(2)  = <y pixel coordinate for spout in next position>
%               ...
%           .y(N)  = <y pixel coordinate for spout in Nth position>
%           .z(1)  = <z pixel coordinate for spout in initial position>
%           .z(2)  = <z pixel coordinate for spout in next position>
%               ...
%           .z(N)  = <z pixel coordinate for spout in Nth position>
%           .speed = <speed of motor in pixels / ms in bottom mask>
%           .latency = <latency from motor command to movement initiation in ms>
%
%   The following fields get added in this function:
%           .cx(1) = <x command value for spout in initial position>
%           .cx(2) = <x command value for spout in next position>
%               ...
%           .cx(N) = <x command value for spout in Nth position>
%           .cy(1) = <y command value for spout in initial position>
%           .cy(2) = <y command value for spout in next position>
%               ...
%           .cy(N) = <y command value for spout in Nth position>
%           .cz(1) = <z command value for spout in initial position>
%           .cz(2) = <z command value for spout in next position>
%               ...
%           .cz(N) = <z command value for spout in Nth position>
%           .x_map = function that takes an x command and outputs the
%                       corresponding x position
%           .y_map = function that takes an y command and outputs the
%                       corresponding y position
%           .z_map = function that takes an z command and outputs the
%                       corresponding z position
%
% This function takes a t_stats struct that has already been aligned and
%   combined with FPGA data, and adds in the spout position calculated 
%   based on the spout motor commands and a calibration mapping between 
%   spout motor command and spout position.
%
% See also: 
%
% Version: <version>
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Build vector of all commands in t_stats file
all_command_x = horzcat(t_stats.actuator_command_x);
all_command_y = horzcat(t_stats.actuator_command_y);

% Add command==>position mappings to spoutCalibration struct
spoutCalibration = addPositionToCalibration(spoutCalibration, all_command_x, all_command_y);

for lickNum = 1:length(t_stats)
    command_x = t_stats(lickNum).actuator_command_x;
    command_y = t_stats(lickNum).actuator_command_y;
    % Create fake z-command vector
    command_z = spout_calibration.map_xy_to_z_command(command_x, command_y);
    if ~isempty(command_x) && ~isempty(command_y) && ~isempty(command_z) && ~isnan(command_x(1)) && ~isnan(command_y(1)) && ~isnan(command_z(1))
        % This must be lick #1, where the entire trial's actuator command
        % vector is stored.
        
        % Map command to position
        t_stats(lickNum).spout_position_x = spoutCalibration.x_map(command_x')';
        t_stats(lickNum).spout_position_y = spoutCalibration.y_map(command_y')';
        t_stats(lickNum).spout_position_z = spoutCalibration.z_map(command_z')';
        % Interpolate position where there are sudden jumps.
        t_stats(lickNum).spout_position_x = inferSpoutPosition(t_stats(lickNum).spout_position_x, spoutCalibration.speed, spoutCalibration.latency);
        t_stats(lickNum).spout_position_y = inferSpoutPosition(t_stats(lickNum).spout_position_y, spoutCalibration.speed, spoutCalibration.latency);
        t_stats(lickNum).spout_position_z = inferSpoutPosition(t_stats(lickNum).spout_position_z, spoutCalibration.speed, spoutCalibration.latency);
    else
        t_stats(lickNum).spout_position_x = NaN;
        t_stats(lickNum).spout_position_y = NaN;
        t_stats(lickNum).spout_position_z = NaN;
    end
end