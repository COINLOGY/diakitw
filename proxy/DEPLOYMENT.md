# Self-hosting template (not automatic deployment)

Use an isolated unprivileged service account, e.g. `diakitw`, and www-data as the
trusted reverse-proxy UID (the source default). Copy service.py to
/opt/emcx-diakitw-api/service.py. Create credentials/ and state/ as private directories
owned by the service account. Provision YOUR OWN provider token at credentials/token
with mode 0600, one hard link, owned by that account; never add it to Git or logs.
Initialize state/quota.db as the service user with `Quota.initialize` before enabling.
Create /run/emcx-diakitw-api accessible to the service and reverse proxy; socket 0660.
Start `python3 /opt/emcx-diakitw-api/service.py` under a hardened supervisor.
Upstream is disabled unless DIAKITW_UPSTREAM_ENABLED=1. Use TLS on api.example.com.

Example nginx location inside your existing TLS server (adapt permissions, do not
trust forwarded-IP headers from arbitrary clients):

```nginx
server_name api.example.com;
location = /geo {
    access_log off;
    proxy_set_header X-Diakitw-Client-IP $remote_addr;
    proxy_set_header X-Forwarded-For "";
    proxy_set_header Forwarded "";
    proxy_pass http://unix:/run/emcx-diakitw-api/api.sock:/geo;
    proxy_read_timeout 8s;
}
```

Keep the socket private: the app validates SO_PEERCRED/getpeereid, not a client
supplied identity. The public shared service is limited to 300 upstream attempts/day,
9000/month; this source uses the same conservative limits. No unlimited-use promise.
Change client proxy URLs for your own deployment. No production SSH host, operator
account, token or configuration is provided. This template was not deployed by publication.
