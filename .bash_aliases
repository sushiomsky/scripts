
#####################
# alias definitions #
#####################
alias c='clear'
alias cd..='cd ..' 
 
## a quick way to get out of current directory ##
alias ..='cd ..' 
alias ...='cd ../../../' 
alias ....='cd ../../../../' 
alias .....='cd ../../../../' 
alias .4='cd ../../../../' 
alias .5='cd ../../../../..'

## Colorize the ls output ##
alias ls='ls --color=auto'
 
## Use a long listing format ##
alias ll='ls -la' 
 
## Show hidden files ##
alias l.='ls -d .* --color=auto'

# if user is not root, pass all commands via sudo #
if [ $UID -ne 0 ]; then
    alias reboot='sudo reboot'
fi

## Colorize the grep command output for ease of use (good for log files)##
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Create parent directories on demand
alias mkdir='mkdir -pv'

# install  colordiff package :)
alias diff='colordiff'

alias mount='mount |column -t'

# Stop after sending count ECHO_REQUEST packets #
alias ping='ping -c 5'
# Do not wait interval 1 second, go fast #
alias fastping='ping -c 100 -s.2'

## shortcut  for iptables and pass it via sudo#
alias ipt='sudo /sbin/iptables'
 
# display all rules #
alias iptlist='sudo /sbin/iptables -L -n -v --line-numbers'
alias iptlistin='sudo /sbin/iptables -L INPUT -n -v --line-numbers'
alias iptlistout='sudo /sbin/iptables -L OUTPUT -n -v --line-numbers'
alias iptlistfw='sudo /sbin/iptables -L FORWARD -n -v --line-numbers'
alias firewall=iptlist

# distro specific  - Debian / Ubuntu and friends #
# install with apt-get
alias apt="sudo apt-get" 
alias apti="sudo apt-get install --yes" 
alias aptr="sudo apt-get remove --yes" 
alias aptp="sudo apt-get purge --yes" 

# update on one command 
alias aptdate='sudo apt-get update'
alias aptgrade='sudo apt-get upgrade'

# init script enable/disable managment
alias einit="update-rc.d $1 enable"
alias dinit="update-rc.d $1 disable"

#start/stop daemon
alias rserv="service $1 restart"
alias sserv="service $1 stop"
alias staserv="service --status-all"
alias stserv="service $1 --status"

#git shortcuts
alias gitcl="git clone"
alias gitad="git add"
alias gitco="git commit -m"
alias gitpl="git pull"
alias gitpu="git push"
alias gitst="git status"
alias gitbr="git branch"
alias gitch="git checkout"
alias commitpush="git add .; git commit -m auto ; git push"

## pass options to free ## 
alias meminfo='free -m -l -t'
 
## get top process eating memory
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
 
## get top process eating cpu ##
alias pscpu='ps auxf | sort -nr -k 3'
alias pscpu10='ps auxf | sort -nr -k 3 | head -10'
 
## Get server cpu info ##
alias cpuinfo='lscpu'
 
## this one saved by butt so many times ##
alias wget='wget -c'

## set some other defaults ##
alias df='df -H'
alias du='du -ch'
 
# top is atop, just like vi is vim
alias top='atop' 
 
alias dmesg='dmesg -w'
alias syslogs='tail -f /var/log/syslog'
alias daemonlogs='tail -f /var/log/daemon.log'

