function [healed_mask, patch_size, tongue_size, spout_close] = heal_occlusion(tongue_mask, spout_mask, max_spout_gap, debug, plot_title)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% heal_occlusion: Heal a spout occlusion in a 2D tongue mask
% usage:  healed_mask = heal_occlusion(tongue_mask, spout_mask, 
%
% where,
%    tongue_mask is a 2D binary mask indicating which pixels contain
%       tongue, and which do not. Must be the same size as spout_mask
%    spout_mask is a 2D binary mask indicating which pixels contain spout
%       and which do not. Must be the same size as tongue_mask
%    max_spout_gap is an optional integer indicating the maximum expected
%       gap in pixels between an occluding spout and the occluded tongue.
%    debug is an optional boolean flag indicating whether or not to produce
%       debugging plots
%
% This function is designed to "heal" a tongue mask where the tongue was
%   known to be occluded by the spout.
%
% See also: tongueTipTracker
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~exist('max_spout_gap', 'var') || isempty(max_spout_gap)
    max_spout_gap = 5;
end
if ~exist('debug', 'var') || isempty(debug)
    debug = false;
end
if ~exist('plot_title', 'var') || isempty(plot_title)
    plot_title = 'Occlusion healing';
end

verbose = false;

% Store original mask size, so the masks can be reconstituted at the end
original_mask_size = size(tongue_mask);

% Crop tongue mask for speed
[xlimits, ylimits] = getMaskLim(tongue_mask | spout_mask, max_spout_gap);
tongue_mask = tongue_mask(xlimits(1):xlimits(2), ylimits(1):ylimits(2));

% Check that there is a tongue
tongue_size = sum(tongue_mask, 'all');
if tongue_size < 3
    if verbose
        warning('Tongue mask is empty, or nearly empty.')
    end
    healed_mask = uncrop(tongue_mask, original_mask_size, xlimits, ylimits);
    patch_size = 0;
    spout_close = false;
    return;
end

% Get coordinate matrices for the whole mask area
% [x, y] = ndgrid(1:size(tongue_mask, 1), 1:size(tongue_mask, 2));
% xy = [x(:), y(:)];

% Get coordinates of tongue pixels
% [xTongue, yTongue] = ind2sub(size(tongue_mask), find(tongue_mask));
% xyTongue = [xTongue, yTongue];

% Get mask of the outer edge of the original tongue pixels (includes
% occlusion indent)
tongue_surface_mask = getMaskSurface(tongue_mask);
[xTongueSurface, yTongueSurface] = ind2sub(size(tongue_mask), find(tongue_surface_mask));
xyTongueSurface = [xTongueSurface, yTongueSurface];

% Get convex hull mask of tongue
try
    conv_hull_tess = convhulln(xyTongueSurface);
catch ME
    switch ME.identifier
        case 'MATLAB:qhullmx:DegenerateData'
            conv_hull_tess = [];
        otherwise
            rethrow(ME);
    end
end
if isempty(conv_hull_tess) %dt.ConnectivityList)
    % No triangulation
    if verbose
        warning('Tongue mask is insufficiently large to complete calculation.')
    end
    healed_mask = uncrop(tongue_mask, original_mask_size, xlimits, ylimits);
    patch_size = 0;
    spout_close = false;
    return;
end

% Crop spout mask for speed
spout_mask = spout_mask(xlimits(1):xlimits(2), ylimits(1):ylimits(2));

% Get coordinates of spout pixels
[xSpout, ySpout] = ind2sub(size(spout_mask), find(spout_mask));
xySpout = [xSpout, ySpout];

spoutInTongueHull = inhull(xySpout, xyTongueSurface, conv_hull_tess, 0);

% Check that tongue convex hull actually intersects spout
if sum(spoutInTongueHull) == 0
    if verbose
        warning('No occlusion found.')
    end
    healed_mask = uncrop(tongue_mask, original_mask_size, xlimits, ylimits);
    patch_size = 0;
    spout_close = false;
    return;
end

convhull_mask = inHullMask(size(tongue_mask), xyTongueSurface, conv_hull_tess, 0);

% Get an ordered list of pixels around the edge of the convex hull of
% tongue
[xhb, yhb] = getMaskOrdering(getMaskSurface(convhull_mask), [], [-1, 0]);
xyHullBoundary = [xhb', yhb'];

% Get pixels that are both in the outer boundary of the tongue convex hull,
% AND in the spout mask. These pixels should represent the "gap" in the
% convex hull of the tongue that the spout occludes
concavityMask = ismember(xyHullBoundary, xySpout, 'rows');

% Compute the coordinates of the "gap" pixels
xyGap = xyHullBoundary(concavityMask, :);

if isempty(xyGap)
    healed_mask = uncrop(tongue_mask, original_mask_size, xlimits, ylimits);
    patch_size = 0;
    spout_close = false;
    return;
end

% Get the coordinates of the N pixels on either side of the "gap", which 
% will be used to fit a spline
num_reference_points = 6;  % Number of fitting points
gapBoundaries = ~concavityMask & logical(conv(concavityMask, ones(1, 1 + num_reference_points), 'same'));
xyConcavity = xyHullBoundary(gapBoundaries, :);
% Interpolate new values within gap based on points on either side of the
% gap
try
[yGapHealed] = healGap(xyConcavity(:, 1), xyConcavity(:, 2), xyGap(:, 1));
catch
    disp('oops')
end
xyFit = round([xyGap(:, 1), yGapHealed]);
% Fit a spline to the gap border points, and use it to predict the outer
% coordinates of the tongue that are behind the spout
% try
%     fitY = pchip(xyConcavity(:, 1), xyConcavity(:, 2), xyGap(:, 1));
% catch
%     try
%         fitY = pchiprot(xyConcavity(:, 1), xyConcavity(:, 2), xyGap(:, 1));
%     catch
%         warning('Failed to fit spline - using line instead.');
%         fitY = xyGap(:, 2);
%     end
% end
% xyFit = [xyGap(:, 1), fitY];
xyHullBoundary(concavityMask, :) = xyFit;

try
    % Use new patched hull boundary to create a patched convex hull mask
    interp_hull_mask = inHullMask(size(tongue_mask), xyHullBoundary, [], 0);
catch
    disp('oops')
end

% Restrict the patched hull to the region behind the spout (we don't want
% to convexify other parts of the tongue)
patched_mask = tongue_mask | (interp_hull_mask & spout_mask);

% It's likely there may be small gaps between the tongue and the spout
% mask, so we need to fill those in with a closure.
% First, dilate the spout mask to produce a safe region in which to perform
% the closure, so we don't close other parts of the tongue.
dilated_spout_mask = imdilate(spout_mask, ones(max_spout_gap));
% Close the patched mask
closed_patched_mask = imclose(patched_mask, ones(max_spout_gap));
% Combine the patched original mask with the closed patch near the spout.
healed_mask = patched_mask | (dilated_spout_mask & closed_patched_mask);

% Check whether the dilated spout mask overlaps the original tongue - this
% is for a later check if the tongue is really obscured or merely deformed.
if any(dilated_spout_mask & tongue_mask, 'all')
    spout_close = true;
else
    spout_close = false;
end
    

patch_size = sum(healed_mask, 'all') - sum(tongue_mask, 'all');

if debug
    f = figure;
    ax1 = subplot(1, 3, 1, 'Parent', f); hold(ax1, 'on');
    plotMask(ax1, tongue_mask);
    plotMask(ax1, spout_mask, 'd');
    title(ax1, 'Original mask');
    ax2 = subplot(1, 3, 2, 'Parent', f); hold(ax2, 'on');
    plotMask(ax2, tongue_mask);
    title(ax2, plot_title);
    plotMask(ax2, spout_mask);

    imagesc(convhull_mask', 'Parent', gca, 'AlphaData', 0.1);
    plot(xyHullBoundary(:, 1), xyHullBoundary(:, 2), '-*r');
    plotMask(gca, tongue_surface_mask, 2);
    plot(xyConcavity(:, 1), xyConcavity(:, 2), 'dk', 'MarkerSize', 15);
    plot(xyHullBoundary(:, 1), xyHullBoundary(:, 2), '--+b', 'MarkerSize', 9);

    ax3 = subplot(1, 3, 3, 'Parent', f);
    plotMask(ax3, healed_mask);
    title(ax3, 'Healed mask');
end

healed_mask = uncrop(healed_mask, original_mask_size, xlimits, ylimits);

function uncropped_mask = uncrop(cropped_mask, original_size, xlimits, ylimits)
uncropped_mask = false(original_size);
uncropped_mask(xlimits(1):xlimits(2), ylimits(1):ylimits(2)) = cropped_mask;