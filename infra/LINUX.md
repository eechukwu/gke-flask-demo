# Linux Interview Guide - Senior Cloud Level (20 Questions)

---

## Q1: How do you troubleshoot a server that's running slow?
```bash
# Check load average
uptime
top

# Check memory
free -h

# Check disk space and I/O
df -h
iostat -x 1

# Check processes
ps aux --sort=-%cpu | head
ps aux --sort=-%mem | head

# Check network
netstat -tulpn
ss -tulpn
```

**Approach:** CPU → Memory → Disk → Network → Processes

---

## Q2: Explain Linux file permissions. What does `chmod 755` mean?
```
rwx rwx rwx = owner group others
7   5   5
```

- **7 (rwx):** Owner can read, write, execute
- **5 (r-x):** Group can read, execute
- **5 (r-x):** Others can read, execute

**Common:**
- `755` - Executables, directories
- `644` - Regular files
- `600` - Private files (SSH keys)

---

## Q3: What's the difference between a process and a thread?

**Process:**
- Independent execution unit
- Own memory space
- Created via `fork()`
- Higher overhead

**Thread:**
- Runs within a process
- Shares memory with other threads
- Lower overhead
- Can cause race conditions

---

## Q4: How do you find which process is using a specific port?
```bash
# Using lsof
lsof -i :8080

# Using netstat
netstat -tulpn | grep 8080

# Using ss (modern)
ss -tulpn | grep 8080

# Using fuser
fuser 8080/tcp
```

---

## Q5: Explain the boot process of a Linux system.

1. **BIOS/UEFI:** Hardware initialization
2. **Bootloader (GRUB):** Loads kernel
3. **Kernel:** Initializes hardware, mounts root filesystem
4. **init/systemd:** First process (PID 1)
5. **Services:** Start based on runlevel/target
6. **Login:** User authentication

---

## Q6: What is systemd? How do you manage services?

**systemd** = Init system and service manager (PID 1)
```bash
systemctl status nginx
systemctl start nginx
systemctl stop nginx
systemctl restart nginx
systemctl enable nginx   # Start on boot
systemctl disable nginx

# View logs
journalctl -u nginx
journalctl -u nginx -f          # Follow
journalctl -u nginx --since "1 hour ago"
```

---

## Q7: How do you check disk usage and find large files?
```bash
# Disk usage summary
df -h

# Directory sizes
du -sh /var/*
du -sh * | sort -hr | head -20

# Find large files
find / -type f -size +100M 2>/dev/null
find /var -type f -size +50M -exec ls -lh {} \;

# ncdu (interactive)
ncdu /
```

---

## Q8: Explain inodes. What happens when you run out?

**Inode** = Data structure storing file metadata (permissions, owner, timestamps, block pointers).

**Run out of inodes:** Can't create new files even with free disk space.
```bash
# Check inode usage
df -i

# Find directories with many files
find / -xdev -type d -exec sh -c 'echo "$(find "$1" -maxdepth 1 | wc -l) $1"' _ {} \; | sort -rn | head
```

---

## Q9: How do you troubleshoot network connectivity issues?
```bash
# Check interface
ip a
ip link show

# Check routing
ip route
route -n

# Test connectivity
ping 8.8.8.8          # Network layer
ping google.com       # DNS resolution

# DNS troubleshooting
cat /etc/resolv.conf
dig google.com
nslookup google.com

# Port connectivity
nc -zv host 443
telnet host 443
curl -v https://host

# Trace route
traceroute google.com
mtr google.com
```

---

## Q10: What is the difference between soft and hard links?

**Hard link:**
- Same inode as original
- Can't cross filesystems
- Can't link directories
- Survives original deletion

**Soft link (symlink):**
- Points to path name
- Can cross filesystems
- Can link directories
- Breaks if original deleted
```bash
ln file hardlink
ln -s file softlink
```

---

## Q11: How do you check and kill zombie processes?

**Zombie** = Finished process waiting for parent to read exit status.
```bash
# Find zombies
ps aux | grep 'Z'
ps -eo pid,ppid,stat,cmd | grep -w Z

# Kill parent (zombies can't be killed directly)
kill -9 <PPID>
```

---

## Q12: Explain `/proc` filesystem. How is it useful?

**/proc** = Virtual filesystem exposing kernel and process info.
```bash
# System info
cat /proc/cpuinfo
cat /proc/meminfo
cat /proc/loadavg

# Process info
cat /proc/<PID>/status
cat /proc/<PID>/cmdline
cat /proc/<PID>/fd        # Open file descriptors

# Network
cat /proc/net/tcp
```

---

## Q13: How do you secure SSH access?
```bash
# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers deploy admin
Port 2222                    # Change default port
MaxAuthTries 3

# Restart SSH
systemctl restart sshd
```

**Additional:**
- Use SSH keys only
- Fail2ban for brute force protection
- Firewall rules (allow specific IPs)

---

## Q14: What is swap? When would you add more?

**Swap** = Disk space used when RAM is full.
```bash
# Check swap
free -h
swapon --show

# Create swap file
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

**Add swap when:** Low memory, hibernation needed, memory-intensive batch jobs.

---

## Q15: How do you analyze logs efficiently?
```bash
# Tail logs
tail -f /var/log/syslog
tail -100 /var/log/nginx/error.log

# Search logs
grep "ERROR" /var/log/app.log
grep -i "failed" /var/log/auth.log

# With context
grep -B5 -A5 "error" app.log

# Count occurrences
grep -c "404" access.log

# Unique entries
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head

# journalctl (systemd)
journalctl -p err          # Errors only
journalctl --since "1 hour ago"
journalctl -u nginx -f
```

---

## Q16: Explain cgroups and namespaces (container foundations).

**Cgroups (Control Groups):**
- Limit resource usage (CPU, memory, I/O)
- Used by Docker to limit container resources

**Namespaces:**
- Isolate system resources
- Types: PID, Network, Mount, User, UTS, IPC
- Each container gets own namespaces

**Together:** Foundation of container isolation.

---

## Q17: How do you set up a cron job? What is crontab syntax?
```bash
# Edit crontab
crontab -e

# Syntax: minute hour day month weekday command
# 0 2 * * * /backup.sh        # Daily at 2am
# */15 * * * * /health.sh     # Every 15 minutes
# 0 0 * * 0 /weekly.sh        # Weekly on Sunday

# List cron jobs
crontab -l

# System cron
/etc/crontab
/etc/cron.d/
/etc/cron.daily/
```

---

## Q18: What happens when you type a command and press Enter?

1. **Shell reads input**
2. **Parsing:** Tokenize, expand variables, globs
3. **Command lookup:** Built-in → alias → PATH
4. **Fork:** Create child process
5. **Exec:** Replace child with command
6. **Wait:** Parent waits for child
7. **Exit:** Return exit code

---

## Q19: How do you manage users and groups?
```bash
# Users
useradd -m -s /bin/bash username
passwd username
usermod -aG sudo username
userdel -r username

# Groups
groupadd developers
usermod -aG developers username
groups username

# Sudoers
visudo
# username ALL=(ALL:ALL) NOPASSWD: ALL
```

---

## Q20: Explain TCP vs UDP. When use each?

**TCP:**
- Connection-oriented
- Reliable, ordered delivery
- Flow control, error correction
- **Use:** HTTP, SSH, databases

**UDP:**
- Connectionless
- No guarantee of delivery
- Lower latency, less overhead
- **Use:** DNS, streaming, gaming, VoIP

---

## Quick Reference - Daily Commands

### Filesystem
```bash
pwd / ls -la / cd / tree
mkdir / touch / cp -r / mv / rm -r
find . -name "*.log"
df -h / du -sh
```

### File Contents
```bash
cat / head / tail -f
grep -r "pattern" .
less / vim
```

### Processes
```bash
ps aux / top / htop
kill -9 <PID>
systemctl status/start/stop/restart
journalctl -u <service> -f
```

### Networking
```bash
ip a / ip route
ping / curl / nc -zv host port
ss -tulpn / netstat -tulpn
```

### Users & Permissions
```bash
chmod 755 / chown user:group
useradd / usermod -aG / passwd
```
