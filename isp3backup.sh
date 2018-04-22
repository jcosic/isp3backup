#!/bin/sh
#
# THIS SCRIPT HAS BEEN UPDATED BY JOHANN COSIC (www.johann-cosic.oramail.fr). PLEASE SEE
# BELOW FOR ORIGINAL SCRIPT AUTHORS.
#
# ISPConfig3 back-up script based on bak-res script by go0ogl3 gabi@eurosistems.ro
#
# Copyright (c) Ioannis Sannos ( http://www.isopensource.com )
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# The above copyright notice and this permission notice shall be included in
# all copies of the script.
#
# description: A backup script for sites and databases on ISPConfig 3 servers
# Add this script in cron tab in order to be executed once per day.
# Example (00:00 at night every day):
# 00 00 * * * /usr/bin/isp3backup.sh &> /dev/null
#
# author: Ioannis Sannos
# date: 2010-03-06 13:45:10
# website: http://www.isopensource.com
# The state of development is "It works for me"!
# So don't blame me if anything bad will happen to you or to your computer
# if you use this script.
#
# updated by: Alex Ward
# date: 2012-02-16 22:31:00
# website: https://www.geekonthepc.com/tag/ispc3backup/
# Script works, but no liability is taken for script failure or any damage done.
#
# updated by: Johann Cosic
# date: 2018-04-22 16:50:00 UTC
# website: https://johann-cosic.oramail.fr
#

## For log, precede with date
dateStatement(){
    date +'%F %H:%M:%S'
}

## Do not edit this section
SCRIPTVERSION="1.5"
FDATE=`date +%F`		# Full Date, YYYY-MM-DD, year sorted, eg. 2009-11-21

## End of non-editable variables

## Start user editable variables
CLIENTSDIR="/var/www/clients" 		# directory where ICPConfig 3 clients folders are located
MAILDIR="/var/vmail"					# mail directory
LETSENCRYPTDIR="/etc/letsencrypt"   #letsencrypt directory
HTTPDIR="/var/log/ispconfig/httpd" #httpd directory
APACHE2DIR="/etc/apache2"  #apache dir

BACKUPDIR="/backup"					# backup directory
LOGDIR="/var/log/isp3backup"   #log directory
TMPDIR="/tmp/tmpbck"				# temp dir for database dump and other stuff

DBUSER=""						 # database user
DBPASS=""				# database password

FTPBACKUP=1         # Activate FTP Backup
FTPMAXBACKUP=2      # Max number of backups saved on FTP Server

FTPHOST='' #FTP HOST
FTPUSER=''          # FTP USER
FTPPASSWD=''        # FTP PASSWORD
FTPBACKUPDIR='ispconfig_backup' #FTP directory for backup. Please create it before proceed

## End user editable variables

if [ ! -d $LOGDIR/ ] ; then
  mkdir $LOGDIR/
fi

message="Start backup ... "
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

########### Start make and check needed directories #############

message="Checking directories exist..."
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

###### Start backup directory verification
if [ ! -d $BACKUPDIR/ ] ; then
  message="Backup directory doesn't exist. Please create it before proceed."
  echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
  exit 0
fi
###### End backup directory verification

###### Start removing old backups files

message="Remove old backups"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
echo $date $message

rm -R $BACKUPDIR/*

message="Old backups removed"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
###### End removing old backups files

###### Start temp directory creation

message="Temp directory verification"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

if [ ! -d $tmpdir/ ] ; then
  mkdir $tmpdir/

  message="Temp directory created."
  echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
fi
###### End temp directory creation

###### Start create backup sub-directories

message="Start create sub-directories"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

mkdir $BACKUPDIR/$FDATE/
mkdir $BACKUPDIR/$FDATE/httpd/
mkdir $BACKUPDIR/$FDATE/apache2/
mkdir $BACKUPDIR/$FDATE/db/
mkdir $BACKUPDIR/$FDATE/webs/
mkdir $BACKUPDIR/$FDATE/vmail/
mkdir $BACKUPDIR/$FDATE/users/
mkdir $BACKUPDIR/$FDATE/letsencrypt/

message="Sub-directories created"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
###### End create backup sub-directories
########### End make and check needed directories #############

########### Start ispconfig/httpd backup #############

message="Start Ispconfig/httpd backup"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

tar -zcpf $BACKUPDIR/$FDATE/httpd/httpd.tar.gz $HTTPDIR

message="Ispconfig/httpd backup completed"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

########### End ispconfig/httpd backup #############

########### Start apache2 backup #############

message="Start Apache2 backup"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

tar -zcpf $BACKUPDIR/$FDATE/apache2/sites-available.tar.gz $APACHE2DIR/sites-available
tar -zcpf $BACKUPDIR/$FDATE/apache2/sites-enabled.tar.gz $APACHE2DIR/sites-enabled

message="Apache2 backup completed"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

########### End apache2 backup #############

########### Start databases backup #############
message="Start MySQL databases backup"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log


message="Logged in as user: "$DBUSER
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

# check and fix any errors found
mysqlcheck -u$DBUSER -p$DBPASS --all-databases --optimize --auto-repair --silent 2>&1
# Starting database dumps
for i in `mysql -u$DBUSER -p$DBPASS -Bse 'show databases'`; do
  `mysqldump -u$DBUSER -p$DBPASS $i --allow-keywords --comments=false --add-drop-table > $TMPDIR/db-$i-$FDATE.sql`
  tar -zcpf $BACKUPDIR/$FDATE/db/$i.tar.gz -C $TMPDIR db-$i-$FDATE.sql
  rm -rf $TMPDIR/db-$i-$FDATE.sql


  message=$i" backed-up"
  echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
done


message="MySQL databases backup completed"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
########### End databases backup #############

########### Start websites backup #############

message="Start websites backup"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

clientslist=`ls $CLIENTSDIR | grep ^client`
for client in $clientslist; do
  if [ -d $CLIENTSDIR/$client/ ] ; then

# create sub-directory for this client

    message="Sub-directory creation: $BACKUPDIR/$FDATE/webs/$client/"
    echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

    mkdir $BACKUPDIR/$FDATE/webs/$client


    message="Sub-directory created"
    echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

# list all websites for this client
    webslist=`ls $CLIENTSDIR/$client/ | grep ^web`
    for web in $webslist; do
      if [ -d $CLIENTSDIR/$client/$web/ ] ; then
        cd $CLIENTSDIR/$client/$web/
        tar -zcpf $BACKUPDIR/$FDATE/webs/$client/$web.tar.gz .

        message="Website backup completed $client/$web"
        echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
      fi
    done
  fi
done


message="All websites backup completed"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
########### End websites backup #############

########### Start mails backup #############

message="Start email backup"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

mailslist=`ls $MAILDIR`
for mail in $mailslist; do
  if [ -d $MAILDIR/ ] ; then
    cd $MAILDIR/$mail/
    tar -zcpf $BACKUPDIR/$FDATE/vmail/$mail.tar.gz .


    message="Mail backed-up: "$mail
    echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
  fi
done


message="Emails backup completed"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
########### End mails backup #############

########### Start users backup #############


message="Start users backup"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

export UGIDLIMIT=5000
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/passwd > $BACKUPDIR/$FDATE/users/passwd.bk
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534)' /etc/group > /$BACKUPDIR/$FDATE/users/group.bk
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534) {print $1}' /etc/passwd | tee - |egrep -f - /etc/shadow > $BACKUPDIR/$FDATE/users/shadow.bk
awk -v LIMIT=$UGIDLIMIT -F: '($3>=LIMIT) && ($3!=65534) {print $1}' /etc/passwd | tee - |egrep -f - /etc/gshadow > $BACKUPDIR/$FDATE/users/gshadow.bk

message="Users backup completed"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

########### End user backup #############

########### Start let's encrypt backup #############

message="Start LetsEncrypt backup"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

tar -zcpf $BACKUPDIR/$FDATE/letsencrypt/letsencrypt.tar.gz $LETSENCRYPTDIR

message="LetsEncrypt backup completed"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

########### End let's encrypt backup #############


########### Start compression #############

message="Start compression"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

tar -zcpf $BACKUPDIR/$FDATE.tar.gz $BACKUPDIR/$FDATE/
rm -R $BACKUPDIR/$FDATE


message="Compression completed"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
########### End compression #############

########### Start ftp save #############
if ((FTPBACKUP == 1 )); then

  message="Start FTP save"
  echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

oldBackup=`date -d "-$FTPMAXBACKUP days" +%F`
backupFile=$BACKUPDIR/$FDATE.tar.gz

ftp -n $FTPHOST <<END_SCRIPT
quote USER $FTPUSER
quote PASS $FTPPASSWD
binary
cd $FTPBACKUPDIR
put $backupFile $FDATE.tar.gz
delete $oldBackup.tar.gz
quit
END_SCRIPT

message="FTP save completed"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log
fi
########### End ftp save #############

# all done

message="Process completed. See you tomorrow"
echo $(dateStatement) $message | tee -a $LOGDIR/$FDATE.log

exit 0
