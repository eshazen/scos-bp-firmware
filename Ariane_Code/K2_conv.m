function [K2,img_I,img_var,img_var_shot,img_var_read,img_var_dig,K2_t] = K2_conv(measurement, gain, read_noise)

file_length = length(measurement(1, 1, :)); 
img = double(measurement);

% digitization variance offset
var_digitization = 1/12;

nw = 49; % number of pixels in the window

%calculate K2 + other var for each image
for i = 1:file_length
    

    [~, std_I2, mean_I_shot2] = calculateSpatialContrast(img(:,:,i));

    var_I = std_I2.^2;
    mean_I = mean_I_shot2;
    var_shot = img(8:end-7,8:end-7,i).*gain;
    
    K2_total_array = (var_I)./(mean_I.^2);
    K2_total_mean = mean(K2_total_array(:));

    % window correction
    window_factor = nw/(nw - K2_total_mean);

    K2_f_array = (var_I - var_digitization - var_shot - read_noise^2)./(mean_I.^2);
    K2_f = mean(K2_f_array(:));

    K2(i) = K2_f*window_factor;
    K2_t(i) = K2_total_mean*window_factor;
    img_I(i) = mean(mean_I_shot2, 'all');
    img_var(i) = mean(var_I, 'all');
    img_var_shot(i) = mean(var_shot, 'all');
    img_var_read(i) = mean(read_noise^2, 'all');
    img_var_dig(i) = mean(var_digitization);


end

K2 = K2'; img_I = img_I'; img_var = img_var'; img_var_shot = img_var_shot';
img_var_read = img_var_read'; img_var_dig = img_var_dig';
K2_t = K2_t';

clear img
end
