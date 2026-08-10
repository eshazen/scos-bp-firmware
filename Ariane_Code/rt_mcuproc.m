%%

if ~exist('s', 'var')
    s = serialport("COM19", 12000000, 'FlowControl', 'hardware');
end
s.flush();
s.Timeout = 1;
s.flush();


tile_size = [32 32];
frame_size = [1280 480];
ntiles = prod(frame_size./tile_size);
npix = prod(tile_size);

%% get full raw frame
nslices = 16;
npix_per_slc = prod(frame_size) / nslices;
img_data = zeros(prod(frame_size), 1, 'uint8');

disp('getting raw frame');
fprintf('acquiring slice   ');
for islice = 1:nslices
    fprintf('\b\b%2u',islice)
    write(s, [islice-1, islice-1+16], 'uint8');
    img_data((1:npix_per_slc)+(islice-1)*npix_per_slc) = read(s, npix_per_slc, 'uint8');
end
write(s, 0, 'uint8');
fprintf('\n');

img_data = reshape(img_data, frame_size);
image(img_data');

colormap bone
axis image


%% display real time bfi
var_digitization = 1/12;
gain = 0.0956;
var_read = 1;

nframes_to_disp = 1200;
nframes_per_xfer = 120;

tv = (1:nframes_to_disp)/120;
K2_f = zeros(nframes_to_disp,1);

rtfig = figure('Position', [100, 100, 1000, 500]);
p = plot(tv, K2_f);

p.XDataSource = 'tv';
p.YDataSource = 'K2_f';

pause(2);

disp('starting real-time bfi');
s.flush()
write(s, 32, 'uint8'); % start acquisition
frame_count = 0;
fprintf('Frame %6u', frame_count);
while ishandle(rtfig)
    fprintf('\b\b\b\b\b\b%6u', frame_count);
   rawdat = read(s, nframes_per_xfer*(2*ntiles+2), 'uint32');
   for iframe = 1:nframes_per_xfer
        if ~all(rawdat((1:2) + (iframe-1)*(2*ntiles+2)) == [65534, 65535])
            disp('header error')
            fprintf('%08x %08x\n', rawdat((1:2) + (iframe-1)*(2*ntiles+2)));
        end
        pix_sum_array = rawdat((1:2:(2*ntiles)) + 2 + (iframe-1)*(2*ntiles+2));
        pix_sq_sum_array = rawdat((1:2:(2*ntiles)) + 3 + (iframe-1)*(2*ntiles+2));
        mean_I_array = pix_sum_array / npix;
        var_I_array = pix_sq_sum_array/npix - mean_I_array.^2;
        var_shot_array = mean_I_array*gain;
        K2_f_array = (var_I_array - var_digitization - var_shot_array - var_read)./(mean_I_array.^2);
        K2_f(mod(frame_count+iframe, nframes_to_disp)+1) = mean(K2_f_array(:));
   end
   frame_count = frame_count + nframes_per_xfer;
    
   % refreshdata
   %  drawnow
end
write(s, 0, 'uint8'); % stop acquisition
disp('stopping');
fprintf('\n');