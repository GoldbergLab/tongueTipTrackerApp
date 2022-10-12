function spout_calibration = add_xy_to_z_command_map(spout_calibration, command_x, command_y)

% Create a fake command_z vector proportional to the spout_calibration.z
%   positions recorded
unique_command_xy = unique([command_x; command_y]', 'rows', 'stable');
% For each y command, swap out the y command with the corresponding z
% position, so that each z position is paired with a z "command" which
% is actually just the z position itself.

z_positions = spout_calibration.z;

function command_z = map_xy_to_z_command(command_x, command_y)
    if iscolumn(command_x)
        command_x = command_x';
    end
    if iscolumn(command_y)
        command_y = command_y';
    end

    command_xy = [command_x; command_y];
    command_z = zeros(size(command_x));
    for command_num = 1:length(z_positions)
        command_z(ismember(command_xy', unique_command_xy(command_num, :), 'rows')) = z_positions(command_num);
    end
end

spout_calibration.map_xy_to_z_command = @map_xy_to_z_command;

end