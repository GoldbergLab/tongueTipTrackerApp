function params = readNetworkTrainingParams(paramFile)
if isfolder(paramFile)
    paramDir = paramFile;
    paramFiles = findFilesByRegex(paramDir, 'networkTrainingParameters');
    for k = 1:length(paramFiles)
        paramFile = paramFiles{k};
        params(k) = readNetworkTrainingParams(paramFile);
    end
else
    finfo = dir(paramFile);
    fid = fopen(paramFile, 'r');
    raw = char(fread(fid)');
    fclose(fid);
    params = jsondecode(raw);
    params.lastModified = finfo.date;
end