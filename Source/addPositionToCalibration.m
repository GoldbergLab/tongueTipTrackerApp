function [spout_calibration, command_x, command_y, command_z] = addPositionToCalibration(spout_calibration, command_x, command_y, command_z)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% mapSpoutCommandToPosition: Complete the calibration struct by adding a 
%   mapping from motor command to position.
% usage:  
%   spout_calibration = addPositionToCalibration(spout_calibration, 
%                                               command_x, command_y, 
%                                               command_z)
%
% where,
%    command_x is a list of x motor command values in Volts, in the order
%       they appeared in the session.
%    command_y is a list of y motor command values in Volts, in the order
%       they appeared in the session.
%    command_z is an optional list of motor command values in Volts, in the
%       order they appeared in the session. If not provided, this is set to
%       zero.
%    spout_calibration is a structure containing a mapping between motor
%       command space and video pixel space. It should have the following
%       structure:
%       spout_calibration
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
% This function takes a list of motor commands from one or more trials, and
%   matches them with positions in the calibration struct, relying on the 
%   order of the commands being the same as the order of the positions.
%   The result is the addition of mapping functions in the calibration
%   struct.
%
% See also: mapSpoutCommandToPosition
%
% Version: <version>
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if iscolumn(command_x)
    command_x = command_x';
end
if iscolumn(command_y)
    command_y = command_y';
end
if ~exist('command_z', 'var') || isempty(command_z)
    % Create a fake command_z vector proportional to the spout_calibration.z
    %   positions recorded by first creating a mapping function that
    %   generates a fake command_z vector from command_x and command_y
    %   vectors.
    spout_calibration = add_xy_to_z_command_map(spout_calibration, command_x, command_y);

    command_z = spout_calibration.map_xy_to_z_command(command_x, command_y);
end
if iscolumn(command_z)
    command_z = command_z';
end

% Remove NaN (NaN is placeholder for non-first-lick command vectors)
all_command = [command_x; command_y; command_z];
notNans = ~isnan(command_x);
all_command = all_command(:, notNans);
% Get unique command vectors, preserving order they were in during
% session. This should ensure "home" position command is 1st, followed
% by whichever target position command came first in the session, then
% any subsequent target position commands in order.
unique_actuator_commands = unique(all_command', 'row', 'stable')';
spout_calibration.cx = unique_actuator_commands(1, :);
spout_calibration.cy = unique_actuator_commands(2, :);
spout_calibration.cz = unique_actuator_commands(3, :);

% Trim command and position vectors to same length
numXCalPoints = min([length(spout_calibration.cx), length(spout_calibration.x)]);
numYCalPoints = min([length(spout_calibration.cy), length(spout_calibration.y)]);
numZCalPoints = min([length(spout_calibration.cz), length(spout_calibration.z)]);
spout_calibration.cx = spout_calibration.cx(1:numXCalPoints);
spout_calibration.cy = spout_calibration.cy(1:numYCalPoints);
spout_calibration.cz = spout_calibration.cz(1:numZCalPoints);
spout_calibration.x = spout_calibration.x(1:numXCalPoints);
spout_calibration.y = spout_calibration.y(1:numYCalPoints);
spout_calibration.z = spout_calibration.z(1:numZCalPoints);

% Fit a line to the command/position mapping to get a general mapping
lmx = fitlm(spout_calibration.cx, spout_calibration.x);
lmy = fitlm(spout_calibration.cy, spout_calibration.y);
lmz = fitlm(spout_calibration.cz, spout_calibration.z);

spout_calibration.x_map = @lmx.predict;
spout_calibration.y_map = @lmy.predict;
spout_calibration.z_map = @lmz.predict;
