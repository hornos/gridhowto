# SELinux
if [ ! -z "$PS1" ] ; then
  SEROLE=`secon -rP 2>/dev/null`
  SEMLS=`secon -lP 2>/dev/null`
  PS1="[\u/$SEROLE/$SEMLS@\h \W]\\$ "
  export PS1
fi
