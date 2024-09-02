function spout_calibration = add_y_to_xz_command_map(spout_calibration, command_y)

% Create a fake command_x and command_z vector proportional to the spout_calibration.x and .z
%   positions recorded
unique_command_y = unique(command_y', 'rows', 'stable');
% For each y command, swap out the y command with the corresponding z
% position, so that each z position is paired with a z "command" which
% is actually just the z position itself.

x_positions = spout_calibration.x;
z_positions = spout_calibration.z;

function [command_x, command_z] = map_y_to_xz_command(command_y)
    if iscolumn(command_y)
        command_y = command_y';
    end

    command_x = zeros(size(command_y));
    command_z = zeros(size(command_y));
    for command_num = 1:length(z_positions)
        command_x(ismember(command_y', unique_command_y(command_num, :), 'rows')) = x_positions(command_num);
        command_z(ismember(command_y', unique_command_y(command_num, :), 'rows')) = z_positions(command_num);
    end
end

spout_calibration.map_y_to_xz_command = @map_y_to_xz_command;

end