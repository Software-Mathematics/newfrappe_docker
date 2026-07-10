# Patch layer for the SMERP (erpnext develop) + frappe version-14 combo.
#
# 1. frappe v14 pins its own rq fork (redis-3.5 compatible); ensure it's installed.
# 2. erpnext develop's e_commerce/redisearch_utils.py imports
#    `redis.commands.search` which only exists in redis-py >= 4.1, but frappe v14
#    pins redis~=3.5.3. Upgrade redis-py to a 4.x that satisfies both frappe/rq
#    and the RediSearch client.
FROM smerp:latest
USER frappe
RUN /home/frappe/frappe-bench/env/bin/pip install --force-reinstall --no-deps \
      "git+https://github.com/frappe/rq@8414b230e1fa797b40922351652f63552310046a" \
 && /home/frappe/frappe-bench/env/bin/pip install "redis==4.5.5"
