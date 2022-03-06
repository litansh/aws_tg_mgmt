#!/bin/bash

function help_ () {
    echo '                                    *** AWS Target-Group management ***                                           '
    echo '                                                                                                                  '       
    echo '      - To register a new target: ./AWS_TG_MGMT reg <TG_arn> <instance_to_reg> <port_number> ...                  '
    echo '          - instance_to_reg: Instance ID or IP address.          (Required)                                       '
    echo '            In case of Lambda function - arn is needed instead.                                                   '
    echo '            You may add as much instances as required. Add <instance_to_reg> <port_number> arguments              '
    echo '          - port_number:     1-65535                             (Optional)                                       '
    echo '                                                                                                                  '       
    echo '        ##############################################################################################            '          
    echo '                                                                                                                  '       
    echo '      - To deregister a new target: ./AWS_TG_MGMT dereg <TG_arn> <instance_to_dereg> <port_number> ...            '
    echo '          - instance_to_reg: Instance ID or IP address.          (Required)                                       '
    echo '            In case of Lambda function - arn is needed instead.                                                   '
    echo '          - port_number:     1-65535                             (Optional)                                       '
    echo '                                                                                                                  '       
    echo '        ##############################################################################################            '              
    echo '                                                                                                                  '       
    echo '      - To run a health check of the Target-Group: ./AWS_TG_MGMT tg_hc <TG_arn>                                   '
    echo '      - To run a health check of a specific target: ./AWS_TG_MGMT target_hc <TG_arn> <instance>                   '
    echo '        <port_number> ...                                                                                         '
    echo '                                                                                                                  '       
    echo '        ##############################################################################################            '       
    echo '                                                                                                                  '          
    echo '                                  - To view log file: ./AWS_TG_MGMT logs                                          '
}

function build_cmd_file () {
# Build the beggining of the command file
echo -n "aws elbv2 $reg_action " > $run_elbv2
echo '\' >> $run_elbv2
echo -n  "    --target-group-arn $tg_arn" >> $run_elbv2
echo ' \' >> $run_elbv2
echo -n  "    --targets" >> $run_elbv2
} 

function build_cmd_file_spec_targets () {
# Build the beggining of the command file for specific targets health check
echo "aws elbv2 $reg_action " > $run_elbv2
echo -n '\' >> $run_elbv2
echo '    --targets' >> $run_elbv2
action_on_targets
echo "    --target-group-arn $tg_arn" >> $run_elbv2
} 

function run_cmd_file () {
# Run aws elbv2 command and output to log
chmod +x $run_elbv2
echo `date` >> log_elbv2.log
if [[ $reg_action == 'describe-target-health' ]]; then
    ./$run_elbv2 > log_hc.log
    echo "Health Check Output: "
    grep -E 'Id|Port|State' log_hc.log
    cat log_hc.log >> log_elbv2.log
else
    ./$run_elbv2 >> log_elbv2.log 2>&1
fi
}

function iterate_over_args () {
# Iterate Over arguments (Instance_ID and Ports or Lambda arn)
for value in "$@";
    do
        args_array+=("$1")
        shift
    done
}

function action_on_targets () {
# Builds the rest of the command file with given parameters
for value in "${args_array[@]}"
do
    if [[ $value =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$value" == *[i-]* ]]; then
        echo -n "Id=$value" >> $run_elbv2
        check_id=1
    else 
        if [[ $check_id == 1 ]] && [[ $value -ge 1 ]] && [[ $value -le 65535 ]]; then
            echo -n ",Port=$value " >> $run_elbv2
            check_id=0
        else
            echo -n ' ' >> $run_elbv2
        fi
    fi
done

# Call function to run elbv2 command
#run_cmd_file
}

# Declare a string array
args_array=()
# File to run elbv2 command
run_elbv2='run_elbv2_cmd.sh'
clear
iterate_over_args "$@"
tg_arn=$2

# Starting here
case "$1" in
  reg)
    reg_action='register-targets'
    build_cmd_file
    action_on_targets
    ;;
  dereg)
    reg_action='deregister-targets'
    build_cmd_file
    action_on_targets
    ;;
  tg_hc)
    reg_action='describe-target-health'
    build_cmd_file
    action_on_targets
    ;;
  target_hc)
    reg_action='describe-target-health'
    build_cmd_file_spec_targets
    action_on_targets
    ;;
  logs)
    if [ -f log_elbv2.log ]; then less log_elbv2.log; else echo 'Log file does not exist..'; fi
    ;;
  *)
    help_
    ;;
esac
