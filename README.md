# Description
Bash script for comressing data, useful for backup archives.

**Tested on RHEL (CentOS) 6!**

## Highlights

1. compresses the data into .tar.xz using 4 cores, level of compression set to 9 (can easy be changed)
2. stores previous archives in separate directory
3. flexible configuration
4. resources initial check (source, output, runtime directories read/write rights)
5. checks for lock file (prevents script execution if source is still created)
6. text formating (bold, colored)
7. e-mail sending on success and or fail
8. outputs compression info (source size, archive size, compression ratio)
9. loging and debuging (outputs more info about process)
10. possibility to change std output (to console and log or log only)
