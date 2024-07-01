eval "$(jq -r '@sh "RG_NAME=\(.rg_name) COS_NAME=\(.cos_name) LOG_NAME=\(.log_name) MON_NAME=\(.mon_name)"')"

#echo "rg = ${RG_NAME}"
#echo "cos = ${COS_NAME}"
#echo "log = ${LOG_NAME}"
#echo "mon = ${MON_NAME}"

OUTPUT=$(ibmcloud resource group $RG_NAME -q)
rg_status=$?
OUTPUT=$(ibmcloud resource service-instance "$COS_NAME")
cos_status=$?
OUTPUT=$(ibmcloud resource service-instance "$LOG_NAME")
log_status=$?
OUTPUT=$(ibmcloud resource service-instance "$MON_NAME")
mon_status=$?

if [[ $rg_status == 0 ]]; then
  create_rg="false"
else
  create_rg="true"
fi

if [[ $cos_status == 0 ]]; then
  create_cos="false"
else
  create_cos="true"
fi

if [[ $log_status == 0 ]]; then
  create_log="false"
else
  create_log="true"
fi

if [[ $mon_status == 0 ]]; then
  create_mon="false"
else
  create_mon="true"
fi

jq -n --arg create_rg "$create_rg" --arg create_cos "$create_cos" --arg create_log "$create_log" --arg create_mon "$create_mon" '{"create_rg":$create_rg, "create_cos":$create_cos, "create_log":$create_log, "create_mon":$create_mon}'