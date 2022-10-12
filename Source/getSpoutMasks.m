function [bot, top] = getSpoutMasks(spout_bbox, mask_size)
% Return two 2D logical arrays representing spout masks from the bottom and
%   side views..
% If t_stats is 1xN (indicating it contains N licks), then spout_bbox will
%   be Nx6, such that spout_bbox(n, :) will return a 1x6 vector of the form
%   [x0, y0, z0, sX, sY, sZ], where [x0, y0, z0] is the bottom back left
%   corner of the spout, and sX, sY, and sZ are the size of the spout
%   bounding box in each dimension.
% mask_size is a 1x3 array indicating the 3D size of the mask volume

bot_mask_size = [mask_size(1), mask_size(2)];
top_mask_size = [mask_size(3), mask_size(2)];

bot_bbox = round([spout_bbox(1), spout_bbox(2), spout_bbox(4), spout_bbox(5)]);
top_bbox = round([spout_bbox(3), spout_bbox(2), spout_bbox(6), spout_bbox(5)]);

bot = false(bot_mask_size);
top = false(top_mask_size);

bot(bot_bbox(1):(bot_bbox(1)+bot_bbox(3)), bot_bbox(2):(bot_bbox(2) + bot_bbox(4))) = true;
top(top_bbox(1):(top_bbox(1)+top_bbox(3)), top_bbox(2):(top_bbox(2) + top_bbox(4))) = true;

top = flipud(top);