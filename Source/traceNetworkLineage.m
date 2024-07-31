function lineage = traceNetworkLineage(networkFilename, rootTrainingDir, rootSwaps)

rootTrainingDir = resolvePath(rootTrainingDir);

params = readNetworkTrainingParams(rootTrainingDir);

fprintf('Checking %s\n', networkFilename);

lineage = params(strcmp(networkFilename, {params.newNetworkName}));
if isempty(lineage)
    return;
end

if exist('rootSwaps', 'var') && ~isempty(rootSwaps)
    lineage.trainingDataPath = RootSwap(lineage.trainingDataPath, rootSwaps{1}, rootSwaps{2});
else
    rootSwaps = {};
end

try
    S = load(lineage.trainingDataPath);
    lineage.numFrames = size(S.imageStack, 1);
catch ME
    lineage.numFrames = NaN;
end

[trainingFolder, ~, ~] = fileparts(lineage.trainingDataPath);
[trainingParentFolder, ~, ~] = fileparts(trainingFolder);
try
    S = load(fullfile(trainingParentFolder, 'assembledRandomFrames_ROI.mat'));
    videoPaths = S.outputStruct.originalVideoPaths;
    mouseNames = regexp(videoPaths, '^(.*)\_[A-z][a-z][a-z] [A-z][a-z][a-z] [0-9]+ [0-9]+.*', 'tokens');
    mouseNames = unique(cellfun(@(x)x{1}, mouseNames));
    lineage.mouseNames = mouseNames;
    lineage.numMice = length(mouseNames);
catch ME
    lineage.mouseNames = {};
    lineage.numMice = NaN;
end
newLineage = traceNetworkLineage(lineage.startNetworkName, rootTrainingDir, rootSwaps);
if ~isempty(newLineage)
    lineage = [lineage, newLineage];
end