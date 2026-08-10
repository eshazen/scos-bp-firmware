function [K, std_I, mean_I] = calculateSpatialContrast(image,varargin)
%calculateContrast Calculate contrast values from image
%   Inputs:
%       image = y by x
%       use_convolution (optional, default = true) = whether to 2D convolve to get std and mean.
%       window (optional, default = 7x7 window) = the convolution window.
%   Outputs:
%       K = contrast (unitless)
%       std_I = standard deviation. More than one value if convolution is
%       used.
%       mean_I = mean intensity. More than one value if convolution is
%       used.

if nargin > 1
    use_convolution = varargin{1};
else
    use_convolution = true;
end

if use_convolution
    if nargin > 2
        window = varargin{2};
    else
        window = ones(7,7); window = window./49;
    end
end

image = double(image);

if use_convolution
    mean_I = conv2(image, window, 'same');
    mean2_I = conv2(image.^2, window, 'same');
    var_I = mean2_I - mean_I.^2;
    var_I = var_I*numel(window)/(numel(window)-1);
    std_I = sqrt(var_I);

    % remove edges
    edge_length_y = size(window,1);
    edge_length_x = size(window,2);

    std_I = std_I(edge_length_y+1:size(image,1)-edge_length_y,...
        edge_length_x+1:size(image,2)-edge_length_x);
    mean_I = mean_I(edge_length_y+1:size(image,1)-edge_length_y,...
        edge_length_x+1:size(image,2)-edge_length_x);

    K = mean(std_I(:))/mean(mean_I(:));
else
    mean_I = mean(image(:));
    std_I = std(image(:));

    K = std_I/mean_I;
end

end