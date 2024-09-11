%% 2024-01-09  William A. Hudson
%
% Raster scan galvanometer.
% Generate an output waveform data set, and read back the corresponding
% input data set from PSD and Photodetector.
% Assumptions:
%    X galvo is fast scan, sine wave.
%    Y galvo is slow scan, triangle wave.
%    Galvo position voltage is +- about zero.  Both start at zero at time 0.

%% DAQ configuration
    % addoutput/addinput order is column order in data matrix

    % construct DataAcquisition object
    dq = daq( 'ni' );

    % output channels for piezo drive signals
    chOutX = addoutput( dq, 'Dev1', 'ao0', 'Voltage' );
    chOutY = addoutput( dq, 'Dev1', 'ao1', 'Voltage' );

    % input channel from photodetector
    chInSig = addinput( dq, 'Dev1', 'ai1', 'Voltage' ); % Intensity Signal

    % input channels from PSD
 %  chInSum = addinput( dq, 'Dev1', 'ai2', 'Voltage' ); % PSD Sum Pin Signal
 %  chInX   = addinput( dq, 'Dev1', 'ai3', 'Voltage' ); % PSD X Pin Signal
 %  chInY   = addinput( dq, 'Dev1', 'ai5', 'Voltage' ); % PSD Y Pin Signal

 %  chInX.Range = [-5,5];
 %  chInY.Range = [-5,5];

    % DAQ sample rate
    dq.Rate  = 62500;		% set samples per second
    sampRate = dq.Rate;

    
%% Parameters

    FreqX_Hz   = 150;		% fast scan sine wave
    LineCycY_n = 200 * 2;	% number of X cycles in ramp cycle
    FrameCnt_n = 1;		% number of frames (Y ramp cycles)

%   FreqX_Hz   = 6250;		% DEBUG - 10 samples per cycle
%   LineCycY_n = 4 * 2;

    totalTime_s = FrameCnt_n * LineCycY_n / FreqX_Hz;
    totalSamp_n = totalTime_s * sampRate;

    OutAmpX_V = 1.0;		% output amplitude, sine wave voltage peak
    OutAmpY_V = 1.0;		% output amplude, ramp voltage peak

    Ofile = "07112024_leaf1a_obj5x.txt";		% output data file name3

    % pi = 3.14159;

    fprintf( 'FreqX_Hz      = %10.3f\n', FreqX_Hz      );
    fprintf( 'LineCycY_n    = %10.3f\n', LineCycY_n    );
    fprintf( 'FrameCnt_n    = %10.3f\n', FrameCnt_n    );
    fprintf( 'OutAmpX_V     = %10.3f\n', OutAmpX_V     );
    fprintf( 'OutAmpY_V     = %10.3f\n', OutAmpY_V     );
    fprintf( 'totalTime_s   = %10.3f\n', totalTime_s   );
    fprintf( 'totalSamp_n   = %10d\n',   totalSamp_n   );

%% Y Waveform (slow triangle wave)

    % sample interval from DAQ sample rate
    dt_s = 1 / sampRate;

    periodX_s = 1 / FreqX_Hz;			% period of one X sine cycle
    periodY_s = periodX_s * LineCycY_n;		% period of one Y ramp cycle

    quarterY_s = periodY_s / 4;			% quarter ramp cycle
    quarterY_n = quarterY_s / dt_s;

    dY_V = OutAmpY_V / quarterY_n ;		% Y ramp increment

    % vector segments of Y ramp cycle
    A = [          0 :  dY_V : ( OutAmpY_V - dY_V ) ];
    B = [  OutAmpY_V : -dY_V : (-OutAmpY_V + dY_V ) ];
    C = [ -OutAmpY_V :  dY_V : ( 0         - dY_V ) ];

    % Note parameters are all floating point.  Number of samples in each
    % ramp segment may vary due to rounding.  Good enough for initial use.
    
    offsetY = 0;
    outVecY = offsetY + [A B C];		% concatenate row vectors

    n = 1;
    while ( n < FrameCnt_n )	% add ramp cycles to fill out frame
	n = n + 1;
	outVecY = [outVecY A B C];
    end

    lengthY_n = length( outVecY );

    nsampX_n = periodX_s / dt_s;

%% X Waveform (fast sine wave)

    lengthX_n = lengthY_n;

    % vector of time values
    tVec_s = (0:(lengthX_n - 1)) * dt_s;

    wX = 2 * pi * FreqX_Hz;		% radian frequency

    offsetX= 0; 
    outVecX =  offsetX + OutAmpX_V * sin( wX * tVec_s );

    fprintf( 'sampRate      = %12.4e\n', sampRate      );
    fprintf( 'dt_s          = %12.4e\n', dt_s          );
    fprintf( 'periodX_s     = %12.4e\n', periodX_s     );
    fprintf( 'periodY_s     = %12.4e\n', periodY_s     );
    fprintf( 'quarterY_s    = %12.4e\n', quarterY_s    );
    fprintf( 'quarterY_n    = %10d\n',   quarterY_n    );
    fprintf( 'dY_V          = %12.4e\n', dY_V          );
    fprintf( 'lengthY_n     = %10d\n',   lengthY_n     );
    fprintf( 'nsampX_n      = %10.3f\n', nsampX_n      );

%% Run the DAQ

    outScanData = [transpose( outVecX ), transpose( outVecY )];
	    % transpose into column vectors, then concatenate rows

    inScanData = readwrite( dq, outScanData, "OutputFormat","Matrix" );

    allScanData = [ inScanData, outScanData ];

    % Range of chInSig, first column of inScanData
    sigMax_V = max( allScanData(:,1) );
    sigMin_V = min( allScanData(:,1) );
    fprintf( 'sigMax_V      = %10.3f\n', sigMax_V      );
    fprintf( 'sigMin_V      = %10.3f\n', sigMin_V      );

    fprintf( 'Ofile         = %s\n', Ofile );

    save( Ofile, 'allScanData', '-ascii' );

 %% Plot using gridbin command

% Load data from file
data = dlmread(Ofile);
%data = dlmread('03212024_NewSys_PSD_At4.70.txt');


% Extract columns from the data
outVecX_GB = data(:, 3); % Assuming the first column contains X coordinates
outVecY_GB = data(:, 2); % Assuming the second column contains Y coordinates
inScanData = data(:, 1); % Assuming the third column contains intensity data

% Define the vectors for grid generation
xqvec = linspace(min(outVecX_GB), max(outVecX_GB), 256); % Adjust the number of points as necessary
yqvec = linspace(min(outVecY_GB), max(outVecY_GB), 256); % Adjust the number of points as necessary

% Create a grid
[xq, yq] = meshgrid(xqvec, yqvec);

% Use gridbin to interpolate the data onto the grid
%vq = gridbin(outVecX_GB, outVecY_GB, inScanData, xq, yq);

% Plot the interpolated data
% imagesc(xqvec, yqvec, vq');
% xlabel('X Coordinate');
% ylabel('Y Coordinate');
% title('Interpolated Data (BID Test 1)');

% Test shifting and re-interpolation
% for ishift = 1:1:20
% for ishift = 10
%    % outVecX_shift = circshift(outVecX_GB, ishift);
%    % vq_shifted = gridbin(outVecX_shift, outVecY_GB, inScanData, xq, yq);
%     outVecY_shift = circshift(outVecY_GB, ishift);
%     vq_shifted = gridbin(outVecX_GB, outVecY_shift, inScanData, xq, yq);
%     % Plot shifted and interpolated data
%     figure;
%     imagesc(xqvec, yqvec, vq_shifted');
%     xlabel('X Coordinate');
%     ylabel('Y Coordinate');
%     title(['GB Shifted and Interpolated Data (Shift = ' num2str(ishift) ')']);
%     colormap("gray");
%     drawnow;
% end

% Region Fill
%filled = regionfill(vq_shifted, isnan(vq_shifted)); % Assuming vq_shifted is the data to be filled
%figure; 
%imagesc(xqvec, yqvec, filled');
%xlabel('X Coordinate');
%ylabel('Y Coordinate');
%title('GB Plot');
%colormap("gray");

 %%
x_store=outVecX;
x_store=x_store(diff(outVecX)>0);

y_store=outVecY;
y_store=y_store(diff(outVecX)>0);

int_store=inScanData;
int_store=int_store(diff(outVecX)>0);

xqvec_store = linspace(min(x_store), max(x_store), 200); % Adjust the number of points as necessary
yqvec_store = linspace(min(y_store), max(y_store), 200); % Adjust the number of points as necessary

[xq_store, yq_store] = meshgrid(xqvec_store, yqvec_store);
%vq_store = gridbin(x_store, y_store, int_store', xq_store, yq_store);

 
%  figure;
% imagesc(xqvec_store, yqvec_store, vq_store);
% colormap("gray");
% title('forward Scan')

%% Scatter forward
% figure;
% s= scatter(x_store,-y_store,[],int_store,"filled");
% title("scatterforward")
%  colormap("gray"); 
%% Scatter bidirectional
% figure;
% scatter(outVecX,-outVecY,[],inScanData,"filled");
% title("Scatter bidirectional")
% colormap("gray");
%% Shifted scatter
%  figure;
% i=9;
%     outVecX_shift=circshift(outVecX,i);
% scatter(outVecX_shift,-outVecY,[],inScanData,"filled");
% title("Shifted scatter")
% colormap("gray");
%% Scatter Interpolant
xmesh_vec=linspace(min(x_store),max(x_store),512);
ymesh_vec=linspace(min(y_store),max(y_store),512);
[x_mesh,y_mesh]=meshgrid(xmesh_vec,ymesh_vec);
 F = scatteredInterpolant(transpose(x_store),transpose(y_store),int_store,'linear');
 grid_int=F(x_mesh,y_mesh);


figure;
%h=pcolor(x_mesh,-y_mesh,grid_int);
imagesc(xmesh_vec,ymesh_vec,grid_int);
%set(h, 'LineStyle', 'none');
title("Scatter interpolant Plot");
colormap("gray")
clim([0.005,.1]);
%clim(10*[-1,1]*var(grid_int(:))+mean(grid_int(:)))
% clim([min(int_store),max(int_store)]);
% xline(0);
%% 
% figure;
% h=pcolor(x_mesh,-y_mesh,grid_int);
% set(h, 'LineStyle', 'none');
% title("pcolor Plot");
% colormap("gray")
%  clim([min(int_store),max(int_store)]);
 %% 
 % vq_interp=interp2(vq_store,3);
 % figure;
 % imagesc(xqvec_store,yqvec_store,vq_interp)
 % colormap("gray")
 % title("Interpolated Image");
