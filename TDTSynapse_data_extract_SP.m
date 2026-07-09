%% clear workspace, add directories to MATLAB path
close all; clear all; clc;

% enter file path
blockpath = ''
data = TDTbin2mat(blockpath);

%set filename for saving everything at the end
filename = ''

%% pull variables
GCAMP = 'x470A';
ISOS = 'x405A';

%% set some pretty colors for plotting 
red = [0.8500, 0.3250, 0.0980];
green = [0.4660, 0.6740, 0.1880];
cyan = [0.3010, 0.7450, 0.9330];
gray1 = [.7 .7 .7];
gray2 = [.8 .8 .8];

%%  check raw signal

a = length(data.streams.(GCAMP).data);
b = length(data.streams.(ISOS).data);
if b <a
    data.streams.(GCAMP).data = data.streams.(GCAMP).data(1:b);
end 
time = (1:length(data.streams.(GCAMP).data))/data.streams.(GCAMP).fs;
figure('Position',[100, 100, 800, 400])
hold on;  
p1 = plot(time, data.streams.(GCAMP).data,'color',green,'LineWidth',1);
p2 = plot(time, data.streams.(ISOS).data,'color',cyan,'LineWidth',1);
title('Raw Demodulated Responses','fontsize',16);
ylabel('mV','fontsize',16);
axis tight;
legend([p1 p2], {'GCaMP','Isos'});


%% remove artifact at start
t = ; % time threshold below which we will discard
ind = find(time>t,1); % find first index of when time crosses threshold
time = time(ind:end); % reformat vector to only include allowed time
data.streams.(GCAMP).data = data.streams.(GCAMP).data(ind:end);
data.streams.(ISOS).data = data.streams.(ISOS).data(ind:end);

%replot
clf;
hold on;
p1 = plot(time, data.streams.(GCAMP).data,'color',green,'LineWidth',1);
p2 = plot(time, data.streams.(ISOS).data,'color',cyan,'LineWidth',1);
title('Raw Demodulated Responses with Artifact Removed','fontsize',16);
xlabel('Seconds','fontsize',16)
ylabel('mV','fontsize',16);
axis tight;
legend([p1 p2], {'GCaMP','ISOS'});

%% downsample 
N = ; % multiplicative for downsampling
data.streams.(GCAMP).data = arrayfun(@(i)...
    mean(data.streams.(GCAMP).data(i:i+N-1)),...
    1:N:length(data.streams.(GCAMP).data)-N+1);
data.streams.(ISOS).data = arrayfun(@(i)...
    mean(data.streams.(ISOS).data(i:i+N-1)),...
    1:N:length(data.streams.(ISOS).data)-N+1);

%decimate time array to match
time = time(1:N:end);
time = time(1:length(data.streams.(GCAMP).data));

%% fit 405 to 470 
bls = polyfit(data.streams.(ISOS).data,data.streams.(GCAMP).data,1);
Y_fit_all = bls(1) .* data.streams.(ISOS).data + bls(2);
Y_dF_all = data.streams.(GCAMP).data - Y_fit_all; %dF (units mV) is not dFF

dFF = 100*(Y_dF_all)./Y_fit_all; %calculate as percentage
std_dFF = std(double(dFF));

%replot to make sure all looks okay 
figure(2)
hold on;
p1 = plot(time, data.streams.(GCAMP).data,'color',green,'LineWidth',1);
p2 = plot(time, Y_dF_all, 'color','b','LineWidth',1);
p3 = plot(time, dFF, 'color','k' , 'LineWidth', 1); 
p4 = plot(time, Y_fit_all, 'color', gray1, 'LineWidth', 1)
title('Raw Demodulated Responses with Artifact Removed','fontsize',16);
xlabel('Seconds','fontsize',16)
ylabel('mV','fontsize',16);
axis tight;
legend([p1 p2 p3 p4], {'GCaMP','dF (not/F0)', 'df/f','fit405'});


%% Pull behavior stamps from digital I/O input

Beh_t = []; %put behavioral time stamps


         vid_len = %in case dropped frames
         tsratio = max(time)/ vid_len;
         Beh_t = Beh_t*tsratio;

figure(3)
hold on;
p1 = plot(time, dFF, 'color','k' , 'LineWidth', 1);;
p2 = xline(Beh_t,'color', 'r')
title('dF/F with behavior time stamps','fontsize',16);
xlabel('Seconds','fontsize',16)
ylabel('mV','fontsize',16);
axis tight;
legend([p2], {'Behavior Stamps'});


%% Make perievent hist
PRE_TIME = ; % ten seconds before event onset
POST_TIME = ; % ten seconds after
fs = data.streams.(GCAMP).fs/N; % must account for downsampling w/ N

% time span for peri-event filtering
TRANGE = [-1*PRE_TIME*floor(fs),POST_TIME*floor(fs)];

%preallocate matrices (makes faster)
trials = numel(Beh_t);
dFF_snips = cell(trials,1);
array_ind = zeros(trials,1);
pre_stim = zeros(trials,1);
post_stim = zeros(trials,1);

for i = 1:trials
    % If the bout cannot include pre-time seconds before event, make zero
    if Beh_t(i) < PRE_TIME
        dFF_snips{i} = single(zeros(1,(TRANGE(2)-TRANGE(1))));
        continue
    else
        % Find first time index after bout onset
        array_ind(i) = find(time > Beh_t(i),1);

        % Find index corresponding to pre and post stim durations
        pre_stim(i) = array_ind(i) + TRANGE(1);
        post_stim(i) = array_ind(i) + TRANGE(2);
        dFF_snips{i} = dFF(pre_stim(i):post_stim(i));
    end
end

% Make all snippets the same size based on minimum length
minLength = min(cellfun('prodofsize', dFF_snips));
dFF_snips = cellfun(@(x) x(1:minLength), dFF_snips, 'UniformOutput',false);

% Convert to a matrix and get mean
allSignals = cell2mat(dFF_snips);
mean_allSignals = mean(allSignals);
std_allSignals = std(mean_allSignals);

% Make a time vector snippet for peri-events
peri_time = (1:length(mean_allSignals))/fs - PRE_TIME;


% plotting
sem = std(allSignals,0,1)./sqrt(size(allSignals,1));

figure(5)

hold on
x = peri_time,10;
y = mean_allSignals;
eb = sem;
lineProps.col{1} = 'green';
mseb(x,y,eb,lineProps,1);

L = line([0 0],[-3 1]);
axis([-PRE_TIME POST_TIME min(mean_allSignals) max(mean_allSignals)])
ylim([-2 2.5])
set(L,'Color','black')
xlabel('Peri-Event Time (sec)')
ylabel('dF/F (%)')
hold off

figure(6)

hold on

imagesc(linspace(-PRE_TIME,POST_TIME,length(mean_allSignals)),1:size(allSignals,1),allSignals)
L = line([0 0],[0 size(allSignals,1)+1]);
set(L,'Color','black')
xlabel('Peri-Event Time (sec)')
ylabel('Trial Number')  
cb = colorbar;
title(cb,'dF/F')
caxis([-1 4])

colormap((brewermap([],'Reds')))
xlim([-PRE_TIME POST_TIME])
ylim([0 size(allSignals,1)+1])
hold off

%% save everything for further plotting

save (filename, 'data', 'time','Beh_t', 'peri_time', 'dFF_snips', 'allSignals', 'allSignals', 'mean_allSignals', 'std_allSignals', 'dFF');