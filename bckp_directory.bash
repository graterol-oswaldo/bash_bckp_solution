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
#      todoslos equipos, de modo de poder tener todos los registros en un único lugar.
#
#LICENCIA._______________________________________________________________________________
# Copyright (c) 2005-2006 nixCraft <http://www.cyberciti.biz/fb/>
# Copyright (c) 2016-2016 Oswaldo Graterol
# Este script esta licenciado bajo GNU GPL version 3.0 o superior
#
#*****************************************************************************************


### Configuracion del Sistema ###
NOW=$(date +"%Y%m%d%H%M")
#Nota: En `DIRS_SRC_BCKP` puedes indicar serparados por espacios las rutas absolutas de todos los directorios
#      que se deseen respaldar. 
DIRS_SRC_BCKP="/var/www/development/encuestas /var/www/development/ngQuiz"
TMP_DIR_DST_BCKP="backups"
TMP_FILE_DST_BCKP="bckp_directory_"
FILE_NAME=`basename "$0"`
HOST_IP=`ifconfig eth0| grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

### Configuracion SSH/SCP ###
REMOTE_USER="root"
REMOTE_HOST="192.168.56.101"
REMOTE_DIR_DST="/servidores/192.168.56.1"

########## SCRIPT DE RESPALDO ##########

spy=0
cat /dev/null > /tmp/script_log.err
rm -r  "/${TMP_DIR_DST_BCKP}" 2>/dev/null

function fc_msg {

case $1 in
	1 ) out="Creando Directorio de Respaldo";;
	2 ) out="Comprimiendo el Directorio de Respaldo";;
	3 ) out="Copiando el Respaldo al Destino Remoto";;
	4 ) out="[INFO]...Preparando Bitacora";;
	5 ) out="Copiando Bitacora al Destino Remoto";;
	6 ) out="********************  Inicio de Ejecucion: Instrucciones de Respaldo de Directorios  ********************";;
	7 ) out="*********** Fin de Ejecucion: Instrucciones de Respaldo Completadas - (flag de Errores: $spy) ***********";;
	8 ) out="Eliminando Contenido del Directorio de Respaldo";;
esac

echo " $out"
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
	error=$(wc -c /tmp/script_log.err | awk '{print $1}')
	if [[ $error > 0 ]] 
	then
		spy=1
		cat /tmp/script_log.err
		break;
	fi
}

fc_msg 6


while [ $spy = 0 ]; do

if [ ! -d "/${TMP_DIR_DST_BCKP}" ]; then
		mkdir "/${TMP_DIR_DST_BCKP}"
		fc_valida $?
		fc_msg 1
		fc_error
fi

tar -zcf /${TMP_DIR_DST_BCKP}/${TMP_FILE_DST_BCKP}${NOW}.tar.gz -P ${DIRS_SRC_BCKP} 2>/tmp/script_log.err
fc_valida $?
fc_msg 2
fc_error

scp -r /${TMP_DIR_DST_BCKP} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR_DST}/. 2>/tmp/script_log.err
fc_valida $?
fc_msg 3
fc_error

fc_msg 4
CHKSUM=`sha1sum "/${TMP_DIR_DST_BCKP}/${TMP_FILE_DST_BCKP}${NOW}.tar.gz"` 2>/tmp/script_log.err
fc_error
FILE_SIZE=`stat -c%s "/${TMP_DIR_DST_BCKP}/${TMP_FILE_DST_BCKP}${NOW}.tar.gz"` 2>/tmp/script_log.err
fc_error
NOWLOG=`date +%F' '%T`

LOG="$NOWLOG $HOST_IP $USERNAME $CHKSUM $FILE_SIZE $FILE_NAME" 2>/tmp/script_log.err
fc_error

ssh $REMOTE_USER@$REMOTE_HOST echo $LOG  \| awk "'{print $1}'" \>\> ${REMOTE_DIR_DST}/${TMP_DIR_DST_BCKP}/bckp.log 2>/tmp/script_log.err
fc_valida $?
fc_msg 5

rm -r  $TMP_DIR_DST_BCKP 2>/tmp/script_log.err
break
done;

fc_msg 7
