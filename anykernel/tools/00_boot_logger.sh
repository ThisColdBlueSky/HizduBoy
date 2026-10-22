#!/system/bin/sh
# 00_boot_logger.sh - Startup and crash logger for KernelSU
# Runs at post-fs-data stage (early boot, before zygote/system server)

LOG_DIR="/data/adb/boot_logs"
SD_LOG_DIR="/data/media/0/boot_logs"

mkdir -p "$LOG_DIR"
mkdir -p "$SD_LOG_DIR" 2>/dev/null || true

# 1. Rotate previous logs (keep up to 5)
rotate_logs() {
    base="$1"
    name="$2"
    for i in 4 3 2 1; do
        next=$((i + 1))
        [ -f "$base/${name}_$i.log" ] && mv -f "$base/${name}_$i.log" "$base/${name}_$next.log"
    done
    [ -f "$base/${name}.log" ] && mv -f "$base/${name}.log" "$base/${name}_1.log"
}

rotate_logs "$LOG_DIR" "kmsg"
rotate_logs "$LOG_DIR" "logcat"

# 2. Capture pstore/ramoops from the PREVIOUS boot (if last boot crashed or panicked)
if [ -d /sys/fs/pstore ]; then
    for f in /sys/fs/pstore/*; do
        if [ -f "$f" ]; then
            fname=$(basename "$f")
            cp -f "$f" "$LOG_DIR/last_crash_${fname}.log"
            cp -f "$f" "$SD_LOG_DIR/last_crash_${fname}.log" 2>/dev/null || true
        fi
    done
fi

# 3. Capture initial dmesg ring buffer immediately
dmesg > "$LOG_DIR/dmesg_boot.log"
cp -f "$LOG_DIR/dmesg_boot.log" "$SD_LOG_DIR/dmesg_boot.log" 2>/dev/null || true

# 4. Stream continuous kernel log in the background
# This writes to disk buffer so even if the device locks up or reboots,
# the final lines right before the crash are preserved on flash!
(
    cat /proc/kmsg >> "$LOG_DIR/kmsg.log"
) &

# 5. Stream logcat once logd is ready
(
    while ! logcat -v time -d >/dev/null 2>&1; do
        sleep 1
    done
    logcat -b all -v time >> "$LOG_DIR/logcat.log"
) &

# 6. Flush to storage and copy to /sdcard periodically
(
    while true; do
        sleep 5
        cp -f "$LOG_DIR/kmsg.log" "$SD_LOG_DIR/kmsg.log" 2>/dev/null || true
        cp -f "$LOG_DIR/logcat.log" "$SD_LOG_DIR/logcat.log" 2>/dev/null || true
        sync
        [ "$(getprop sys.boot_completed)" = "1" ] && break
    done
) &
