function frame = getSynthFrame(imean, k2f, sz)

gain = 0.0956;
offset = 55;
grad_type = 'lin';

switch grad_type
    case 'lin'
        % linear intensity gradient (non-uniform mean image)
        frame = repmat(linspace(imean*1.02, imean*0.98, sz(2)), sz(1), 1);
    case 'dist'
        % gradient based on 1/distance from origin
        % should have similar variance to linear gradient
        origin = [-4400, -3250];
        [xi, yi] = ndgrid((1:sz(1))-origin(1), (1:sz(2))-origin(2));
        frame = 1./sqrt(xi.^2 + yi.^2);
        frame = frame/mean(frame(:)) * imean;
    case 'step'
        frame = ones(sz) * imean;
        midpnt = floor(sz(2)/2);
        frame(:,1:midpnt) = frame(:,1:midpnt)*1.05;
        frame(:,(midpnt+1):end) = frame(:,(midpnt+1):end)*0.95;
    otherwise % no gradient
        frame = ones(sz) * imean;
end

% speckle pattern
frame = random("Exponential", frame./gain*sqrt(k2f)) + frame./gain*(1-sqrt(k2f));

% speckle pattern with additional noise in k2f in one region of the image
% rndmult = 0.5+rand(1);
% frame(:,end-(0:63)) = random("Exponential", frame(:,end-(0:63))./gain*sqrt(k2f*rndmult)) + frame(:,end-(0:63))./gain*(1-sqrt(k2f*rndmult));
% frame(:,1:(end-64)) = random("Exponential", frame(:,1:(end-64))./gain*sqrt(k2f)) + frame(:,1:(end-64))./gain*(1-sqrt(k2f));

% frame(:,216+(0:63)) = random("Exponential", frame(:,216+(0:63))./gain*sqrt(k2f*rndmult)) + frame(:,216+(0:63))./gain*(1-sqrt(k2f*rndmult));
% frame(:,1:215) = random("Exponential", frame(:,1:215)./gain*sqrt(k2f)) + frame(:,1:215)./gain*(1-sqrt(k2f));
% frame(:,280:end) = random("Exponential", frame(:,280:end)./gain*sqrt(k2f)) + frame(:,280:end)./gain*(1-sqrt(k2f));

% frame(:,1:64) = random("Exponential", frame(:,1:64)./gain*sqrt(k2f*rndmult)) + frame(:,1:64)./gain*(1-sqrt(k2f*rndmult));
% frame(:,65:end) = random("Exponential", frame(:,65:end)./gain*sqrt(k2f)) + frame(:,65:end)./gain*(1-sqrt(k2f));

% frame(:,1:midpnt) = random("Exponential", frame(:,1:midpnt)./gain*sqrt(k2f*rndmult)) + frame(:,1:midpnt)./gain*(1-sqrt(k2f*rndmult));
% frame(:,(midpnt+1):end) = random("Exponential", frame(:,(midpnt+1):end)./gain*sqrt(k2f)) + frame(:,(midpnt+1):end)./gain*(1-sqrt(k2f));


% quantize to photoelectrons
frame = poissrnd(frame);

% apply gain and offset
frame = frame*gain + offset;

% apply read noise
frame = frame + random("Normal", 0, 1, sz);

% % additional testing noise
% frame(:,end-(1:50)) = frame(:,end-(1:50)) + random("Normal", 0, 100, [640 50]);

% quantize to digital levels ("counts")
frame = round(frame);

