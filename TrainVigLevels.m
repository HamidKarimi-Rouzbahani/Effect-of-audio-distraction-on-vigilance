function TrainVigLevels(Subj)
% Screen('Preference', 'SkipSyncTests',1);
% developed by Hamid Karimi-Rouzbahani on 23/March/2022
commandwindow;
rng('default')
if ~IsOctave
    commandwindow;
else
    more off;
end
% General parameters
% Eye-tracker, MEG and Screen parameters
Eye_tracking=0; % 1= collect eye-tracking data; 0= no eye-tracking data
photodiode= 0; % 1= photodiode trigger appears; 0= photodiode trigger does not appear
MEG =0;        % 1= send MEG triggers; 0= do not send triggers
p.triggernums = 178:183;                        % Trigger numbers for the experiment
p.trigger_duration = 0.01;                      % Trigger duration in seconds

testing_screen_size=[]; % in pixels or [] for the whole screen

% Timing parameters
refresh_rate=60; % All the following timing paramteres are calcaulted relative to refresh rate e.g.,
% when refresh rate is set to 60 Hz, 30 means 0.5 second
trial_length=200; % length of a single dot movement on the screen
Trials_per_block=32; % number of trials/dots shown from each side of the screen
distance_between_dots_limit=round(trial_length./10);
distance_between_events_limit=randsample([fix(trial_length./6) fix(trial_length./5)],1);
refractory_time=30; % time between button presses which is excluded to avoid spuruous button presses
post_defl_refractory_time=15; % time after deflection which the user can not press button to avoid confusion
fading_time=20; % time it takes for the stimulus to fade
Break_time=2; % time interval at the end of block
non_target_time_gap_constant=0.2494; % time between non-target dots


SaveMovie=0; % whether to save the screen as a movie (1) or not (0)
SaveAudio=0; % whether to save audio file during each block (1) or not (0)
Fs=44100; % sound sampling freq
Audio_quality=16; % 8, 16, or 24
Mono_Stereo=2;  % mono=1; sterio =2
length_of_recording=(Trials_per_block+1)*trial_length/60; % length of recording in block

% Task parameters
percentage_target_cond=[0.5]; % Frequency of targets across conditions
% the length of this vector also determines how many (target frequency)
% conditions you will have
proportion_of_events=0.5; % You do not need to change this
Blocks_per_condition=2; % Number of blocks per target frequency condition

% Stimulus appearance parameters
first_dot_colour=[255 0 0]; % left to right: red green and blue (0 to 255 each)
second_dot_colour=[0 0 255]; % left to right: red green and blue (0 to 255 each)
distance_of_consideration=600; % from what distance (pixel) are the trajectories and dots displayed
moving_dots_radius=10;         % in pixels
obstacle_radius=20;  % in pixels
boundary_radius = 100; % in pixels
x_boundary=330;  % do not need to change this parameter
Num_moving_dots=2; % do not need to change this parameter



Num_of_conditions=length(percentage_target_cond);
Sets_of_subjects=200; % how many groups of subjects do you want to repeat all the conditions for?
% Generating counter-balanced blocks in terms of frequency conditions and cued colours
conds_perm=repmat(perms([1:Num_of_conditions]),[Sets_of_subjects 1]);
Block_condition=nan(size(conds_perm,1),Num_of_conditions*Blocks_per_condition);
Cued_color_in_block=ones(size(conds_perm,1),Num_of_conditions*Blocks_per_condition);
for subj=1:size(conds_perm,1)
    for cond=1:Num_of_conditions
        blk_inds_of_currnt_cond=(cond-1)*Blocks_per_condition+1:cond*Blocks_per_condition;
        Block_condition(subj,blk_inds_of_currnt_cond)=repmat(conds_perm(subj,cond),[1 Blocks_per_condition]);
        if length(blk_inds_of_currnt_cond)>1
            indices_to_make_zero=randsample(blk_inds_of_currnt_cond,round(size(blk_inds_of_currnt_cond,2)./2));
            Cued_color_in_block(subj,indices_to_make_zero)=0;
        else
            Cued_color_in_block(subj,blk_inds_of_currnt_cond)=randi([0 1],1);
        end
    end
end
%% Actual code starts here
try
    %% Open i/o port
    if MEG
        % Create io64 interface object
        try
            p.ioObj = io64;
            % check the port status
            status = io64(p.ioObj);
        catch e
            status = 1;
            disp(['Failed to open io64: ' e.message])
        end
    else
        status = 1;
    end
    if status == 0
        p.address = hex2dec('DFB8'); %stim2
        % p.address = hex2dec('D020'); %stim1
        display(['Functioning parallel port opened at: ' num2str(p.address)])
    else
        p.ioObj = [];
        p.address = [];
    end
    
    screenNumber=max(Screen('Screens'));
    
    if Eye_tracking
        % STEP 1
        % Added a dialog box to set your own EDF file name before opening
        % experiment graphics. Make sure the entered EDF file name is 1 to 8
        % characters in length and only numbers or letters are allowed.
        prompt = {'Enter tracker EDF file name (1 to 8 letters or numbers)'};
        dlg_title = 'Create EDF file';
        num_lines= 1;
        def     = {'DEMO'};
        answer  = inputdlg(prompt,dlg_title,num_lines,def);
        edfFile = answer{1};
        fprintf('EDFFile: %s\n', edfFile );
        
        % STEP 2
        % Open a graphics window on the main screen
        % using the PsychToolbox's Screen function.
        [wpoint, wRect]=Screen('OpenWindow', screenNumber, 0,testing_screen_size,32,2);
        Screen(wpoint,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        % end
        %     if Eye_tracking
        % STEP 3
        % Provide Eyelink with details about the graphics environment
        % and perform some initializations. The information is returned
        % in a structure that also contains useful defaults
        % and control codes (e.g. tracker state bit and Eyelink key values).
        el=EyelinkInitDefaults(wpoint);
        
        dummymode=0;
        % STEP 4
        % Initialization of the connection with the Eyelink Gazetracker.
        % exit program if this fails.
        if ~EyelinkInit(dummymode)
            fprintf('Eyelink Init aborted.\n');
            cleanup;  % cleanup function
            return;
        end
        [v,vs]=Eyelink('GetTrackerVersion');
        fprintf('Running experiment on a ''%s'' tracker.\n', vs );
        
        % open file to record data to
        i = Eyelink('Openfile', edfFile);
        if i~=0
            fprintf('Cannot create EDF file ''%s'' ', edffilename);
            cleanup;
            %         Eyelink( 'Shutdown');
            return;
        end
        
        Eyelink('command', 'add_file_preamble_text ''Recorded by EyelinkToolbox demo-experiment''');
        [width, height]=Screen('WindowSize', screenNumber);
        
        
        % STEP 5
        % SET UP TRACKER CONFIGURATION
        % Setting the proper recording resolution, proper calibration type,
        % as well as the data file content;
        Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', 0, 0, width-1, height-1);
        Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, width-1, height-1);
        % set calibration type.
        Eyelink('command', 'calibration_type = HV9');
        % set parser (conservative saccade thresholds)
        Eyelink('command', 'saccade_velocity_threshold = 35');
        Eyelink('command', 'saccade_acceleration_threshold = 9500');
        
        % remote mode possible add HTARGET ( head target)
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT,HTARGET');
        % set link data (used for gaze cursor)
        Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT,FIXUPDATE');
        Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT,HTARGET');
        
        % allow to use the big button on the eyelink gamepad to accept the
        % calibration/drift correction target
        Eyelink('command', 'button_function 5 "accept_target_fixation"');
        
        % Tell the Eyelink to send a fixation update every 50 ms
        Eyelink('command', 'fixation_update_interval = %d', 50);
        Eyelink('command', 'fixation_update_accumulate = %d', 50);
        
        % make sure we're still connected.
        if Eyelink('IsConnected')~=1
            cleanup;
            return;
        end
        
        % STEP 6
        % Calibrate the eye tracker
        % setup the proper calibration foreground and background colors
        el.backgroundcolour = 128;
        el.foregroundcolour = 0;
        % Hide the mouse cursor;
        Screen('HideCursorHelper', wpoint);
        EyelinkDoTrackerSetup(el);
        
        %% STEP 7 Main expt
        % Now starts running individual trials;
        % You can keep the rest of the code except for the implementation
        % of graphics and event monitoring
        % Each trial should have a pair of "StartRecording" and "StopRecording"
        % calls as well integration messages to the data file (message to mark
        % the time of critical events and the image/interest area/condition
        % information for the trial)
    end
    
    for Block_Num=1:Num_of_conditions*Blocks_per_condition
        percentage_target=percentage_target_cond(1,Block_condition(24,Block_Num));
        Condition_string=['Freq_',sprintf('%.2f', percentage_target)];
        
        if Block_Num==1
            background_colour=0;
            [wpoint, wRect]=Screen('OpenWindow',screenNumber,background_colour,testing_screen_size);
            if SaveMovie==1
                movie = Screen('CreateMovie', wpoint, 'MyTestMovie.mov', wRect(3), wRect(4), refresh_rate, ':CodecSettings=Videoquality=0.05 Profile=2');
            end
            Screen('TextSize',wpoint, 18);
            HideCursor;
            KbCheck;
            WaitSecs(0.1);
            GetSecs;
            
            priorityLevel=MaxPriority(wpoint);
            Priority(priorityLevel);
            
            % Instructions
            Screen('TextSize',wpoint, 22);
            str=sprintf(['...  Practice  ...']);
            message = [str '\n\n\n\n ... STOP the dots hitting the static object  ...'...
                '\n\n\n\n ... the dots usually follow their trajectories ...'...
                '\n\n\n\n ... press the button WHEN they do not !!!  ...'...
                '\n\n\n\n ... you have ONLY ONE button press for each dot  ...'...
                '\n\n\n\n ... dots are in two colors: you will be told which color to protect  ...'...
                '\n\n\n\n ... look at the central object ALL THE TIME  ...'];
            DrawFormattedText(wpoint, message,'center','center',WhiteIndex(wpoint));
            Screen('Flip', wpoint ,0);
            GetClicks(wpoint);
            beepStart;
        end
        
        Screen('TextSize',wpoint, 30);
        if Cued_color_in_block(Subj,Block_Num)==1
            target_color='RED';
            block_target_color=1;
            message = ['\n\n\n\n\n ---  Respond to ',target_color, ' dots  ---\n\n\n\n\n Press the button to start !!! \n\n\n\n\n'];
            DrawFormattedText(wpoint, message,'center','center',first_dot_colour);
        else
            target_color='BLUE';
            block_target_color=0;
            message = ['\n\n\n\n\n ---  Respond to ',target_color, ' dots  ---\n\n\n\n\n Press the button to start !!! \n\n\n\n\n'];
            DrawFormattedText(wpoint, message,'center','center',second_dot_colour);
        end
        Screen('Flip', wpoint ,0);
        if Block_Num == 1
            while 1
                [~, keycode] = KbWait();
                response_button = KbName(keycode);
                if any(keycode)
                    break;
                end
            end
        else
            while 1
                [~, keycode] = KbWait();
                if keycode(KbName(response_button))
                    break;
                end
            end
        end
        WaitSecs(0.5);
        Screen('Flip',wpoint);
        
        obstacle_xposition1=wRect(3)./2;
        obstacle_yposition1=wRect(4)./2;
        
        Obstacle_1 = [obstacle_xposition1-obstacle_radius, obstacle_yposition1-obstacle_radius, obstacle_xposition1+obstacle_radius, obstacle_yposition1+obstacle_radius];
        a_Obstacle_1=obstacle_yposition1./obstacle_xposition1;
        
        
        
        hitting_border_distance=boundary_radius+moving_dots_radius;
        hitting_obstacle_distance=obstacle_radius+moving_dots_radius;
        
        for y=1:obstacle_yposition1
            x=round(y/a_Obstacle_1);
            if round(sqrt(x.^2+y.^2))>hitting_obstacle_distance
                x_vertical_up_1=obstacle_xposition1+y;
                y_vertical_up_1=obstacle_yposition1-x;
                x_hit_boundary_1=obstacle_xposition1-x;
                break;
            end
        end
        a_vertical_up_1=y_vertical_up_1./x_vertical_up_1;
        x_vertical_down_1=obstacle_xposition1-(x_vertical_up_1-obstacle_xposition1);
        y_vertical_down_1=obstacle_yposition1-(y_vertical_up_1-obstacle_yposition1);
        a_vertical_down_1=y_vertical_down_1./x_vertical_down_1;
        
        
        defl_direction=zeros(1,Num_moving_dots*Trials_per_block);
        defl_direction(randsample([1:length(defl_direction)],length(defl_direction)./2))=1;
        defl_direction2=zeros(1,Num_moving_dots*Trials_per_block);
        defl_direction2(randsample([1:length(defl_direction2)],length(defl_direction2)./2))=1;
        
        
        bias_to_ensure=(a_vertical_down_1-a_vertical_up_1).*0.1;
        
        trial_of_targets=zeros(1,Trials_per_block);
        inds_targs=randsample(Trials_per_block,ceil(Trials_per_block*percentage_target));
        trial_of_targets(1,inds_targs)=1;
        
        top_targets=nan*ones(round(proportion_of_events.*Num_moving_dots),Trials_per_block);
        for trial=1:Trials_per_block
            % generating indices of all event dots
            a=zeros(1,Num_moving_dots);
            index_of_event_dots=randperm(Num_moving_dots,round(proportion_of_events.*Num_moving_dots));
            
            % generating top event dots
            number_of_events=round(length(index_of_event_dots));
            if mod(trial,2)
                a(index_of_event_dots(1:number_of_events))=randsample([a_vertical_up_1+bias_to_ensure:0.006:a_vertical_up_1+2*bias_to_ensure],round(length(index_of_event_dots)));
            else
                a(index_of_event_dots(1:number_of_events))=randsample([a_vertical_down_1-2*bias_to_ensure:0.006:a_vertical_down_1-bias_to_ensure],round(length(index_of_event_dots)));
            end
            top_events(:,trial)=index_of_event_dots;
            
            if trial_of_targets(1,trial)>0
                tmp=index_of_event_dots(1:number_of_events);
                index_of_target_dots=tmp(randperm(length(tmp),round(length(tmp).*trial_of_targets(1,trial))));
                top_targets(:,trial)=index_of_target_dots;
            else
                top_targets(:,trial)=0;
            end
            
            % generating non-target dots
            tmp_a=[non_target_time_gap_constant*10000:fix((a_vertical_up_1-bias_to_ensure)*10000) fix((a_vertical_down_1+bias_to_ensure)*10000):(1*10000)];
            ind=(find(a==0));
            a(ind(1:round(length(ind))))=randsample(tmp_a,round((1-proportion_of_events).*Num_moving_dots))./10000;               % y=ax+b
            a_original(:,trial)=a;
        end
        a=a_original;
        
        
        trial_of_targets2=zeros(1,Trials_per_block);
        inds_targs=randsample(Trials_per_block,ceil(Trials_per_block*percentage_target));
        trial_of_targets2(1,inds_targs)=1;
        
        top_targets2=nan*ones(round(proportion_of_events.*Num_moving_dots),Trials_per_block);
        for trial=1:Trials_per_block
            % generating indices of all event dots
            a2=zeros(1,Num_moving_dots);
            index_of_event_dots=randperm(Num_moving_dots,round(proportion_of_events.*Num_moving_dots));
            
            % generating top event dots
            number_of_events=round(length(index_of_event_dots));
            if mod(trial,2)
                a2(index_of_event_dots(1:number_of_events))=randsample([a_vertical_up_1+bias_to_ensure:0.006:a_vertical_up_1+2*bias_to_ensure],round(length(index_of_event_dots)));
            else
                a2(index_of_event_dots(1:number_of_events))=randsample([a_vertical_down_1-2*bias_to_ensure:0.006:a_vertical_down_1-bias_to_ensure],round(length(index_of_event_dots)));
            end
            top_events2(:,trial)=index_of_event_dots;
            
            if trial_of_targets2(1,trial)>0
                tmp=index_of_event_dots(1:number_of_events);
                index_of_target_dots=tmp(randperm(length(tmp),round(length(tmp).*trial_of_targets2(1,trial))));
                top_targets2(:,trial)=index_of_target_dots(1:length(index_of_target_dots));
            else
                top_targets2(:,trial)=0;
            end
            
            % generating non-target dots
            tmp_a=[non_target_time_gap_constant*10000:fix((a_vertical_up_1-bias_to_ensure)*10000) fix((a_vertical_down_1+bias_to_ensure)*10000):(1*10000)];
            ind=(find(a2==0));
            a2(ind(1:round(length(ind))))=randsample(tmp_a,round((1-proportion_of_events).*Num_moving_dots))./10000;               % y=ax+b
            a_original2(:,trial)=a2;
        end
        a2=a_original2;
        
        
        inds_targ=zeros(Num_moving_dots,Trials_per_block);
        dot_color=nan*ones(Num_moving_dots,Trials_per_block);
        for i=1:Trials_per_block
            if top_targets(i)>0
                inds_targ(top_targets(i),i)=1;
            end
        end
        first_color_inds=randsample(find(inds_targ),sum(sum(inds_targ)./2));
        dot_color(first_color_inds)=1;
        inds_targ(first_color_inds)=nan;
        second_color_inds=find(inds_targ==1);
        dot_color(second_color_inds)=0;
        dot_color(randsample(find(isnan(dot_color)),nansum(nansum(isnan(dot_color)))./2))=1;
        dot_color(isnan(dot_color))=0;
        
        inds_targ2=zeros(Num_moving_dots,Trials_per_block);
        dot_color2=nan*ones(Num_moving_dots,Trials_per_block);
        for i=1:Trials_per_block
            if top_targets2(i)>0
                inds_targ2(top_targets2(i),i)=1;
            end
        end
        first_color_inds2=randsample(find(inds_targ2==1),sum(sum(inds_targ2)./2));
        dot_color2(first_color_inds2)=1;
        inds_targ2(first_color_inds2)=nan;
        second_color_inds2=find(inds_targ2==1);
        dot_color2(second_color_inds2)=0;
        dot_color2(randsample(find(isnan(dot_color2)),nansum(nansum(isnan(dot_color2)))./2))=1;
        dot_color2(isnan(dot_color2))=0;
        
        
        % Shuffling of trajectories as many times to get the highest distance between
        % consecutive events
        modified_a_events_t=zeros(2*Trials_per_block,500);
        for i=1:Trials_per_block
            a_events(1,i)=a(top_events(i),i);
            a_events(2,i)=a2(top_events2(i),i);
        end
        a_events_t(:,1)=reshape(a_events,[1 2*Trials_per_block]);
        modified_a_events_t([1:2:end],1)=a_events_t([1:2:end],1);
        modified_a_events_t([2:2:end],1)=a_vertical_down_1-a_events_t([2:2:end],1)+a_vertical_up_1;
        for sh=1:500
            a_events_t(:,sh)=reshape(Shuffle(a_events),[1 2*Trials_per_block]);
            modified_a_events_t([1:2:end],sh)=a_events_t([1:2:end],sh);
            modified_a_events_t([2:2:end],sh)=a_vertical_down_1-a_events_t([2:2:end],sh)+a_vertical_up_1;
            for i=2:2*Trials_per_block
                a_event_distance(i,sh)=abs(modified_a_events_t(i,sh)-modified_a_events_t(i-1,sh));
            end
        end
        [~,inx]=max(sum(a_event_distance));
        c=0;
        for i=1:2:Trials_per_block*2
            c=c+1;
            a(top_events(c),c)=a_events_t(i,inx);
        end
        c=0;
        for i=2:2:Trials_per_block*2
            c=c+1;
            a2(top_events2(c),c)=a_events_t(i,inx);
        end
        a_original=a;
        a_original2=a2;
        
        
        
        for dot_num=1:Num_moving_dots*Trials_per_block
            for xt=1:obstacle_xposition1
                yt=round(a_original(dot_num).*xt);
                if sqrt((xt-obstacle_xposition1).^2+(yt-obstacle_yposition1).^2)<(boundary_radius+moving_dots_radius)
                    break;
                end
            end
            hitting_coordinates1(dot_num,:)=[xt yt];
            yhit(dot_num)=hitting_coordinates1(dot_num,2);
            for cnt=1:150
                if defl_direction(dot_num)==1
                    yhit(dot_num)=yhit(dot_num)+1;
                else
                    yhit(dot_num)=yhit(dot_num)-1;
                end
                xtt(dot_num)=round((yhit(dot_num)-hitting_coordinates1(dot_num,2)+(-1./a_original(dot_num))*hitting_coordinates1(dot_num,1))./(-1./a_original(dot_num)));
            end
            deflection_coordinates1(dot_num,:)=[xtt(dot_num) yhit(dot_num)];
        end
        y_boundary=a_original.*x_boundary;
        
        
        for dot_num=1:Num_moving_dots*Trials_per_block
            for xt=1:obstacle_xposition1
                xtmp=wRect(3)-xt;
                yt=round(a_original2(dot_num).*xtmp)+wRect(4)-round(wRect(3).*a_original2(dot_num));
                
                if sqrt((xtmp-obstacle_xposition1).^2+(yt-obstacle_yposition1).^2)<(boundary_radius+moving_dots_radius)
                    break;
                end
            end
            hitting_coordinates2(dot_num,:)=[xtmp yt];
            yhit(dot_num)=hitting_coordinates2(dot_num,2);
            for cnt=1:150
                if defl_direction2(dot_num)==1
                    yhit(dot_num)=yhit(dot_num)+1;
                else
                    yhit(dot_num)=yhit(dot_num)-1;
                end
                xtt(dot_num)=round((yhit(dot_num)-hitting_coordinates2(dot_num,2)+(-1./a_original2(dot_num))*hitting_coordinates2(dot_num,1))./(-1./a_original2(dot_num)));
            end
            deflection_coordinates2(dot_num,:)=[xtt(dot_num) yhit(dot_num)];
        end
        y_boundary2=a_original2.*(wRect(3)-x_boundary)+wRect(4)-round(wRect(3).*a_original2);
        
        
        
        speedx1=4.*ones(Num_moving_dots,Trials_per_block)-(a_original-non_target_time_gap_constant);
        speedyd1=speedx1.*wRect(4)./wRect(3);
        speedx2=4.*ones(Num_moving_dots,Trials_per_block)-(a_original2-non_target_time_gap_constant);
        speedyd2=speedx2.*wRect(4)./wRect(3);
        
        
        appearance_time_temp=zeros(2*Num_moving_dots,Trials_per_block);
        top_indices=[1:Num_moving_dots];
        top_indices2=[Num_moving_dots+1:2*Num_moving_dots];
        for tr=1:Trials_per_block
            appearance_time_temp([top_indices(top_events(:,tr)) top_indices2(top_events2(:,tr))],tr)=randsample([(tr-1)*trial_length+1:distance_between_events_limit:tr*trial_length-distance_between_events_limit],length([top_indices(top_events(:,tr)) top_indices2(top_events2(:,tr))]));
            for iter=1:500
                tp(iter,:)=randsample([(tr-1)*trial_length+1+distance_between_dots_limit:distance_between_dots_limit:tr*trial_length-distance_between_dots_limit],sum(appearance_time_temp(:,tr)==0));
                tg=appearance_time_temp(appearance_time_temp(:,tr)~=0,tr);
                for i=1:length(tp(iter,:))
                    for j=1:length(tg)
                        tmpp(i,j)=abs(tp(iter,i)-tg(j));
                    end
                end
                dist_alterns(iter)=min(min(tmpp));
            end
            [~,indmax]=max(dist_alterns);
            appearance_time_temp(appearance_time_temp(:,tr)==0,tr)=tp(indmax,:);
        end
        appearance_time=appearance_time_temp(1:Num_moving_dots,:);
        appearance_time2=appearance_time_temp(Num_moving_dots+1:2*Num_moving_dots,:);
        
        
        y=zeros(1,Num_moving_dots*Trials_per_block);
        x0=zeros(Num_moving_dots,Trials_per_block);
        y0=zeros(Num_moving_dots,Trials_per_block);
        
        yy=zeros(1,Num_moving_dots*Trials_per_block);
        xx0=zeros(Num_moving_dots,Trials_per_block);
        yy0=zeros(Num_moving_dots,Trials_per_block);
        
        FirstAppearTop1=zeros(Num_moving_dots,Trials_per_block);
        FirstAppearTop2=zeros(Num_moving_dots,Trials_per_block);
        FirstShadeTop1=zeros(Num_moving_dots,Trials_per_block);
        FirstShadeTop2=zeros(Num_moving_dots,Trials_per_block);
        
        counter1=zeros(1,Num_moving_dots*Trials_per_block);
        counter1_temp=zeros(1,Num_moving_dots*Trials_per_block);
        
        counter2=zeros(1,Num_moving_dots*Trials_per_block);
        counter2_temp=zeros(1,Num_moving_dots*Trials_per_block);
        temp=zeros(1,Num_moving_dots*Trials_per_block);
        
        key_pressed1=zeros(Num_moving_dots,trial_length*(Trials_per_block+1),Trials_per_block);
        key_pressed2=zeros(Num_moving_dots,trial_length*(Trials_per_block+1),Trials_per_block);
        key_pressedTotal=zeros(1,trial_length*(Trials_per_block+1));
        dist_top=nan*ones(Num_moving_dots,Trials_per_block);
        dist_top2=nan*ones(Num_moving_dots,Trials_per_block);
        
        automatically_deflected_top=nan*ones(size(appearance_time));
        manually_deflected_top=nan*ones(size(appearance_time));
        beeped_top=nan*ones(size(appearance_time));
        
        automatically_deflected_top2=nan*ones(size(appearance_time));
        manually_deflected_top2=nan*ones(size(appearance_time));
        beeped_top2=nan*ones(size(appearance_time));
        
        distance_traj1=nan*ones(Num_moving_dots*Trials_per_block,trial_length*(Trials_per_block+1));
        distance_traj2=nan*ones(Num_moving_dots*Trials_per_block,trial_length*(Trials_per_block+1));
        xy_final_1=nan*ones(2,Num_moving_dots*Trials_per_block,trial_length*(Trials_per_block+1));
        xy_final_2=nan*ones(2,Num_moving_dots*Trials_per_block,trial_length*(Trials_per_block+1));
        
        shades1=zeros(Num_moving_dots,Trials_per_block);
        shades2=zeros(Num_moving_dots,Trials_per_block);
        
        dot_num_closest_top=1;
        dot_num_closest_top2=1;
        refractory_counter=0;
        defl_refractory_counter=0;
        refractory_counter_beep_off=0;
        
        if Eye_tracking
            
            % STEP 7.1
            % Sending a 'TRIALID' message to mark the start of a trial in Data
            % Viewer.  This is different than the start of recording message
            % START that is logged when the trial recording begins. The viewer
            % will not parse any messages, events, or samples, that exist in
            % the data file prior to this message.
            Eyelink('Message', 'BLOCKID %d', Block_Num);
            
            % This supplies the title at the bottom of the eyetracker display
            Eyelink('command', 'record_status_message "BLOCK %d/%d, Task %s, Target %s"', Block_Num, Blocks_per_condition, Condition_string, target_color);
            % Before recording, we place reference graphics on the host display
            % Must be offline to draw to EyeLink screen
            Eyelink('Command', 'set_idle_mode');
            % clear tracker display and draw box at center
            Eyelink('Command', 'clear_screen 0')
            Eyelink('command', 'draw_box %d %d %d %d 15', width/2-50, height/2-50, width/2+50, height/2+50);
            
            
            % STEP 7.2
            % Do a drift correction at the beginning of each trial
            % Performing drift correction (checking) is optional for
            % EyeLink 1000 eye trackers.
            %       % EyelinkDoDriftCorrection(el);
            
            % STEP 7.3
            % start recording eye position (preceded by a short pause so that
            % the tracker can finish the mode transition)
            % The paramerters for the 'StartRecording' call controls the
            % file_samples, file_events, link_samples, link_events availability
            Eyelink('Command', 'set_idle_mode');
            WaitSecs(0.05);
            
            %         % tracker starts recording!
            Eyelink('StartRecording');
            % record a few samples before we actually start displaying
            % otherwise you may lose a few msec of data
            WaitSecs(0.1);
            
            % get eye that's tracked
            % returns 0 (LEFT_EYE), 1 (RIGHT_EYE) or 2 (BINOCULAR) depending on what data is
            eye_used = Eyelink('EyeAvailable');
            if eye_used == 2
                eye_used = 1; % use the right-eye data
            end
        end
        
        % Stimulus onset
        % mark zero-plot time in data file
        if Eye_tracking
            Eyelink('Message', 'Block_Onset');
        end
        if MEG; io64(p.ioObj,p.address,p.triggernums(1,5)-128); trigger_on = GetSecs; end           % MEG trigger on
        if MEG; WaitSecs(p.trigger_duration-(GetSecs-trigger_on)); io64(p.ioObj,p.address,0); end   % MEG trigger off
        
        if SaveAudio==1
            Voice = audiorecorder(Fs, Audio_quality, Mono_Stereo);
            Voice.StartFcn = 'disp(''Start speaking.'')';
            Voice.StopFcn = 'disp(''End of recording.'')';
            record(Voice,length_of_recording);
        end
        
        for main_counter=1:trial_length*(Trials_per_block+1)
            
            [~,~,keycode,~] = KbCheck();
            
            if keycode(KbName(response_button))
                key_pressedTotal(1,main_counter)=1;
            end
            
            % Check recording status, stop display if error
            if Eye_tracking
                error=Eyelink('CheckRecording');
                if(error~=0)
                    break;
                end
            end
            refractory_counter=refractory_counter+1;
            defl_refractory_counter=defl_refractory_counter+1;
            
            Screen('FillOval',wpoint,[255 255 255], Obstacle_1);
            
            for dot_num=1:Num_moving_dots*Trials_per_block
                [~,dot_num_closest_top_total(1,tr)]=nanmin([dist_top(:,tr);dist_top2(:,tr)]);
                if dot_num_closest_top_total(1,tr)<=Num_moving_dots
                    closest_dot_is_left(1,tr)=1;
                else
                    closest_dot_is_left(1,tr)=0;
                end
                
                tr=ceil(dot_num./Num_moving_dots);
                dot_in_trial=dot_num-(tr-1).*Num_moving_dots;
                
                if main_counter>appearance_time(dot_num)
                    counter1(dot_num)=counter1(dot_num)+speedx1(dot_num);
                    y(dot_num)=round(a(dot_num).*(counter1(dot_num)-x0(dot_num)))+y0(dot_num);
                    
                    if sum(dot_in_trial==top_events(:,tr))==1 && (isnan(automatically_deflected_top(dot_num)) && isnan(manually_deflected_top(dot_num)))
                        dist_top(dot_in_trial,tr)=sqrt((counter1(dot_num)-obstacle_xposition1).^2+(y(dot_num)-obstacle_yposition1).^2);
                    elseif sum(dot_in_trial==top_events(:,tr))==1 && (~isnan(automatically_deflected_top(dot_num)) || ~isnan(manually_deflected_top(dot_num)))
                        dist_top(dot_in_trial,tr)=sqrt((x1-obstacle_xposition1).^2+(counter1_temp(dot_num)-obstacle_yposition1).^2);
                    end
                    
                    dist_top(dist_top(:,tr)>distance_of_consideration,tr)=nan;
                    if sum(~isnan(dist_top(:,tr))) && defl_refractory_counter>post_defl_refractory_time
                        [~,dot_num_closest_top]=nanmin(dist_top(:,tr));
                    end
                    
                    if sum(dot_num_closest_top==top_events(:,tr))==1 && isnan(manually_deflected_top(dot_num_closest_top,tr)) && isnan(beeped_top(dot_num_closest_top,tr)) && refractory_counter>refractory_time && closest_dot_is_left(1,tr)==1 && (counter1((tr-1).*Num_moving_dots+dot_num_closest_top)-obstacle_xposition1)<0 && counter1((tr-1).*Num_moving_dots+dot_num_closest_top)>x_boundary && keycode(KbName(response_button)) %&& length(responseIdx)==1
                        key_pressed1(dot_num_closest_top,main_counter,tr)=1;
                        refractory_counter=0;
                        if Eye_tracking
                            Eyelink('Message', 'KeyTop1 %d %d', tr, dot_num_closest_top);
                        end
                        if MEG; io64(p.ioObj,p.address,p.triggernums(1,2)-128); trigger_on = GetSecs; end           % MEG trigger on
                        if MEG; WaitSecs(p.trigger_duration-(GetSecs-trigger_on)); io64(p.ioObj,p.address,0); end   % MEG trigger off
                        if dist_top(dot_num_closest_top,tr)<hitting_border_distance && block_target_color==dot_color((tr-1).*Num_moving_dots+dot_num_closest_top)
                            a(dot_num_closest_top,tr)=-1./a(dot_num_closest_top,tr);
                            x0(dot_num_closest_top,tr)=counter1((tr-1).*Num_moving_dots+dot_num_closest_top);
                            y0(dot_num_closest_top,tr)=y((tr-1).*Num_moving_dots+dot_num_closest_top);
                            counter1_temp((tr-1).*Num_moving_dots+dot_num_closest_top)=y0(dot_num_closest_top,tr);
                            manually_deflected_top(dot_num_closest_top,tr)=1;
                            beepCorrect;
                        else
                            beepIncorrect;
                            beeped_top(dot_num_closest_top,tr)=1;
                        end
                    end
                    
                    if sum(dot_in_trial==top_events(:,tr)) && isnan(automatically_deflected_top(dot_in_trial,tr)) && isnan(manually_deflected_top(dot_in_trial,tr)) && sum(dot_in_trial==top_targets(:,tr))==0 && (sqrt((counter1(dot_num)-obstacle_xposition1).^2+(y(dot_num)-obstacle_yposition1).^2)<hitting_border_distance)
                        if Eye_tracking
                            Eyelink('Message', 'DefTop1 %d %d', tr, dot_in_trial);
                        end
                        if MEG; io64(p.ioObj,p.address,p.triggernums(1,3)-128); trigger_on = GetSecs; end           % MEG trigger on
                        if MEG; WaitSecs(p.trigger_duration-(GetSecs-trigger_on)); io64(p.ioObj,p.address,0); end   % MEG trigger off
                        x0(dot_in_trial,tr)=counter1(dot_num);
                        y0(dot_in_trial,tr)=y(dot_num);
                        a(dot_num)=-1./a(dot_num);
                        automatically_deflected_top(dot_in_trial,tr)=1;
                        counter1_temp(dot_num)=y(dot_num);
                        defl_refractory_counter=0;
                    end
                    
                    Moving_dot = [counter1(dot_num)-moving_dots_radius, y(dot_num)-moving_dots_radius, counter1(dot_num)+moving_dots_radius, y(dot_num)+moving_dots_radius];
                    if ~isnan(automatically_deflected_top(dot_num)) || ~isnan(manually_deflected_top(dot_num))
                        if defl_direction(dot_num)
                            counter1_temp(dot_num)=counter1_temp(dot_num)+speedyd1(dot_num);
                        else
                            counter1_temp(dot_num)=counter1_temp(dot_num)-speedyd1(dot_num);
                        end
                        x1=round((counter1_temp(dot_num)-y0(dot_num)+a(dot_num)*x0(dot_num))./a(dot_num));
                        Moving_dot = [x1-moving_dots_radius,counter1_temp(dot_num)-moving_dots_radius, x1+moving_dots_radius,counter1_temp(dot_num)+moving_dots_radius];
                    end
                    
                    if dot_color(dot_num)==1
                        current_dot_color=first_dot_colour;
                    else
                        current_dot_color=second_dot_colour;
                    end
                    
                    if sum(dot_in_trial==top_events(:,tr))==1 && Moving_dot(1)>x_boundary && Moving_dot(1)<wRect(3)-x_boundary
                        if FirstAppearTop1(dot_in_trial,tr)==0
                            if Eye_tracking
                                Eyelink('Message', 'FirstAppearTop1 %d %d', tr, dot_in_trial);
                            end
                            FirstAppearTop1(dot_in_trial,tr)=main_counter;
                            if MEG; io64(p.ioObj,p.address,p.triggernums(1,1)-128); trigger_on = GetSecs; end           % MEG trigger on
                            if MEG; WaitSecs(p.trigger_duration-(GetSecs-trigger_on)); io64(p.ioObj,p.address,0); end   % MEG trigger off
                            if photodiode; Screen('FillRect',wpoint,[255 255 255],[wRect(3)-140 100 wRect(3)-100 140]); end
                        end
                        if (isnan(automatically_deflected_top(dot_num)) && isnan(manually_deflected_top(dot_num))) && Moving_dot(1)<obstacle_xposition1+120
                            Screen('DrawLine',wpoint,[120],x_boundary,y_boundary(dot_num),hitting_coordinates1(dot_num,1),hitting_coordinates1(dot_num,2));
                            Screen('DrawLine',wpoint,[120],hitting_coordinates1(dot_num,1),hitting_coordinates1(dot_num,2),deflection_coordinates1(dot_num,1),deflection_coordinates1(dot_num,2));
                            Screen('FillOval', wpoint, current_dot_color, Moving_dot);
                        elseif (~isnan(automatically_deflected_top(dot_num)) || ~isnan(manually_deflected_top(dot_num))) && ((Moving_dot(2)./Moving_dot(1))>non_target_time_gap_constant) && ((Moving_dot(2)./Moving_dot(1))<1)
                            if Moving_dot(1)<obstacle_xposition1
                                Screen('DrawLine',wpoint,[120],x_boundary,y_boundary(dot_num),hitting_coordinates1(dot_num,1),hitting_coordinates1(dot_num,2));
                                Screen('DrawLine',wpoint,[120],hitting_coordinates1(dot_num,1),hitting_coordinates1(dot_num,2),deflection_coordinates1(dot_num,1),deflection_coordinates1(dot_num,2));
                            end
                            Screen('FillOval', wpoint, current_dot_color, Moving_dot);
                        else
                            if FirstShadeTop1(dot_in_trial,tr)==0 && (isnan(automatically_deflected_top(dot_num)) && isnan(manually_deflected_top(dot_num)))
                                if Eye_tracking
                                    Eyelink('Message', 'FirstShadeTop1 %d %d', tr, dot_in_trial);
                                end
                                if MEG; io64(p.ioObj,p.address,p.triggernums(1,4)-128); trigger_on = GetSecs; end           % MEG trigger on
                                if MEG; WaitSecs(p.trigger_duration-(GetSecs-trigger_on)); io64(p.ioObj,p.address,0); end   % MEG trigger off
                                FirstShadeTop1(dot_in_trial,tr)=main_counter;
                            end
                            shades1(dot_num)=shades1(dot_num)+fading_time;
                            Screen('FillOval', wpoint, current_dot_color-shades1(dot_num), Moving_dot);
                        end
                    end
                    if (isnan(automatically_deflected_top(dot_num)) && isnan(manually_deflected_top(dot_num)))
                        distance_traj1(dot_num,main_counter)=sqrt((counter1(dot_num)-obstacle_xposition1).^2+(y(dot_num)-obstacle_yposition1).^2);
                        xy_final_1(1,dot_num,main_counter)=counter1(dot_num);
                        xy_final_1(2,dot_num,main_counter)=y(dot_num);
                    else
                        distance_traj1(dot_num,main_counter)=sqrt((x1-obstacle_xposition1).^2+(counter1_temp(dot_num)-obstacle_yposition1).^2);
                        xy_final_1(1,dot_num,main_counter)=x1;
                        xy_final_1(2,dot_num,main_counter)=counter1_temp(dot_num);
                    end
                    
                end
                
                if main_counter>appearance_time2(dot_num)
                    temp(dot_num)=temp(dot_num)+speedx2(dot_num);
                    counter2(dot_num)=wRect(3)-temp(dot_num);
                    yy(dot_num)=round(a2(dot_num).*(counter2(dot_num)-xx0(dot_num)))+yy0(dot_num)+wRect(4)-round(wRect(3).*a2(dot_num));
                    
                    if sum(dot_in_trial==top_events2(:,tr))==1 && (isnan(automatically_deflected_top2(dot_num)) && isnan(manually_deflected_top2(dot_num)))
                        dist_top2(dot_in_trial,tr)=sqrt((counter2(dot_num)-obstacle_xposition1).^2+(yy(dot_num)-obstacle_yposition1).^2);
                    elseif sum(dot_in_trial==top_events2(:,tr))==1 && (~isnan(automatically_deflected_top2(dot_num)) || ~isnan(manually_deflected_top2(dot_num)))
                        dist_top2(dot_in_trial,tr)=sqrt((xx1-obstacle_xposition1).^2+(counter2_temp(dot_num)-obstacle_yposition1).^2);
                    end
                    
                    dist_top2(dist_top2(:,tr)>distance_of_consideration,tr)=nan;
                    if sum(~isnan(dist_top2(:,tr))) && defl_refractory_counter>post_defl_refractory_time
                        [~,dot_num_closest_top2]=nanmin(dist_top2(:,tr));
                    end
                    
                    if sum(dot_num_closest_top2==top_events2(:,tr))==1 && isnan(manually_deflected_top2(dot_num_closest_top2,tr)) && isnan(beeped_top2(dot_num_closest_top2,tr)) && refractory_counter>refractory_time && closest_dot_is_left(1,tr)==0 && (counter2((tr-1).*Num_moving_dots+dot_num_closest_top2)-(obstacle_xposition1))>0 && counter2((tr-1).*Num_moving_dots+dot_num_closest_top2)<wRect(3)-x_boundary && keycode(KbName(response_button)) %&& length(responseIdx)==1
                        key_pressed2(dot_num_closest_top2,main_counter,tr)=1;
                        refractory_counter=0;
                        if Eye_tracking
                            Eyelink('Message', 'KeyTop2 %d %d', tr, dot_num_closest_top2);
                        end
                        if MEG; io64(p.ioObj,p.address,p.triggernums(1,2)-128); trigger_on = GetSecs; end           % MEG trigger on
                        if MEG; WaitSecs(p.trigger_duration-(GetSecs-trigger_on)); io64(p.ioObj,p.address,0); end   % MEG trigger off
                        if  dist_top2(dot_num_closest_top2,tr)<hitting_border_distance && block_target_color==dot_color2((tr-1).*Num_moving_dots+dot_num_closest_top2)
                            a2(dot_num_closest_top2,tr)=-1./a2(dot_num_closest_top2,tr);
                            xx0(dot_num_closest_top2,tr)=counter2((tr-1).*Num_moving_dots+dot_num_closest_top2);
                            yy0(dot_num_closest_top2,tr)=yy((tr-1).*Num_moving_dots+dot_num_closest_top2);
                            counter2_temp((tr-1).*Num_moving_dots+dot_num_closest_top2)=yy0(dot_num_closest_top2,tr);
                            manually_deflected_top2(dot_num_closest_top2,tr)=1;
                            beepCorrect;
                        else
                            beepIncorrect;
                            beeped_top2(dot_num_closest_top2,tr)=1;
                        end
                    end
                    
                    if sum(dot_in_trial==top_events2(:,tr)) && isnan(automatically_deflected_top2(dot_in_trial,tr)) && isnan(manually_deflected_top2(dot_in_trial,tr)) && sum(dot_in_trial==top_targets2(:,tr))==0 && (sqrt((counter2(dot_num)-obstacle_xposition1).^2+(yy(dot_num)-obstacle_yposition1).^2)<hitting_border_distance)
                        if Eye_tracking
                            Eyelink('Message', 'DefTop2 %d %d', tr, dot_in_trial);
                        end
                        if MEG; io64(p.ioObj,p.address,p.triggernums(1,3)-128); trigger_on = GetSecs; end           % MEG trigger on
                        if MEG; WaitSecs(p.trigger_duration-(GetSecs-trigger_on)); io64(p.ioObj,p.address,0); end   % MEG trigger off
                        yy0(dot_in_trial,tr)=yy(dot_num);
                        xx0(dot_in_trial,tr)=counter2(dot_num);
                        a2(dot_num)=-1./a2(dot_num);
                        automatically_deflected_top2(dot_in_trial,tr)=1;
                        counter2_temp(dot_num)=yy0(dot_in_trial,tr);
                        defl_refractory_counter=0;
                    end
                    
                    Moving_dot = [counter2(dot_num)-moving_dots_radius,yy(dot_num)-moving_dots_radius, counter2(dot_num)+moving_dots_radius,yy(dot_num)+moving_dots_radius];
                    
                    if ~isnan(automatically_deflected_top2(dot_num)) || ~isnan(manually_deflected_top2(dot_num))
                        if defl_direction2(dot_num)
                            counter2_temp(dot_num)=counter2_temp(dot_num)+speedyd2(dot_num);
                        else
                            counter2_temp(dot_num)=counter2_temp(dot_num)-speedyd2(dot_num);
                        end
                        xx1=round((counter2_temp(dot_num)-yy0(dot_num)+a2(dot_num).*xx0(dot_num))./a2(dot_num));
                        Moving_dot = [xx1-moving_dots_radius,counter2_temp(dot_num)-moving_dots_radius,xx1+moving_dots_radius,counter2_temp(dot_num)+moving_dots_radius];
                    end
                    
                    if dot_color2(dot_num)==1
                        current_dot_color2=first_dot_colour;
                    else
                        current_dot_color2=second_dot_colour;
                    end
                    
                    if sum(dot_in_trial==top_events2(:,tr))==1 && Moving_dot(1)>x_boundary && Moving_dot(1)<wRect(3)-x_boundary
                        if FirstAppearTop2(dot_in_trial,tr)==0
                            if Eye_tracking
                                Eyelink('Message', 'FirstAppearTop2 %d %d', tr, dot_in_trial);
                            end
                            FirstAppearTop2(dot_in_trial,tr)=main_counter;
                            if MEG; io64(p.ioObj,p.address,p.triggernums(1,1)-128); trigger_on = GetSecs; end           % MEG trigger on
                            if MEG; WaitSecs(p.trigger_duration-(GetSecs-trigger_on)); io64(p.ioObj,p.address,0); end   % MEG trigger off
                            if photodiode; Screen('FillRect',wpoint,[255 255 255],[wRect(3)-140 100 wRect(3)-100 140]); end
                        end
                        if (isnan(automatically_deflected_top2(dot_num)) && isnan(manually_deflected_top2(dot_num))) && Moving_dot(1)>obstacle_xposition1-120
                            Screen('DrawLine',wpoint,[120],wRect(3)-x_boundary,y_boundary2(dot_num),hitting_coordinates2(dot_num,1),hitting_coordinates2(dot_num,2));
                            Screen('DrawLine',wpoint,[120],hitting_coordinates2(dot_num,1),hitting_coordinates2(dot_num,2),deflection_coordinates2(dot_num,1),deflection_coordinates2(dot_num,2));
                            Screen('FillOval', wpoint,current_dot_color2, Moving_dot);
                        elseif (~isnan(automatically_deflected_top2(dot_num)) || ~isnan(manually_deflected_top2(dot_num))) && ((Moving_dot(2)./Moving_dot(1))>0.3) && (Moving_dot(2)./Moving_dot(1))<(0.9)
                            if Moving_dot(1)>obstacle_xposition1
                                Screen('DrawLine',wpoint,[120],wRect(3)-x_boundary,y_boundary2(dot_num),hitting_coordinates2(dot_num,1),hitting_coordinates2(dot_num,2));
                                Screen('DrawLine',wpoint,[120],hitting_coordinates2(dot_num,1),hitting_coordinates2(dot_num,2),deflection_coordinates2(dot_num,1),deflection_coordinates2(dot_num,2));
                            end
                            Screen('FillOval', wpoint,current_dot_color2, Moving_dot);
                        else
                            if FirstShadeTop2(dot_in_trial,tr)==0 && (isnan(automatically_deflected_top2(dot_num)) && isnan(manually_deflected_top2(dot_num)))
                                if Eye_tracking
                                    Eyelink('Message', 'FirstShadeTop2 %d %d', tr, dot_in_trial);
                                end
                                if MEG; io64(p.ioObj,p.address,p.triggernums(1,4)-128); trigger_on = GetSecs; end           % MEG trigger on
                                if MEG; WaitSecs(p.trigger_duration-(GetSecs-trigger_on)); io64(p.ioObj,p.address,0); end   % MEG trigger off
                                FirstShadeTop2(dot_in_trial,tr)=main_counter;
                            end
                            shades2(dot_num)=shades2(dot_num)+fading_time;
                            Screen('FillOval', wpoint,current_dot_color2-shades2(dot_num), Moving_dot);
                        end
                    end
                    if (isnan(automatically_deflected_top2(dot_num)) && isnan(manually_deflected_top2(dot_num)))
                        distance_traj2(dot_num,main_counter)=sqrt((counter2(dot_num)-obstacle_xposition1).^2+(yy(dot_num)-obstacle_yposition1).^2);
                        xy_final_2(1,dot_num,main_counter)=counter2(dot_num);
                        xy_final_2(2,dot_num,main_counter)=yy(dot_num);
                    else
                        distance_traj2(dot_num,main_counter)=sqrt((xx1-obstacle_xposition1).^2+(counter2_temp(dot_num)-obstacle_yposition1).^2);
                        xy_final_2(1,dot_num,main_counter)=xx1;
                        xy_final_2(2,dot_num,main_counter)=counter2_temp(dot_num);
                    end
                end
            end
            
            Screen('Flip',wpoint);
            if SaveMovie==1
                Screen('AddFrameToMovie', wpoint, CenterRect([0 0 wRect(3) wRect(4)], Screen('Rect', screenNumber)), 'frontBuffer');
            end
        end
        
        if Eye_tracking
            Eyelink('Message', 'Block_Offset');
            Eyelink('Message', 'Start_of_Rest_Time');
        end
        if MEG; io64(p.ioObj,p.address,p.triggernums(1,6)-128); trigger_on = GetSecs; end           % MEG trigger on
        if MEG; WaitSecs(p.trigger_duration-(GetSecs-trigger_on)); io64(p.ioObj,p.address,0); end   % MEG trigger off
        Screen('Flip',wpoint);
        WaitSecs(Break_time);
        if Eye_tracking
            Eyelink('Message', 'End_of_Rest_Time');
        end
        save(['Subj_',num2str(Subj),'_Blk_',num2str(Block_Num),'_',Condition_string,...
            '_train_Levels.mat'],'manually_deflected_top','top_events','top_events2','top_targets','top_targets2',...
            'automatically_deflected_top','manually_deflected_top2','automatically_deflected_top2','speedx1','speedx2',...
            'moving_dots_radius','obstacle_radius','boundary_radius','distance_traj1','beeped_top','beeped_top2',...
            'distance_traj2','hitting_obstacle_distance','hitting_border_distance',...
            'key_pressed1','key_pressed2','appearance_time','appearance_time2',...
            'a_original','a_original2','a','a2','defl_direction','defl_direction2',...
            'Num_moving_dots','Trials_per_block','key_pressedTotal',...
            'dot_color','dot_color2','block_target_color','FirstAppearTop1','FirstAppearTop2',...
            'FirstShadeTop1','FirstShadeTop2','response_button','xy_final_1','xy_final_2',...
            'Block_condition','Cued_color_in_block');
        
        if SaveMovie==1
            Screen('FinalizeMovie', movie);
        end
        if SaveAudio==1
            audiowrite(['Subj_',num2str(Subj),'_Blk_',num2str(Block_Num),'_',Condition_string,...
                '_train_Levels.wav'], getaudiodata(Voice), Fs)
        end
        
        
        if Eye_tracking
            
            % stop the recording of eye-movements for the current block.
            % recommended to put this right after Block_RESULT
            Eyelink('StopRecording');
            
            
            % STEP 7.7
            % Send out necessary integration messages for data analysis
            % Send out interest area information for the block
            % See "Protocol for EyeLink Data to Viewer Integration-> Interest
            % Area Commands" section of the EyeLink Data Viewer User Manual
            % IMPORTANT! Don't send too many messages in a very short period of
            % time or the EyeLink tracker may not be able to write them all
            % to the EDF file.
            % Consider adding a short delay every few messages.
            WaitSecs(0.001);
            Eyelink('Message', '!V IAREA ELLIPSE %d %d %d %d %d %s', 1, width/2-50, height/2-50, width/2+50, height/2+50,'center');
            Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 2, width/4-50, height/2-50, width/4+50, height/2+50,'left');
            Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 3, 3*width/4-50, height/2-50, 3*width/4+50, height/2+50,'right');
            Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 4, width/2-50, height/4-50, width/2+50, height/4+50,'up');
            Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 5, width/2-50, 3*height/4-50, width/2+50, 3*height/4+50,'down');
            
            % Send messages to report trial condition information
            % Each message may be a pair of trial condition variable and its
            % corresponding value follwing the '!V TRIAL_VAR' token message
            % See "Protocol for EyeLink Data to Viewer Integration-> Trial
            % Message Commands" section of the EyeLink Data Viewer User Manual
            WaitSecs(0.001);
            Eyelink('Message', '!V Block Number =  %d', Block_Num)
            
            % STEP 7.8
            % Sending a 'BLOCK_RESULT' message to mark the end of a trial in
            % Data Viewer. This is different than the end of recording message
            % END that is logged when the trial recording ends. The viewer will
            % not parse any messages, events, or samples that exist in the data
            % file after this message.
            Eyelink('Message', 'BLOCK_RESULT 0') ;
            % %         if Block_Num>1 && mod(Block_Num,4)==1
            % %             EyelinkDoTrackerSetup(el);
            % %         end
        end
    end
    if Eye_tracking
        % STEP 8
        % End of Experiment; close the file first
        % close graphics window, close data file and shut down tracker
        
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.5);
        Eyelink('CloseFile');
        
        % download data file
        try
            fprintf('Receiving data file ''%s''\n', edfFile );
            status=Eyelink('ReceiveFile');
            if status > 0
                fprintf('ReceiveFile status %d\n', status);
            end
            if 2==exist(edfFile, 'file')
                fprintf('Data file ''%s'' can be found in ''%s''\n', edfFile, pwd );
            end
        catch
            fprintf('Problem receiving data file ''%s''\n', edfFile );
        end
        
        % STEP 9
        % run cleanup function (close the eye tracker and window).
        cleanup;
        Eyelink('ShutDown');
    end
    
    Screen('CloseAll');
    ShowCursor;
    fclose('all');
    Priority(0);
    ListenChar(0);
    %     PsychPortAudio('Close');
    return;
catch
    ShowCursor;
    fclose('all');
    Priority(0);
    if Eye_tracking
        cleanup;
    end
end
end
function cleanup
% Shutdown Eyelink:
Eyelink('Shutdown');

% % Close window:
sca;
commandwindow;
end

function beepStart
% MATLAB sound
fs=15000;
duration=0.1;
freq=35000;
values=0:1/fs:duration;
a=20*sin(2*pi* freq*values);
sound(a)

% InitializePsychSound(1);
% freq=44100;
% nrchannels=1;
% pahandle=PsychPortAudio('Open',[],1,0,freq,nrchannels);
% snddata= MakeBeep(250,0.1,freq);
% PsychPortAudio('FillBuffer',pahandle,snddata);
% PsychPortAudio('Start',pahandle,[],[]);
end

function beepIncorrect
% MATLAB sound
fs=20500 ;
duration=0.03;
freq=30000;
values=0:1/fs:duration;
bi=20*sin(2*pi* freq*values);
sound(bi)

% InitializePsychSound(1);
% freq=44100;
% nrchannels=1;
% pahandle=PsychPortAudio('Open',[],1,0,freq,nrchannels);
% snddata= MakeBeep(250,0.1,freq);
% PsychPortAudio('FillBuffer',pahandle,snddata);
% PsychPortAudio('Start',pahandle,[],[]);
end


function beepCorrect

fs=13000;
duration=0.03;
freq=40000;
values=0:1/fs:duration;
bc=10*sin(2*pi* freq*values);
sound(bc)

% InitializePsychSound(1);
% freq=44100;
% nrchannels=1;
% pahandle=PsychPortAudio('Open',[],1,0,freq,nrchannels);
% snddata= MakeBeep(13000,0.1,freq);
% PsychPortAudio('FillBuffer',pahandle,snddata);
% PsychPortAudio('Start',pahandle,[],[]);
end