#!/bin/bash
#****************************************************************************************
#DESCRIPCION.____________________________________________________________________________
#Este script permite una vez establecidas las configuraciones correspondientes, respaldar 
#el directorio o directorios indicados, comprimirlo y copiarlo en un equipo de computación 
#remoto. Así mismo, durante su ejecución se genera una bitácora que también es enviado a un 
#equipo remoto e incluido en un archivo donde reposan todos los demás registros de bitácoras.
#
#INSTALACION.____________________________________________________________________________
#(1)Copiar este script en cada equipo donde se desee efectuar la tarea de respaldo.
#(2)Establece por cada equipo las configuraciones correspondientes.
#(3)Programar tarea de respaldo para su ejecución periódica.
#NOTA: Considerar que las configuraciones relativas a las bitácoras., deben ser las mimas en
#todoslos equipos, de modo de poder tener todos los registros en un único lugar.
#
#LICENCIA._______________________________________________________________________________
# Copyright (c) 2005-2006 nixCraft <http://www.cyberciti.biz/fb/>
# Copyright (c) 2016-2016 Oswaldo Graterol
# This script is licensed under GNU GPL version 2.0 or above
#
#*****************************************************************************************


### Configuracion del Sistema ###
NOW=$(date +"%Y%m%d%H%M")
TMP_FILE_DST_BCKP="bckp_MySQL_DB_"
TMP_DIR_DST_BCKP="backups"
TMP_DIR_DST_SQL_FILES="backups_mysql_db"
FILE_NAME_BCKP="/$TMP_DIR_DST_SQL_FILES/$TMP_FILE_DST_BCKP$NOW.gz"
FILE_NAME=`basename "$0"`
HOST_IP=`ifconfig eth0| grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
TMP_ERROR_LOG=$(mktemp -d)

### Configuracion MySQL ###
MUSER="admin"
MPASS="mysqladminpassword"
MHOST="localhost"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
GZIP="$(which gzip)"
#Nota: En `DBS` indica los nombres de las Base de Datos correspondientes al servidor de MySQL configurado 
#      que desees respaldar. 
DBS=(SIACE local_wp)


### Configuracion SSH/SCP ###
REMOTE_USER="root"
REMOTE_HOST="192.168.56.101"
REMOTE_DIR_DST="/servidores/192.168.56.1"

########## SCRIPT DE RESPALDO ##########

spy=0
touch ${TMP_ERROR_LOG}/script_log.err
rm -r  /$TMP_DIR_DST_SQL_FILES 2>/dev/null
rm -r  /$TMP_DIR_DST_BCKP 2>/dev/null

function fc_msg {

case $1 in
	1 ) out="Creando Directorio de Respaldo";;
	2 ) out="Efectuando Respaldo de MySQL BD: ";;
	3 ) out="Copiando el Respaldo al Destino Remoto";;
	4 ) out="[INFO]...Preparando Bitacora";;
	5 ) out="Copiando Bitacora al Destino Remoto";;
	6 ) out="*****************  Inicio de Ejecucion: Instrucciones de Respaldo de Base de Datos MySQL *****************";;
	7 ) out="***********  Fin de Ejecucion: Instrucciones de Respaldo Completadas - (flag de Errores: $spy) ***********";;
	8 ) out="Eliminando Contenido del Directorio de Respaldo";;
	9 ) out="Generando empaquetado de TODOS los respaldo de BD de MySQL ";;
	10 ) out="Creando Directorio de Respaldo para archivos SQL";;
esac

echo $2 " $out"
}

function fc_valida {
	if [ $1 == 0 ] 
	then 
		echo -n " [OK]..." 
	else 
		echo -n " [ERROR]..."
	fi
}

function fc_error {
	error=$(wc -c ${TMP_ERROR_LOG}/script_log.err | awk '{print $1}')
	if [[ $error > 0 ]] 
	then
		spy=1
		cat ${TMP_ERROR_LOG}/script_log.err
		break;
	fi
}

fc_msg 6


while [ $spy = 0 ]; do

	if [ ! -d /$TMP_DIR_DST_SQL_FILES ]; then
			mkdir -p /$TMP_DIR_DST_SQL_FILES
			fc_valida $?
			fc_msg 10
			fc_error
	fi

	### Inicio de Respaldo de Base de Datos - MySQL ###
	for DB in ${DBS[@]}; 
	do
	  SQLFILE="/${TMP_DIR_DST_SQL_FILES}/${NOW}_${DB}.sql.gz"
	  sh -c "$MYSQLDUMP -ubckpdbuser $DB | $GZIP -9 > $SQLFILE" 2>${TMP_ERROR_LOG}/script_log.err
	  fc_valida $?
	  fc_msg 2 -n 
	  echo $DB
	  fc_error
	done


	if [ ! -d /$TMP_DIR_DST_BCKP ]; then
			mkdir -p /$TMP_DIR_DST_BCKP
			fc_valida $?
			fc_msg 1
			fc_error
	fi

	tar -zcf /${TMP_DIR_DST_BCKP}/${TMP_FILE_DST_BCKP}${NOW}.tar.gz -P /${TMP_DIR_DST_SQL_FILES} 2>${TMP_ERROR_LOG}/script_log.err
	fc_valida $?
	fc_msg 9
	fc_error

	scp -r /${TMP_DIR_DST_BCKP} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR_DST}/. 2>${TMP_ERROR_LOG}/script_log.err
	fc_valida $?
	fc_msg 3
	fc_error


	fc_msg 4
	### Preparacion de logs - Respaldo de Base de Datos - MySQL ###
	for FILE in /${TMP_DIR_DST_SQL_FILES}/*.sql.gz
	do
	  CHKSUM=`sha1sum "${FILE}"` 2>${TMP_ERROR_LOG}/script_log.err
	  fc_error
	  FILE_SIZE=`stat -c%s "${FILE}"` 2>${TMP_ERROR_LOG}/script_log.err 
	  fc_error
	  NOWLOG=`date +%F' '%T`
	  LOG="$NOWLOG $HOST_IP $USERNAME $CHKSUM $FILE_SIZE $FILE_NAME" 2>${TMP_ERROR_LOG}/script_log.err
	  fc_error
	  ssh $REMOTE_USER@$REMOTE_HOST echo $LOG  \| awk "'{print $1}'" \>\> ${REMOTE_DIR_DST}/${TMP_DIR_DST_BCKP}/bckp.log 2>${TMP_ERROR_LOG}/script_log.err
	  fc_valida $?
	  fc_msg 5
	done

	for FILE in /${TMP_DIR_DST_BCKP}/${TMP_FILE_DST_BCKP}${NOW}.tar.gz
	do
	  CHKSUM=`sha1sum "${FILE}"` 2>${TMP_ERROR_LOG}/script_log.err
	  fc_error
	  FILE_SIZE=`stat -c%s "${FILE}"` 2>${TMP_ERROR_LOG}/script_log.err 
	  fc_error
	  NOWLOG=`date +%F' '%T`
	  LOG="$NOWLOG $HOST_IP $USERNAME $CHKSUM $FILE_SIZE $FILE_NAME" 2>${TMP_ERROR_LOG}/script_log.err
	  fc_error
	  i=$((i+1))
	  ssh $REMOTE_USER@$REMOTE_HOST echo $LOG  \| awk "'{print $1}'" \>\> ${REMOTE_DIR_DST}/${TMP_DIR_DST_BCKP}/bckp.log 2>${TMP_ERROR_LOG}/script_log.err
	  fc_valida $?
	  fc_msg 5
	done


	rm -r  /$TMP_DIR_DST_BCKP 2>/dev/null
	rm -r  /$TMP_DIR_DST_SQL_FILES 2>/dev/null
	break
done;

fc_msg 7