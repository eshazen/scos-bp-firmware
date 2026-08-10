function bitvec_vhdlproc(fnamein, fnameout)

tile_size = [16 16];
mean_dark_value = 55;

pix_sum = zeros(640/tile_size(1),1);
pix_sq_sum = zeros(640/tile_size(1),1);


fin = fopen(fnamein, "r");
fout = fopen(fnameout, "w");

tline = fgetl(fin);

line_valid_last = 0;
frame_valid_last = 0;
line_count = 0;
pix_count = 0;
tile_count = 0;
frame_count = 0;
fprintf('Frame %3u', frame_count);

while tline ~= -1
    [valids, ~, ~, ni] = sscanf(tline,'%u', 2);
    frame_valid = valids(1);
    line_valid = valids(2);  

    if frame_valid == 0
        % outside of frame, reset all
        line_count = 0;
        pix_count = 0;
        tile_count = 0;
    else  
        if frame_valid_last == 0
            % new frame
            fprintf(fout, '%08u %08u\n', 1000, 1000);
            frame_count = frame_count +1;
            fprintf('\b\b\b%3u', frame_count);
        end

        if line_valid == 1
            pix_val = bin2dec(tline(ni:end)) - mean_dark_value;

            if line_valid_last == 0 
                % new line started
                line_count = line_count +1;
                pix_count = 1;
                tile_count = 1;
            end
            % receiving data
            if pix_count == 1 && mod(line_count, tile_size(2)) == 1
                % first pixel in tile, reset sums
                pix_sum(tile_count) = pix_val;
                pix_sq_sum(tile_count) = pix_val*pix_val;
            else
                pix_sum(tile_count) = pix_sum(tile_count) + pix_val;
                pix_sq_sum(tile_count) = pix_sq_sum(tile_count) + pix_val*pix_val;
            end
            
            if pix_count == tile_size(1)
                % last pixel in tile for this line 
                if mod(line_count, tile_size(2)) == 0
                    % this was the last pixel in the tile overall
                    fprintf(fout, '%08u %08u\n', pix_sum(tile_count), pix_sq_sum(tile_count));
                end
                pix_count = 1;
                tile_count = tile_count +1;
            else
                pix_count = pix_count +1;
            end
        end
    end

    line_valid_last = line_valid;
    frame_valid_last = frame_valid;
    tline = fgetl(fin);
end

fprintf('\n');
fclose(fin);
fclose(fout);