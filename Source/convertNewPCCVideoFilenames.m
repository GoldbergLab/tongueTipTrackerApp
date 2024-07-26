function [matchingFiles, newFiles] = convertNewPCCVideoFilenames(rootDirectory, lookInSubdirectories, overWrite, videoType, dryRun)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% convertNewPCCVideoFilenames: Convert new PCC filenames to old format
% usage:  [matchingFiles, newFiles] = convertNewPCCVideoFilenames(rootDirectory)
%         [matchingFiles, newFiles] = convertNewPCCVideoFilenames(rootDirectory, lookInSubdirectories)
%         [matchingFiles, newFiles] = convertNewPCCVideoFilenames(rootDirectory, lookInSubdirectories, overWrite)
%         [matchingFiles, newFiles] = convertNewPCCVideoFilenames(rootDirectory, lookInSubdirectories, overWrite, videoType)
%         [matchingFiles, newFiles] = convertNewPCCVideoFilenames(rootDirectory, lookInSubdirectories, overWrite, videoType, dryRun)
%
% where,
%    rootDirectory is the directory in which to look for video files to 
%       rename
%    lookInSubdirectories is an optional boolean flag indicating whether or
%       not to also search for video files in subdirectories. Default is 
%       false.
%    overWrite is an optional boolean flag indicating whether or not to
%       overwrite files if a file with a converted name already exists. If
%       false, the function will terminate with an error without moving any
%       files. If true, the function will overwrite existing files. Default
%       is false.
%    videoType indicates whether to look for avi or cine files. Must be
%       either 'avi' or 'cine'. Default is 'cine'.
%    dryRun is an optional boolean flag indicating whether or not to do a
%       "dry run" or not. If true, the function will display a list of
%       actions it would have taken, but will not actually rename any
%       files. If false, the function will rename files. Default is false.
%
% At some point between PCC (Phantom Camera Control) version 3.4 and 3.9,
%   the timestamp formatting for video files changed. This function is
%   designed to convert filenames created with the new format to the old 
%   format so they are compatible with existing software.
%
% See also: <related functions>
%
% Version: 1.0
% Author:  Brian Kardon
% Email:   bmk27=cornell*org, brian*kardon=google*com
% Real_email = regexprep(Email,{'=','*'},{'@','.'})
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
arguments
    rootDirectory char = '.'
    lookInSubdirectories logical = false
    overWrite logical = false
    videoType char {mustBeMember(videoType, {'avi', 'cine'})} = 'cine'
    dryRun logical = false
end

% Define starting and ending timestamp formats
% PCC {timeF} timestamp format: YyyyymmddHhhmmss.xxxxxxxxx
% Destination timestamp format: Sat Nov 20 2021 16 48 49.972 124.00_C1001.avi
startingTimestampFormat = '''Y''yyyyMMdd''H''HHmmss.SSSSSSSSS';
startingTimestampRegex = 'Y[0-9]{8}H[0-9]{6}\.[0-9]{9}';
destinationTimestampFormat = 'eee MMM dd yyyy HH mm ss.SSSSSS.00'; 
% Note: For some reason there's a space between the millisecond and 100 microsecond place that we'll have to add in later.

% Select file type
switch videoType
    case 'avi'
        suffix = '[aA][vV][iI]';
    case 'cine'
        suffix = '[cC][iI][nN][eE]';
end

% Prepare the full regular expression used to find relevant files
regex = sprintf('(.*)_(%s)\\.%s', startingTimestampRegex, suffix);

% Find a list of matching files, and extract the prefixes (path and mouse
%   ID) and timestamp strings
[matchingFiles, mouseIDs, timestamps] = findFilesByRegex(rootDirectory, regex, false, lookInSubdirectories);

% Convert the timestamp strings to datetime objects
timestamps = datetime(timestamps, 'InputFormat', startingTimestampFormat);

% Construct new file paths
newFiles = cell(size(matchingFiles));
for k = 1:length(matchingFiles)
    % Format the new timestamp
    newTimestamp = char(timestamps(k), destinationTimestampFormat);
    % Add in the extra space between the millisecond place and the 100
    %   microsecond place
    newTimestamp = [newTimestamp(1:end-6), ' ', newTimestamp(end-5:end)];
    % Get the original folder path
    [folder, ~, ~] = fileparts(matchingFiles{k});
    % Construct the new filename
    newFiles{k} = fullfile(folder, [mouseIDs{k}, '_', newTimestamp, '.', videoType]);
    if ~overWrite
        if exist(newFiles{k}, 'file')
            % Exit before renaming anything, because there is a filename
            % conflict and overWrite is False
            error('File %s already exists, and overWrite=False. Operation aborted, no files renamed.', newFiles{k})
        end
    end
end

% Rename the files (or display the intended action if dryRun is True)
for k = 1:length(matchingFiles)
    oldFile = matchingFiles{k};
    newFile = newFiles{k};
    if dryRun
        fprintf('DRYRUN: This would have moved: %s\nto\n\t%s\n', oldFile);
        fprintf('                                 to\n');
        fprintf('                               %s\n', newFile);
    else
        fprintf('Moving: %s\nto\n\t%s\n', oldFile);
        fprintf(' `        to\n');
        fprintf('        %s\n', newFile);
        movefile(oldFile, newFile)
    end
end

fprintf('\n\nDONE\n\n')

if dryRun
    fprintf('\n\nRun again with dryRun as False to move files.\n')
end