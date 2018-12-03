#!/bin/bash
array=($@)
len=${#array[@]}

for i in ${array[@]:0:$len};
do
  # Insert to ISPConfig database
  if [[ ${i:0:1} -eq 7 ]]; then
    mysql -uroot -ppassword -hlocalhost dbispconfig -e "insert into server_php (sys_userid, sys_groupid, sys_perm_user, sys_perm_group, sys_perm_other, server_id, client_id, name, php_fpm_init_script, php_fpm_ini_dir, php_fpm_pool_dir) values (1, 1, 'ruid', 'ruid', '', 1, 0, 'PHP $i', '/etc/init.d/php-$i-fpm', '/opt/php-$i/lib', '/opt/php-$i/etc/php-fpm.d');"
  fi
  if [[ ${i:0:1} -eq 5 ]]; then
    mysql -uroot -ppassword -hlocalhost dbispconfig -e "insert into server_php (sys_userid, sys_groupid, sys_perm_user, sys_perm_group, sys_perm_other, server_id, client_id, name, php_fpm_init_script, php_fpm_ini_dir, php_fpm_pool_dir) values (1, 1, 'ruid', 'ruid', '', 1, 0, 'PHP $i', '/etc/init.d/php-$i-fpm', '/opt/php-$i/lib', '/opt/php-$i/etc/pool.d');"
  fi

  cp /tmp/php-VERSION-fpm /etc/init.d/php-${i}-fpm && chmod +x /etc/init.d/php-${i}-fpm
  sed -i "s/VERSION/$i/" /etc/init.d/php-$i-fpm
done

