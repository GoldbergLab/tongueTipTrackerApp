function tip_coords = project_tip_guess_on_boundary(tip_guess_coords, centroid_coords, boundary_coords)
% Project the line from the tongue centroid to the tip guess coordinate
% onto the boundary candidate coordinates, and select the boundary voxel 
% that is closest to that line, so the tip will actually be on the boundary
% of the tongue.

% Obtain the vector and unit vector from the centroid to the tip guess
tip_vec = tip_guess_coords - centroid_coords;
tip_vec_hat = tip_vec / norm(tip_vec);

% Obtain the vectors from the centroid to each boundary point
boundary_vecs = boundary_coords - centroid_coords;
boundary_vecs_hat = boundary_vecs ./ vecnorm(boundary_vecs')';

% Find the vector that extends from each boundary point perpendicularly to
% the centroid-tip_guess line.
perpendicular_vecs = boundary_vecs - (boundary_vecs_hat * tip_vec_hat') .* tip_vec;
if size(perpendicular_vecs, 1) ~= 3
% vecnorm will norm across the second dimension, so we have to make sure
% our perpendicular vectors are arranged that way.
    perpendicular_vecs = perpendicular_vecs';
end

% Find the distance of each boundary point to the line
distances_from_line = vecnorm(perpendicular_vecs);

% Find which boundary point is closest to the line
[~, minIdx] = min(distances_from_line);

% Select the tip coordinates of the boundary point closest to the line.
tip_coords = boundary_coords(minIdx, :);

% scatter3(tip_coords(1), tip_coords(2), tip_coords(3), 'MarkerEdgeColor', 'green', 'MarkerFaceColor', 'green')
% disp('hi')