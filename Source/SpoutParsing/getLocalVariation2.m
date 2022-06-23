function y = getLocalVariation2(x, window, method)
if ~exist('method', 'var')
    method = 'std';
end

if length(window) == 1
    window = [window, window];
end

switch method
    case 'std'
        method = @std2;
    case 'iqr'
        method = @(x)iqr(x(:));
end

y = zeros(size(x));
for k = 1:size(x, 1)
    k1 = max([1, k - window(1)]);
    k2 = min([size(x, 1), k + window(1)]);
    for j = 1:size(x, 2)
        j1 = max([1, j - window(2)]);
        j2 = min([size(x, 2), j + window(2)]);
        y(k, j) = method(x(k1:k2, j1:j2));
    end
end