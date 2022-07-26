function healed_3mask = heal_occlusion(tongue_3mask, spout_3mask)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% heal_occlusion: Heal a spout occlusion in a 3D tongue mask
% usage:  healed_3mask = heal_occlusion(tongue_3mask, spout_3mask, 
%                                       occlusion_direction)
%
% where,
%    tongue_3mask is a 3D binary mask indicating which voxels contain
%       tongue, and which do not. Must be the same size as spout_3mask
%    spout_3mask is a 3D binary mask indicating which voxels contain spout
%       and which do not. Must be the same size as tongue_3mask
%
% This function is designed to "heal" a tongue volume where the tongue was
%   known to be occluded by the spout.
%
% See also: tongueTipTracker
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

occlusion_direction = 1;

occlusion_dimension = abs(occlusion_direction);

spoutShadow = shadow3Mask(spout_3mask, occlusion_dimension, sign(occlusion_direction));
snoutShadow = shadow3Mask(tongue_3mask, 3, -1);

% Compute mask of interior of convex hull of tongue
[x, y, z] = ndgrid(1:size(tongue_3mask, 1), 1:size(tongue_3mask, 2), 1:size(tongue_3mask, 3));
xyz = [x(:), y(:), z(:)];
[x, y, z] = ind2sub(size(tongue_3mask), find(tongue_3mask));
xyzTongue = [x, y, z];isInHull = inhull(xyz, xyzTongue, [], 0.1);
convhull_3mask = zeros(size(tongue_3mask));
convhull_3mask(isInHull) = true;

tongue_patch = spoutShadow & snoutShadow & convhull_3mask;

ax = plot3Mask(tongue_patch);
hold(ax, 'on');
plot3Mask(ax, tongue_3mask);
title(ax, 'tongue patch')

% [k2,av2] = convhull(x,y,z,'Simplify',true);

healed_3mask = tongue_3mask | tongue_patch;

figure;
ax = plot3Mask(healed_3mask);
title(ax, 'Pre-closure');

% Compute a morphological closure of healed mask to close any gaps between
% spout and spout shadow.
maxSpoutGap = 4;
s = strel('sphere', maxSpoutGap/2);
closed_3mask = imclose(healed_3mask, s);
% Compute an expanded patch volume in which to apply the closure, so we
% don't alter the shape of the tongue away from the patch.
s_dilate = strel('sphere', maxSpoutGap*2);
closable_3mask = imdilate(tongue_patch, s_dilate);
% Restrict closed region to the expanded spout area
closed_3mask = closed_3mask & closable_3mask;
% Combine the original healed mask with the closed healed mask.
healed_3mask = healed_3mask | closed_3mask;