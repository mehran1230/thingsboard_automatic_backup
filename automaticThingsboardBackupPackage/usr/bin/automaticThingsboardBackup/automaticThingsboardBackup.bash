function parse_yaml {
  local prefix=$2
  local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @ | tr @ '\034')
  sed -ne "s|^\($s\):|\1|" \
    -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
    -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" $1 |
    awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

function backupPostgreSQL() {
  echo "Backup PostgreSQL . . ."
  sudo -Hiu postgres pg_dump thingsboard | gzip -9 - >automatic_backup_postgres.tar.gz
  sudo chmod 777 automatic_backup_postgres.tar.gz
  echo "Backup PostgreSQL Completed."
}
function backupCassandra() {
  echo "Backup Cassandra . . . "
  sudo systemctl stop thingsboard
  nodetool drain
  sudo systemctl stop cassandra
  tar cvf - /var/lib/cassandra/ 2>/dev/null | gzip -9 - >automatic_backup_cassandra.tar.gz
  sudo systemctl restart cassandra
  sleep 60
  sudo systemctl restart thingsboard
  sudo chmod 777 automatic_backup_cassandra.tar.gz
  echo "Backup Cassandra Completed."
}
function createBackupFileNameForLocal() {

  export localFileNameIndex=0
  export localFileNameDate=$(date +"%Y_%m_%d")

  while [[ -e "${saveLocalBackup_location}automatic_backup_postgres_${localFileNameDate}_${localFileNameIndex}.tar.gz" || -e "${saveLocalBackup_location}automatic_backup_cassandra_${localFileNameDate}_${localFileNameIndex}.tar.gz" ]]; do
    ((localFileNameIndex++))
  done

}
function createBackupFileNameForFTP() {
  ftp_path="$1"
  export FTPFileNameIndex=0
  export FTPFileNameDate=$(date +"%Y_%m_%d")

  while [[ -e "${ftp_path}${saveFTPBackup_location}automatic_backup_postgres_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz" || -e "${ftp_path}${saveFTPBackup_location}automatic_backup_cassandra_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz" ]]; do
    ((FTPFileNameIndex++))
  done

}
function checkConfigAndBackup() {
  if [ "$PostgreSQLBackupEnabled" = "true" ]; then
    backupPostgreSQL
  fi
  if [ "$cassandraBackupEnabled" = "true" ]; then
    backupCassandra
  fi
}

function saveLocal() {
  sudo mkdir -p "${saveLocalBackup_location}"
  createBackupFileNameForLocal
  #region postgreSQL
  if [ "$PostgreSQLBackupEnabled" = "true" ]; then
    echo "Local Saving PostgreSQL . . ."
    sudo rsync --progress automatic_backup_postgres.tar.gz "${saveLocalBackup_location}automatic_backup_postgres_${localFileNameDate}_${localFileNameIndex}.tar.gz"
    echo "PostgreSQL saved in local ${saveLocalBackup_location}automatic_backup_postgres_${localFileNameDate}_${localFileNameIndex}.tar.gz"
    # region remove old files if count is bigger than config file
    files=("${saveLocalBackup_location}automatic_backup_postgres_"*)

    if [[ ${#files[@]} -gt $saveLocalBackup_maximumBackupsCount ]]; then
      # Sort files by creation time in ascending order
      sorted_files=($(ls -t -r -U "${files[@]}"))

      # Calculate the number of files to remove
      num_files_to_remove=$((${#files[@]} - saveLocalBackup_maximumBackupsCount))

      # Remove the oldest files
      for ((i = 0; i < num_files_to_remove; i++)); do
        file_to_remove="${sorted_files[i]}"
        sudo rm -f "$file_to_remove"
        echo "Removed file: $file_to_remove"

      done

      # Rename the remaining files
      files=("${saveLocalBackup_location}automatic_backup_postgres_"*)
      sorted_files=($(ls -t -r -U "${files[@]}"))

      while [[ ${#sorted_files[@]} -gt 0 ]]; do
        base_name="${sorted_files[0]%_*}"
        date_files=("${base_name}"*)
        date_sorted_files=($(ls -t -r -U "${date_files[@]}"))

        # remove date-sorted_files form sorted_files
        filtered_files=()

        # Loop through the sorted files
        for file in "${sorted_files[@]}"; do
          # Check if the file exists in the date sorted files
          if [ "${file%_*}" != "${base_name}" ]; then
            filtered_files+=("$file")
          fi
        done
        sorted_files=("${filtered_files[@]}")
        #
        new_index=0
        for file in "${date_sorted_files[@]}"; do
          if [ "${file}" != "${base_name}_${new_index}.tar.gz" ]; then
            sudo mv ${file} ${base_name}_${new_index}.tar.gz
          fi
          new_index=$((new_index + 1))
        done

      done

    fi

    #endregion
  fi
  #endregion
  #region Cassandra
  if [ "$cassandraBackupEnabled" = "true" ]; then
    echo "Local Saving Cassandra . . ."
    sudo rsync --progress automatic_backup_cassandra.tar.gz "${saveLocalBackup_location}automatic_backup_cassandra_${localFileNameDate}_${localFileNameIndex}.tar.gz"
    echo "Cassandra saved in Local ${saveLocalBackup_location}automatic_backup_cassandra_${localFileNameDate}_${localFileNameIndex}.tar.gz"
    # region remove old files if count is bigger than config file
    files=("${saveLocalBackup_location}automatic_backup_cassandra_"*)

    if [[ ${#files[@]} -gt $saveLocalBackup_maximumBackupsCount ]]; then
      # Sort files by creation time in ascending order
      sorted_files=($(ls -t -r -U "${files[@]}"))

      # Calculate the number of files to remove
      num_files_to_remove=$((${#files[@]} - saveLocalBackup_maximumBackupsCount))

      # Remove the oldest files
      for ((i = 0; i < num_files_to_remove; i++)); do
        file_to_remove="${sorted_files[i]}"
        sudo rm -f "$file_to_remove"
        echo "Removed file: $file_to_remove"

      done

      # Rename the remaining files
      files=("${saveLocalBackup_location}automatic_backup_cassandra_"*)
      sorted_files=($(ls -t -r -U "${files[@]}"))

      while [[ ${#sorted_files[@]} -gt 0 ]]; do
        base_name="${sorted_files[0]%_*}"
        date_files=("${base_name}"*)
        date_sorted_files=($(ls -t -r -U "${date_files[@]}"))
        # remove date-sorted_files form sorted_files
        filtered_files=()

        # Loop through the sorted files
        for file in "${sorted_files[@]}"; do
          # Check if the file exists in the date sorted files
          if ! grep -q "$file" <<<"${date_sorted_files[@]}"; then
            filtered_files+=("$file")
          fi
        done
        sorted_files=("${filtered_files[@]}")
        new_index=0
        for file in "${date_sorted_files[@]}"; do
          if [ "${file}" != "${base_name}_${new_index}.tar.gz" ]; then
            sudo mv ${file} ${base_name}_${new_index}.tar.gz
          fi
          new_index=$((new_index + 1))
        done

      done
    fi
    #endregion
  fi
  #endregion
}
function saveFTP() {
  username=$saveFTPBackup_userName
  password=$saveFTPBackup_password
  FTPAddress=$saveFTPBackup_address
  port=$saveFTPBackup_port
  result=0
  ftp_path="1111"
  #  encoded_username=$(printf "%s" "$username" | jq -s -R -r @uri)
  #    encoded_password=$(printf "%s" "$password" | jq -s -R -r @uri)
  #  encoded_address=$(printf "%s" "$FTPAddress" | jq -s -R -r @uri)
  echo "connecting to FTP . . ." >&2
  gio mount -fu ftp://$FTPaddress >/dev/null 2>&1 #disconnect FTP
  gio mount "ftp://${FTPAddress}:${port}" <<<"$username
$password" >/dev/null 2>&1 # make sure there is no space before $password
  check_folder="ftp:host=${FTPAddress}"
  mount_pathes=$(mount | grep gvfsd-fuse)
  addresses=$(echo "$mount_pathes" | grep -oP '/\S+')

  for address in $addresses; do
    if [[ -d "$address/$check_folder" ]]; then
      ftp_path="$address/$check_folder"
      break
    fi

  done
  if [[ "$ftp_path" = "1111" ]]; then
    result=1
  fi
  cd $ftp_path || result=1
  sudo mkdir -p ".${saveFTPBackup_location}" || result=1
  script_directory="$(cd "$(dirname "$0")" && pwd)"
  cd "$script_directory" || result=1
  echo "FTP is connected." >&2

  createBackupFileNameForFTP "$ftp_path"
  find "$ftp_path" -type f -name ".automatic_backup_*.tar.gz.*" -delete # remove uncompleted copy in FTP server
  #region postgreSQL
  if [ "$PostgreSQLBackupEnabled" = "true" ]; then
    echo "FTP Saving PostgreSQL (${saveFTPBackup_transferTimeout} min timout). . ." >&2
    timeout $saveFTPBackup_transferTimeout sudo rsync --progress automatic_backup_postgres.tar.gz "${ftp_path}${saveFTPBackup_location}automatic_backup_postgres_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz" || result=1
    echo "PostgreSQL saved in FTP ${saveFTPBackup_location}automatic_backup_postgres_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz" >&2
    # region remove old files if count is bigger than config file
    files=("${ftp_path}${saveFTPBackup_location}automatic_backup_postgres_"*)
    if [[ ${#files[@]} -gt $saveFTPBackup_maximumBackupsCount ]]; then
      # Sort files by creation time in ascending order
      sorted_files=($(ls -t -r -U "${files[@]}")) || result=1

      # Calculate the number of files to remove
      num_files_to_remove=$((${#files[@]} - saveFTPBackup_maximumBackupsCount))

      # Remove the oldest files
      for ((i = 0; i < num_files_to_remove; i++)); do
        file_to_remove="${sorted_files[i]}"
        sudo rm -f "$file_to_remove" || result=1
        echo "Removed file: $file_to_remove" >&2

      done

      # Rename the remaining files
      files=("${ftp_path}${saveFTPBackup_location}automatic_backup_postgres_"*)
      sorted_files=($(ls -t -r -U "${files[@]}"))

      while [[ ${#sorted_files[@]} -gt 0 ]]; do
        base_name="${sorted_files[0]%_*}"
        date_files=("${base_name}"*)
        date_sorted_files=($(ls -t -r -U "${date_files[@]}"))

        # remove date-sorted_files form sorted_files
        filtered_files=()

        # Loop through the sorted files
        for file in "${sorted_files[@]}"; do
          # Check if the file exists in the date sorted files
          if [ "${file%_*}" != "${base_name}" ]; then
            filtered_files+=("$file")
          fi
        done
        sorted_files=("${filtered_files[@]}")
        #
        new_index=0
        for file in "${date_sorted_files[@]}"; do
          if [ "${file}" != "${base_name}_${new_index}.tar.gz" ]; then
            sudo mv ${file} ${base_name}_${new_index}.tar.gz || result=1
            echo "rename '${file}' to '${base_name}_${new_index}.tar.gz' " >&2
          fi
          new_index=$((new_index + 1))
        done

      done

    fi

    #endregion
  fi
  #endregion
  #region Cassandra
  if [ "$cassandraBackupEnabled" = "true" ]; then
    echo "FTP Saving Cassandra  (${saveFTPBackup_transferTimeout} min timout) . . ." >&2
    timeout $saveFTPBackup_transferTimeout sudo rsync --progress automatic_backup_cassandra.tar.gz "${ftp_path}${saveFTPBackup_location}automatic_backup_cassandra_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz" || result=1
    echo "Cassandra saved in FTP ${saveFTPBackup_location}automatic_backup_cassandra_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz" >&2
    # region remove old files if count is bigger than config file
    files=("${ftp_path}${saveFTPBackup_location}automatic_backup_cassandra_"*)

    if [[ ${#files[@]} -gt $saveFTPBackup_maximumBackupsCount ]]; then
      # Sort files by creation time in ascending order
      sorted_files=($(ls -t -r -U "${files[@]}"))

      # Calculate the number of files to remove
      num_files_to_remove=$((${#files[@]} - saveFTPBackup_maximumBackupsCount))
      # Remove the oldest files
      for ((i = 0; i < num_files_to_remove; i++)); do
        file_to_remove="${sorted_files[i]}"
        sudo rm -f "$file_to_remove" || result=1
        echo "Removed file: $file_to_remove" >&2

      done

      # Rename the remaining files
      files=("${ftp_path}${saveFTPBackup_location}automatic_backup_cassandra_"*)
      sorted_files=($(ls -t -r -U "${files[@]}"))

      while [[ ${#sorted_files[@]} -gt 0 ]]; do
        base_name="${sorted_files[0]%_*}"
        date_files=("${base_name}"*)
        date_sorted_files=($(ls -t -r -U "${date_files[@]}"))
        # remove date-sorted_files form sorted_files
        filtered_files=()

        # Loop through the sorted files
        for file in "${sorted_files[@]}"; do
          # Check if the file exists in the date sorted files
          if ! grep -q "$file" <<<"${date_sorted_files[@]}"; then
            filtered_files+=("$file")
          fi
        done
        sorted_files=("${filtered_files[@]}")
        new_index=0
        for file in "${date_sorted_files[@]}"; do
          if [ "${file}" != "${base_name}_${new_index}.tar.gz" ]; then
            sudo mv ${file} ${base_name}_${new_index}.tar.gz || result=1
            echo "rename '${file}' to '${base_name}_${new_index}.tar.gz' " >&2
          fi
          new_index=$((new_index + 1))
        done

      done
    fi
    #endregion
  fi
  #endregion
  FTPaddress=$saveFTPBackup_address
  find "$ftp_path" -type f -name ".automatic_backup_*.tar.gz.*" -delete # remove uncompleted copy in FTP server

  gio mount -fu ftp://$FTPaddress >/dev/null 2>&1 #disconnect FTP
  echo "FTP is Disconnected" >&2

  return $result
}
function CheckAndSaveBackups() {
  if [ "$saveLocalBackup_enabled" = "true" ]; then
    saveLocal
  fi
  if [ "$saveFTPBackup_enabled" = "true" ]; then

    for ((i = 0; i < saveFTPBackup_retry_count; i++)); do
      saveFTP
      saveFTPResult=$?
      echo "saveFTPResult : ${saveFTPResult}"
      if [ "$saveFTPResult" = 0 ]; then

        break
      else
        address=$saveFTPBackup_address

        echo "wait ${saveFTPBackup_retry_wait} min before retrying . . . "
        gio mount -fu ftp://$address >/dev/null 2>&1 #disconnect FTP

        sleep $(($saveFTPBackup_retry_wait * 60))
        echo "retry (${i+1}/${saveFTPBackup_retry_count}). . ."
      fi
    done

  fi
}

function removeCurrentBackup() {
  sudo rm -f "automatic_backup_cassandra.tar.gz"
  sudo rm -f "automatic_backup_postgres.tar.gz"
}
function main() {
  script_directory="$(cd "$(dirname "$0")" && pwd)"

  while true; do
    cd "$script_directory"
    configFilePath="../../../etc/automaticThingsboardBackup/automaticThingsboardBackupConfig.yml"
    lastBackupTimeFilePath="../../../etc/automaticThingsboardBackup/last_backup_time.txt"
    eval $(parse_yaml $configFilePath)
    backupIntervalInTs=$(($backupDayInterval * 86400))
    if [ -e "$lastBackupTimeFilePath" ]; then
      lastBackupTime=$(cat "$lastBackupTimeFilePath")
    else
      lastBackupTime=0
    fi
    spentTimeFromLastBackup=$(($(date +"%s") - $lastBackupTime))

    current_time=$(date +"%H:%M")

    # Convert backup time and current time to minutes since midnight
    backup_minutes=$((10#$(date -d "$backupTime" +%H) * 60 + 10#$(date -d "$backupTime" +%M)))
    current_minutes=$((10#$(date -d "$current_time" +%H) * 60 + 10#$(date -d "$current_time" +%M)))

    # Calculate the difference in minutes
    time_diff=$(($current_minutes - $backup_minutes))

    if [[ "$spentTimeFromLastBackup" -ge "$backupIntervalInTs" && $time_diff -ge 0 && $time_diff -le 30 ]]; then
      currentBackupTime="$(date +"%s")"
      checkConfigAndBackup
      CheckAndSaveBackups
      removeCurrentBackup
      echo $currentBackupTime >"$lastBackupTimeFilePath"
    fi

    echo "waiting . . . "
    sleep 30 # Delay for 30 second
  done

}

function handleSIGINT() {
  echo 'exiting . . .'
  script_directory="$(cd "$(dirname "$0")" && pwd)"
  cd "$script_directory"
  address=$saveFTPBackup_address
  gio mount -fu ftp://$address >/dev/null 2>&1 #disconnect FTP
  removeCurrentBackup
  exit
}
#set -x

script_directory="$(cd "$(dirname "$0")" && pwd)"
cd "$script_directory" || handleSIGINT
trap handleSIGINT SIGINT
main
