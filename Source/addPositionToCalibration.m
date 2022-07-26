function spoutCalibration = addPositionToCalibration(spoutCalibration, command_x, command_y, command_z)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% mapSpoutCommandToPosition: Complete the calibration struct by adding a 
%   mapping from motor command to position.
% usage:  
%   spoutCalibration = addPositionToCalibration(spoutCalibration, 
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

if ~exist('command_z', 'var') || isempty(command_z)
    command_z = 0*command_y;
end
if iscolumn(command_x)
    command_x = command_x';
end
if iscolumn(command_y)
    command_y = command_y';
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
spoutCalibration.cx = unique_actuator_commands(1, :);
spoutCalibration.cy = unique_actuator_commands(2, :);
spoutCalibration.cz = unique_actuator_commands(3, :);

% Trim command and position vectors to same length
numXCalPoints = min([length(spoutCalibration.cx), length(spoutCalibration.x)]);
numYCalPoints = min([length(spoutCalibration.cy), length(spoutCalibration.y)]);
numZCalPoints = min([length(spoutCalibration.cz), length(spoutCalibration.z)]);
spoutCalibration.cx = spoutCalibration.cx(1:numXCalPoints);
spoutCalibration.cy = spoutCalibration.cy(1:numYCalPoints);
spoutCalibration.cz = spoutCalibration.cz(1:numZCalPoints);
spoutCalibration.x = spoutCalibration.x(1:numXCalPoints);
spoutCalibration.y = spoutCalibration.y(1:numYCalPoints);
spoutCalibration.z = spoutCalibration.z(1:numZCalPoints);

% Fit a line to the command/position mapping to get a general mapping
lmx = fitlm(spoutCalibration.cx, spoutCalibration.x);
lmy = fitlm(spoutCalibration.cy, spoutCalibration.y);
lmz = fitlm(spoutCalibration.cz, spoutCalibration.z);

spoutCalibration.x_map = @lmx.predict;
spoutCalibration.y_map = @lmy.predict;
spoutCalibration.z_map = @lmz.predict;
