function matimg2bitvec(fnamein, fnameout)
% create vector file that we can load into VHDL testbench
%
% output format is:
% <frame_valid> <line_valid> <pixel_valid> <pixel_value> 
%
% example:
% matimg2bitvec('.\sample_data\SynthData\const_no_grad.mat', '.\bitvecs\const_no_grad.txt')

nbits = 16;
nframes_to_cnv = 1;
ncyc_btw_frames = 100;
ncyc_btw_lines = 30;


load(fnamein, "meas");
fout = fopen(fnameout, "w");
formatspec = '%u %u %u %s\n';

for iframe = 1:nframes_to_cnv
    % between frames
    % frame_valid = 0
    for ii = 1:ncyc_btw_frames
        fprintf(fout, formatspec, 0, 0, 0, dec2bin(0,nbits));
    end
    
    for iline = 1:size(meas,2)
        % between lines
        % frame_valid = 1, line_valid = 0
        for ii = 1:ncyc_btw_lines
            fprintf(fout, formatspec, 1, 0, 0, dec2bin(0,nbits));
        end

        % actual pixel data
        % frame_valid = 1, line_valid = 1 
        for ipix = 1:size(meas,1)
            fprintf(fout, formatspec, 1, 1, 1, dec2bin(meas(ipix, iline, iframe), nbits));
            if mod(ipix, 10) == 0
                fprintf(fout, formatspec, 1, 1, 0, dec2bin(meas(ipix, iline, iframe), nbits));
            end
        end
    end
    
    % after all lines of a frame, wait for eof packet
    % frame_valid = 1, line_valid = 0
    for ii = 1:ncyc_btw_lines
        fprintf(fout, formatspec, 1, 0, 0, dec2bin(0,nbits));
    end

end

% after all frames, add some trailer
% frame_valid = 0
for ii = 1:ncyc_btw_frames
    fprintf(fout, formatspec, 0, 0, 0, dec2bin(0,nbits));
end

fclose(fout);


