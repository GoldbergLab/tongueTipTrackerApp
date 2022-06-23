function y = getLocalVariation(x, window, method)
if ~exist('method', 'var')
    method = 'std';
end
switch method
    case 'std'
        method = @std;
    case 'iqr'
        method = @iqr;
end

y = zeros(size(x));
for k = 1:length(x)
    a = max([1, k - window]);
    b = min([length(x), k + window]);
    y(k) = method(x(a:b));
end