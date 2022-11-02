function [healed_mask, patch_size, tongue_size, spout_close] = heal_occlusion(tongue_mask, spout_mask, max_spout_gap, debug, plot_title, video_frame, verbose)
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
%    verbose is an optional boolean flag indicating extra information
%       about the process should be output
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
    max_spout_gap = 10;
end
if ~exist('debug', 'var') || isempty(debug)
    debug = false;
end
if ~exist('plot_title', 'var') || isempty(plot_title)
    plot_title = 'Occlusion healing';
end
if ~exist('video_frame', 'var') || isempty(video_frame)
    video_frame = [];
end
if ~exist('verbose', 'var') || isempty(verbose)
    verbose = false;
end

% Check that there is a tongue
tongue_size = sum(tongue_mask, 'all');
if tongue_size < 3
    if verbose
        warning('Tongue mask is empty, or nearly empty.')
    end
    healed_mask = tongue_mask;
    patch_size = 0;
    spout_close = false;
    return;
end

% Store original mask size, so the masks can be reconstituted at the end
original_tongue_mask = tongue_mask;
original_mask_size = size(tongue_mask);

% Crop tongue mask for speed
[xlimits, ylimits] = getMaskLim(tongue_mask | spout_mask); %, max_spout_gap);
tongue_mask = tongue_mask(xlimits(1):xlimits(2), ylimits(1):ylimits(2));

% Find the blobs in the mask
cc = bwconncomp_sorted(tongue_mask);

% Check if there are multiple blobs in the mask
if cc.NumObjects > 1
    % Perform a morphological closing operation with successively larger
    % structuring elements to try to connect disconnected pieces
    se_radius = 4;
    while (cc.NumObjects > 1) && (se_radius < 10)
        se = strel('disk',se_radius);
        tongue_mask = imclose(tongue_mask, se);
        cc = bwconncomp_sorted(tongue_mask);
        se_radius = se_radius + 1;
    end

    % If we failed to connect all blobs, remove all but the largest blob
    if cc.NumObjects > 1
        tongue_mask(vertcat(cc.PixelIdxList{2:end})) = false;
    end
end

% Get mask of the outer edge of the original tongue pixels (includes
% occlusion indent)
tongue_surface_mask = getMaskSurface(tongue_mask);
[xTongueSurface, yTongueSurface] = ind2sub(size(tongue_mask), find(tongue_surface_mask));
xyTongueSurface = [xTongueSurface, yTongueSurface];

% Get convex hull mask of tongue
try
    conv_hull_tess = convhull(xyTongueSurface);
    % inhull expects the output style that convhulln provides, so we have
    % to replicate that:
    conv_hull_tess = [conv_hull_tess(1:end-1), conv_hull_tess(2:end)];
catch ME
    switch ME.identifier
        case {'MATLAB:qhullmx:DegenerateData', 'MATLAB:convhull:EmptyConvhull2DErrId', 'MATLAB:convhull:NotEnoughPtsConvhullErrId'}
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
    healed_mask = original_tongue_mask;
    patch_size = 0;
    spout_close = false;
    return;
end

% Crop spout mask for speed
spout_mask = spout_mask(xlimits(1):xlimits(2), ylimits(1):ylimits(2));

% spout_surface_mask = getMaskSurface(spout_mask);
% % Get coordinates of spout surface pixels
% [xSpoutSurface, ySpoutSurface] = ind2sub(size(spout_surface_mask), find(spout_surface_mask));
% xySpoutSurface = [xSpoutSurface, ySpoutSurface];

% Get coordinates of spout pixels
[xSpout, ySpout] = ind2sub(size(spout_mask), find(spout_mask));
xySpout = [xSpout, ySpout];

% Check that bounding boxes of spout and tongue overlap
minSpoutXY = min(xySpout, [], 1)-[1, 1];
maxSpoutXY = max(xySpout, [], 1)+[1, 1];
minTongueXY = min(xyTongueSurface, [], 1);
maxTongueXY = max(xyTongueSurface, [], 1);

spoutRect = [minSpoutXY, maxSpoutXY - minSpoutXY];
tongueRect = [minTongueXY, maxTongueXY - minTongueXY];

spoutTongueBBoxOverlap = rectint(spoutRect, tongueRect);
if spoutTongueBBoxOverlap == 0
    if verbose
        warning('No bbox overlap.')
    end
    healed_mask = original_tongue_mask;
    patch_size = 0;
    spout_close = false;
    return;
end

spoutInTongueHull = sum(inhull(xySpout, xyTongueSurface, conv_hull_tess, 0));

% Check that tongue convex hull actually intersects spout
if spoutInTongueHull == 0
    if verbose
        warning('No occlusion found.')
    end
    healed_mask = original_tongue_mask;
    patch_size = 0;
    spout_close = false;
    return;
end

% Check if tongue is actually in front of spout
%   If tongue is in front of spout, not only the hull, but the tongue mask
%   itself should have significant intersection.
tongueOverSpout = sum(spout_mask & tongue_mask, 'all');
if tongueOverSpout / spoutInTongueHull > 0.5
    % At least 50% of the spout/tongue hull overlap is actual tongue -
    % there should be little or no tongue in the spout if it's a real
    % occlusion, so the tongue is probably actually in front of the spout,
    % not the other way around.
    if verbose
        warning('Reverse occlusion - tongue in front of spout.')
    end
    healed_mask = original_tongue_mask;
    patch_size = 0;
    spout_close = false;
    return;
end

[~, convhull_mask, xyHullBoundary] = drawMaskPolygon(xyTongueSurface(conv_hull_tess(:, 1), :), size(tongue_mask), true);

% Get an ordered list of pixels around the edge of the convex hull of
% tongue
% [xhb, yhb] = getMaskOrdering(convhull_surface_mask, [], [-1, 0]);
% xyHullBoundary = [xhb', yhb'];

% Get pixels that are both in the outer boundary of the tongue convex hull,
% AND in the spout mask. These pixels should represent the "gap" in the
% convex hull of the tongue that the spout occludes
concavityMask = ismember(xyHullBoundary, xySpout, 'rows');

if sum(concavityMask) == 0
    % No actual gap in tongue hull boundary
    healed_mask = original_tongue_mask;
    patch_size = 0;
    spout_close = false;
    return;
end

% Get hull boundary coordinates with the spout occlusion removed
xyGapRemoved = xyHullBoundary(~concavityMask, :);
gapStartIdx = find(concavityMask, 1)-1;

reference_radius = 3; % Number of fitting points on either side of gap
% Interpolate new values within gap based on points on either side of the
% gap
xyGapHealed = healGap(xyGapRemoved, gapStartIdx, reference_radius);

[~, interp_hull_mask, ~] = drawMaskPolygon(xyGapHealed, size(tongue_mask), true);

% Restrict the patched hull to the region behind the spout (we don't want
% to convexify other parts of the tongue)
patched_mask = tongue_mask | (interp_hull_mask & spout_mask);

% It's likely there may be small gaps between the tongue and the spout
% mask, so we need to fill those in with a closure.
% First, dilate the spout mask to produce a safe region in which to perform
% the closure, so we don't close other parts of the tongue.
dilated_spout_mask = imdilate(spout_mask, ones(max_spout_gap));
% Close the patched mask
closed_patched_mask = imclose(patched_mask, strel('disk', max_spout_gap));
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
    f = figure('units','normalized','outerposition',[0 0 1 1]);
    nPlots = 7;
    ax0 = subplot(1, nPlots, 1, 'Parent', f); hold(ax0, 'on');
    plotMask(ax0, tongue_mask);
    title(ax0, 'Original mask');

    ax1 = subplot(1, nPlots, 2, 'Parent', f); hold(ax1, 'on');
    plotMask(ax1, tongue_mask);
    plotMask(ax1, spout_mask, 'd');
    title(ax1, 'Original mask + spout');
    ax2 = subplot(1, nPlots, 3, 'Parent', f); hold(ax2, 'on');
    plotMask(ax2, tongue_mask);
    title(ax2, plot_title);
    plotMask(ax2, spout_mask);

    imagesc(convhull_mask', 'Parent', gca, 'AlphaData', 0.1);
    plot(xyHullBoundary(:, 1), xyHullBoundary(:, 2), '-*r');
    plotMask(gca, tongue_surface_mask, 2);
%    plot(xyConcavity(:, 1), xyConcavity(:, 2), 'dk', 'MarkerSize', 15);
    plot(xyHullBoundary(:, 1), xyHullBoundary(:, 2), '--+b', 'MarkerSize', 9);

    ax3 = subplot(1, nPlots, 4);
    plotMask(ax3, tongue_mask);
    hold(ax3, 'on');
    plotMask(ax3, healed_mask & ~tongue_mask, 'filled');

    ax4 = subplot(1, nPlots, 5);
    plotMask(ax4, healed_mask);

    if ~isempty(video_frame)
        video_frame = video_frame(xlimits(1):xlimits(2), ylimits(1):ylimits(2));

        ax5 = subplot(1, nPlots, 6);
        imshow(video_frame', 'Parent', ax5);
        
        set(ax5, 'YDir','reverse');
        
        ax6 = subplot(1, nPlots, 7);
        imshow(video_frame', 'Parent', ax6);
        hold(ax6, 'on');
        plotMask(ax6, tongue_mask, 1);
        plotMask(ax6, spout_mask, 1);
        
        set(ax6, 'YDir','reverse');
    end

    linkaxes([ax0, ax1, ax2, ax3, ax3, ax4]);
end

healed_mask = uncrop(healed_mask, original_mask_size, xlimits, ylimits);

function uncropped_mask = uncrop(cropped_mask, original_size, xlimits, ylimits)
uncropped_mask = false(original_size);
uncropped_mask(xlimits(1):xlimits(2), ylimits(1):ylimits(2)) = cropped_mask;