# thingsboard automatic backup

## a bash that automatically backups thingsboard databases.

## How To Run?

### install version :

1. download the latest version deb file
   from [releases](https://github.com/Mehranpr/thingsboard_automatic_backup/releases)
2. install package using this command : `sudo dpkg -i automaticThingsboardBackupPackage.deb`

### using dev mode:

1. fork repository
2. clone forked
3. run the following command:

```bash
sudo bash -ci "dbus-run-session bash {abs path to the repo}/automaticThingsboardBackupPackage/usr/bin/automaticThingsboardBackup/automaticThingsboardBackup.bash"
```

don't forgot to replace {abs path to the repo} with real abs path of this repo in local

## build from source

1. fork repository
2. clone forked
3. build package using this command : `dpkg-deb --build automaticThingsboardBackupPackage`
4. install using the following command: `sudo dpkg -i automaticThingsboardBackupPackage.deb`

## How To Config?

just edit automaticThingsboardBackupConfig.yml file

in install version file path is :

`/etc/automaticThingsboardBackup/automaticThingsboardBackupConfig.yml`

in dev file path is in repo folder :

`automaticThingsboardBackupPackage/etc/automaticThingsboardBackup/automaticThingsboardBackupConfig.yml`

### after edit config there is nothing need to do(bash automatically detect config changes)

## FEATURES

1. automatic backup in interval
2. back at specific time
3. backup of PostgreSQL
4. backup of cassandra
5. allow to save backup in local path
6. allow to save backup in FTP remote path
7. allow to limit backup count for limit save storage