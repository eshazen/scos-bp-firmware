function [K2_f, K2_raw, K2_shot, K2_spatial, mean_var_I, mean_sq_mean_I] = getK2fTiled(frames, var_read, window_size)

if nargin < 2
    var_read = 1;
end
if nargin < 3
    window_size = [8,8];
end

var_digitization = 1/12;

gain = 0.0956;

%%
nframes = size(frames,3);
K2_f = zeros(nframes, 1);
K2_shot = zeros(nframes, 1);
K2_raw = zeros(nframes, 1);
mean_var_I = zeros(nframes, 1);
mean_sq_mean_I = zeros(nframes, 1);

for iframe = 1:nframes
    frame = double(frames(:,:,iframe));
    mean_I_array = zeros(floor(size(frame)./window_size));
    var_I_array = zeros(floor(size(frame)./window_size));
    
    for ix = 1:size(mean_I_array,1)
        for iy = 1:size(mean_I_array,2)
            image_slice = frame((1:window_size(1)) + (ix-1)*window_size(1), (1:window_size(2)) + (iy-1)*window_size(2));
            mean_I_array(ix,iy) = mean(image_slice(:));
            var_I_array(ix,iy) = var(image_slice(:));
        end
    end
    
    var_shot_array = mean_I_array*gain;
    
    K2_total_array = var_I_array./(mean_I_array.^2);
    K2_total_mean = mean(K2_total_array(:));
    window_factor = window_size(1)*window_size(2)/(window_size(1)*window_size(2) - K2_total_mean);
    
    K2_raw_array = var_I_array./(mean_I_array.^2);
    K2_shot_array = var_shot_array./(mean_I_array.^2);
    K2_f_array = (var_I_array - var_digitization - var_shot_array - var_read)./(mean_I_array.^2);
    
    mean_var_I(iframe) = mean(var_I_array(:));
    mean_sq_mean_I(iframe) = mean(mean_I_array(:).^2);

    K2_raw(iframe) = mean(K2_raw_array(:)) * window_factor;
    K2_shot(iframe) = mean(K2_shot_array(:)) * window_factor;
    K2_f(iframe) = mean(K2_f_array(:)) * window_factor;
end

%% --- spatial heterogenity correction ---
mean_on_frame = mean(frames,3);
mean_sp_array = zeros(size(mean_on_frame)./window_size);
var_sp_array = zeros(size(mean_on_frame)./window_size);
for ix = 1:size(mean_I_array,1)
    for iy = 1:size(mean_I_array,2)
        image_slice = mean_on_frame((1:window_size(1)) + (ix-1)*window_size(1), ...
            (1:window_size(2)) + (iy-1)*window_size(2));
        mean_sp_array(ix,iy) = mean(image_slice(:));
        var_sp_array(ix,iy) = var(image_slice(:));
    end
end
K2_spatial_array = (var_sp_array - gain*mean_sp_array/nframes) ./ (mean_sp_array.^2);
K2_spatial = mean(K2_spatial_array(:))*window_factor;
K2_f = K2_f - K2_spatial;