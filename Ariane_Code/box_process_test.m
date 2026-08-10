clear all

%set source/save folder paths 
addpath('.\natsortfiles\')
path_dirA = '.\sample_data\';
saveFolder = '.\output\';
saveFile = 'finger_sample_data';

%set image size
im_size1 = 400;
im_size2 = 400;
measurement_ind = 1;

%load files
path_dirA = natsortfiles(dir(fullfile(path_dirA,'*.tiff')));

%set length of measurement (frame rate 390Hz)
file_length = 500; %length(path_dirA);

BaslerA = zeros(im_size2, im_size1, file_length, 'uint8');

%read all images and store in BaslerA variable
for file_ind = 1:file_length
    if mod(file_ind,10000) == 1
        disp(['    image # ' num2str(file_ind)]);
    end
    BaslerA(:, :, file_ind) = imread(fullfile(path_dirA(file_ind).folder, path_dirA(file_ind).name));

end
disp('    all images read');

%store BaslerA in measurement
measurement = {BaslerA(:, 1:400, :)};

%pre measured gain and read noise values for this measurement
gain = 0.02636; 
read_noise = 0.1957; 

disp(['    calculating K2 for measurement # ' num2str(measurement_ind)]);
tic;

%calculate K2
[K2,img_I,img_var,img_var_shot,img_var_read,img_var_dig] = ...
    K2_conv(measurement{measurement_ind},gain(measurement_ind),read_noise(measurement_ind));

%calculate BFI/PPG
BFI = 1./K2;
PPG = log(mean(img_I)./img_I);
Kf = sqrt(K2);

%Store all variables in one 
data = cat(2, BFI, PPG, Kf, img_I, sqrt(img_var), img_var_shot, img_var_read,img_var_dig);

%timing to process measurement
t = toc;
disp(['    took ' num2str(t) ' seconds.'])


if ~exist(saveFolder)
    mkdir(saveFolder);
end


save(fullfile(saveFolder,saveFile), 'data');
