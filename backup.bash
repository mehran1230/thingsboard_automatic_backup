
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
  echo "Backup PostgreSQL Completed."
}
function backupCassandra() {
  echo "Backup Cassandra . . . "
  sudo systemctl stop thingsboard
  nodetool drain
  sudo systemctl stop cassandra
  tar cvf - /var/lib/cassandra/ 2>/dev/null | gzip -9 - >automatic_backup_cassandra.tar.gz
  sudo systemctl restart cassandra
  sudo systemctl restart thingsboard
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

  export FTPFileNameIndex=0
  export FTPFileNameDate=$(date +"%Y_%m_%d")

  while [[ -e "${saveFTPBackup_location}automatic_backup_postgres_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz" || -e "${saveFTPBackup_location}automatic_backup_cassandra_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz" ]]; do
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
  address=$saveFTPBackup_address
  port=$saveFTPBackup_port

  ftp_path="1111"
  #  encoded_username=$(printf "%s" "$username" | jq -s -R -r @uri)
  #  encoded_password=$(printf "%s" "$password" | jq -s -R -r @uri)
  #  encoded_address=$(printf "%s" "$address" | jq -s -R -r @uri)
  echo "connecting to FTP . . ."
  gio mount "ftp://${address}:${port}" <<<"$username
$password" # make sure there is no space before $password
check_folder='ftp:host=ftp.arvinet.com'
mount_pathes=$(mount | grep gvfsd-fuse)
addresses=$(echo "$mount_pathes" | grep -oP '/\S+')



for address in $addresses; do
  if [[ -d "$address/$check_folder" ]]; then
    ftp_path="$address/$check_folder"
  fi

done
if [[ "$ftp_path" = "1111" ]]; then
  handleSIGINT
fi
  cd $ftp_path || handleSIGINT
  sudo mkdir -p ".${saveFTPBackup_location}" || handleSIGINT
  script_directory="$(cd "$(dirname "$0")" && pwd)"
  cd "$script_directory" || handleSIGINT
  echo "FTP is connected."
  createBackupFileNameForFTP
  #region postgreSQL
  if [ "$PostgreSQLBackupEnabled" = "true" ]; then
    echo "FTP Saving PostgreSQL . . ."
    sudo rsync --progress automatic_backup_postgres.tar.gz "${ftp_path}${saveFTPBackup_location}automatic_backup_postgres_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz"
    echo "PostgreSQL saved in FTP ${saveFTPBackup_location}automatic_backup_postgres_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz"
    # region remove old files if count is bigger than config file
    files=("${ftp_path}${saveFTPBackup_location}automatic_backup_postgres_"*)

    if [[ ${#files[@]} -gt $saveFTPBackup_maximumBackupsCount ]]; then
      # Sort files by creation time in ascending order
      sorted_files=($(ls -t -r -U "${files[@]}"))

      # Calculate the number of files to remove
      num_files_to_remove=$((${#files[@]} - saveFTPBackup_maximumBackupsCount))

      # Remove the oldest files
      for ((i = 0; i < num_files_to_remove; i++)); do
        file_to_remove="${sorted_files[i]}"
        sudo rm -f "$file_to_remove"
        echo "Removed file: $file_to_remove"

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
    echo "FTP Saving Cassandra . . ."
    sudo rsync --progress automatic_backup_cassandra.tar.gz "${ftp_path}${saveFTPBackup_location}automatic_backup_cassandra_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz"
    echo "Cassandra saved in FTP ${saveFTPBackup_location}automatic_backup_cassandra_${FTPFileNameDate}_${FTPFileNameIndex}.tar.gz"
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
        sudo rm -f "$file_to_remove"
        echo "Removed file: $file_to_remove"

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
            sudo mv ${file} ${base_name}_${new_index}.tar.gz
          fi
          new_index=$((new_index + 1))
        done

      done
    fi
    #endregion
  fi
  #endregion
  address=$saveFTPBackup_address
  gio mount -u ftp://$address #disconnect FTP
  echo "FTP is Disconnected"
}
function CheckAndSaveBackups() {
  if [ "$saveLocalBackup_enabled" = "true" ]; then
    saveLocal
  fi
  if [ "$saveFTPBackup_enabled" = "true" ]; then
    saveFTP
  fi
}
function checkInterval() {
  return 0

}
function removeCurrentBackup() {
  sudo rm -f "automatic_backup_cassandra.tar.gz"
  sudo rm -f "automatic_backup_postgres.tar.gz"
}
function main() {
  eval $(parse_yaml backupConfig.yaml)
  checkConfigAndBackup
  CheckAndSaveBackups
  removeCurrentBackup
}
function handleSIGINT() {
  echo 'exiting . . .'
  script_directory="$(cd "$(dirname "$0")" && pwd)"
  cd "$script_directory"
  address=$saveFTPBackup_address
  gio mount -u ftp://$address #disconnect FTP
  removeCurrentBackup
  exit
}
#set -x

script_directory="$(cd "$(dirname "$0")" && pwd)"
cd "$script_directory" || handleSIGINT
trap handleSIGINT SIGINT
main
