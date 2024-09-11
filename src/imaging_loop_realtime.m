%% Initialize DAQ and declare variables
clear all; clc; close all;
global data
global t
global nx
global ny
global DAQ
global nSamps
global loggingImages
global loggingData
global filename
global collectionDate
global dataPath
global fitobj
global fs

loggingImages = 0;
loggingData = 0;
dataPath = 'T:\Projects\WilsonGroup\InsightLaser\DataCollectionArya\CollectedData\';
collectionDate = datestr(now, 'yyyymmdd');
dataPath = append(dataPath, collectionDate, '\');
mkdir([dataPath]);

if ~contains(path,'gridbin')
    addpath('T:\Projects\WilsonGroup\TuCo\software\gridbin');
end

DAQ = daq.createSession('ni');
DAQ.addAnalogInputChannel('PXI1Slot6', 'ai6', 'Voltage'); % RCM photodiode connected to ai6
DAQ.addAnalogInputChannel('PXI1Slot6', 'ai1', 'Voltage'); % galvo x
DAQ.addAnalogInputChannel('PXI1Slot6', 'ai2', 'Voltage'); % galvo y
DAQ.addTriggerConnection('External','PXI1Slot6/PFI0','StartTrigger');
DAQ.Connections.TriggerCondition = 'RisingEdge';
%DAQ.NumberOfScans = 35e3;
DAQ.Rate = 0.5e6;
DAQ.DurationInSeconds = 0.45; % (Y galvo is 2 Hz frame rate)
nSamps = DAQ.DurationInSeconds*DAQ.Rate;
DAQ.NotifyWhenDataAvailableExceeds = nSamps; % grab a whole frame before running callback
DAQ.IsContinuous = true;
lh = DAQ.addlistener('DataAvailable',@AcqData);

t = (1 / DAQ.Rate)*(1:nSamps);
fs = DAQ.Rate;

%% image loop parameters
nx = 128;
ny = 128;

% fitting routine to calculate the correct x_shift
x_fov = 0.6; % initial guess for x scan range of FOV

% calibration table for RCM channel
x_shift_table = [1.3033e-05, 1.3333e-05, 1.2733e-05, 1.2433e-05, 1.2433e-05, 1.2133e-05, 1.1833e-05, 1.1533e-05, 1.1533e-05, 1.1233e-05, 1.0933e-05, 1.0633e-05];

ft = fittype('A + B*x','independent','x');

% for RCM channel
x_range_rcm = linspace(0.2,2.6,12);
fitobj = fit(x_range_rcm.', x_shift_table.', ft);

x_shift = fitobj(x_fov);

figure(2);
clf;
hImageObj = imagesc(0, 0, 0);
colorbar();
colormap(gray);
% caxis([-.2 0.1]); % color axis limit for pump-probe channel
set(hImageObj,'tag','imageObj');
set(gca,'Position',[.114,.250,.6796,.73])
xlabel('X (V)')
ylabel('Y (V)')
axis image

hStopButton = uicontrol('Style','togglebutton',...
    'String','Stop','Callback',@stopCallback);

hXshift = uicontrol('Style','slider',...
    'Value',x_shift,'Max',3e-5,'Min',0,'SliderStep',[0.01,0.1],...
    'Position',[20,40,300,20],'tag','xshift',...
    'Callback',@xShiftSliderCallback);

hXshiftEdt = uicontrol('Style','edit',...
    'String',num2str(x_shift),...
    'Position',[320,40,80,20],'tag','xshift_edt',...
    'Callback',@xShiftEdtCallback);

hAutoPhase = uicontrol('Style','togglebutton',...
    'String','Automatic Phase','Callback',@autoPhaseCallback,...
    'Position',[300,20,100,20],'tag','auto_phase_toggle');

hcbAverage = uicontrol('Style','checkbox',...
    'Value',0,'Position',[420,40,75,20],'String','Average','tag','cb_average');

hLogData = uicontrol('Style','togglebutton',...
    'String','Log Raw Data','Callback',@logRawDataCallback,'position',[420,60,75,20],'Value',0);

%%
DAQ.startBackground();
while DAQ.IsRunning
    pause(1);
end

%%
function AcqData(src,event)
    global data 
    global t
    global fs
    global nx
    global ny
    global loggingImages
    global loggingData
    global logFrameCount
    global filename
    global dataPath
    global collectionDate
    global fitobj
    global use_autoPhase
    persistent x_shift
    persistent mon_x_shifted
    persistent xq
    persistent yq
    persistent xq_vec
    persistent yq_vec
    persistent theImage

    data = event.Data;
    
    signal = data(:,1)';
    mon_x = data(:,2)';
    mon_y = data(:,3)';
    
    if use_autoPhase
        x_fov = max(xq_vec) - min(xq_vec);
        x_shift = fitobj(x_fov);
    else    
        x_shift = findobj('tag','xshift').Value;
    end
    
    average = findobj('tag','cb_average').Value;
    
    % adjust phase of x monitor signal
    mon_x_shifted = interp1(t,mon_x,t-x_shift,'linear','extrap');
    
    % grid data onto regularly-sampled x, y (form an image)
    xq_vec = linspace(min(mon_x), max(mon_x), nx);
    yq_vec = linspace(min(mon_y), max(mon_y), ny);
    [xq,yq] = meshgrid(xq_vec, yq_vec);
    

    % display the gridded image
    tic
    gridded = gridbin(mon_x_shifted, mon_y, signal, xq, yq);
    gridded(isnan(gridded)) = 0;
    if average
        alpha = 0.01;
        theImage = (1-alpha)*theImage + alpha*gridded;
    else
        theImage = gridded;
    end
    
    if loggingData
        % write raw data to .mat
        % write mon_x, mon_y, and signal        
        mon_x_varname = sprintf("mon_x_%04i",logFrameCount);
        mon_y_varname = sprintf("mon_y_%04i",logFrameCount);
        signal_varname = sprintf("signal_%04i",logFrameCount);
        logFrameCount = logFrameCount + 1;
        eval(join([mon_x_varname," = mon_x;"]));
        eval(join([mon_y_varname," = mon_y;"]));
        eval(join([signal_varname," = signal;"]));
        
        if logFrameCount == 1
            nFrames = logFrameCount;
            save(filename, mon_x_varname, mon_y_varname, signal_varname, "t", "x_shift", "fs", "nFrames");
        else
            nFrames = logFrameCount; 
            save(filename, mon_x_varname, mon_y_varname, signal_varname,'-append', "nFrames");
        end
    end    
    toc
    % update display
    set(findobj('tag','imageObj'),'Xdata',xq_vec,'YData',yq_vec,'CData',theImage);    
    drawnow;
    
end

%%
function stopCallback(src,event)
    global DAQ    
    DAQ.stop()
    disp('Imaging Stopped')
end

function xShiftSliderCallback(src,event)
    global x_shift
    x_shift = src.Value;
    set(findobj('tag','xshift_edt'),'String',num2str(x_shift));
    
end

function xShiftEdtCallback(src,event)
    global x_shift    
    val = str2num(src.String);
    if ~isempty(val)
       x_shift = val;
       set(findobj('tag','xshift'),'Value',x_shift);
    else
        set(src,'String',num2str(x_shift));
    end
end

function autoPhaseCallback(src,event)
    global use_autoPhase
    val = src.Value;
    if val==1
        % set for auto-phase adjust
        set(findobj(gcf,'tag','xshift'),'enable','off');
        set(findobj(gcf,'tag','xshift_edt'),'enable','off');
        use_autoPhase = true;
        
    elseif val==0
        % set for manual phase adjust
        set(findobj(gcf,'tag','xshift'),'enable','on');
        set(findobj(gcf,'tag','xshift_edt'),'enable','on');
        use_autoPhase=false;
    else
        error('invalid value for auto phase toggle button');
        
    end
end
    
function logRawDataCallback(src, event)
    global filename
    global loggingData
    global logFrameCount
    global dataPath
    global collectionDate
    global ny
    global nx
    
    if src.Value
        % open a tif file, store the handle to global
        filename = append(dataPath, datestr(now,'yyyymmdd_HH_MM_SS'), '.mat');
        logFrameCount = 0;
        fprintf('logging images to %s\n', filename);              
        loggingData = 1;           
    else
        loggingData = 0;        
        disp('data logging stopped')
    end
end
    