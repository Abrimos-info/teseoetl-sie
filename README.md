# TeseoETL

## Requirements
- Two servers with 16gb of memory each.
- Storage - around double what you want to store.
- docker
- Git (with ssh key) for accesssing this repo
- nginx (for docker compose deploy) or ingress
- certbot

Tested in Ubuntu 24.04, but should work everywhere else.

## Install via docker compose with nginx

Clone this repository in both servers
`git clone git@github.com:Abrimos-info/teseoetl.git`

### Enable access
There needs to be three subdomains configured in your DNS server:
- nifi.[YOURDOMAIN] pointed to server 1
- opensearch.[YOURDOMAIN] pointed to server 2
- dashboards.[YOURDOMAIN] pointed to server 2

An example nginx configuration looks like this, this file would be in `/etc/nginx/sites-enabled/[SUBDOMAIN].[YOURDOMAIN].yml`
There needs to be three, one for each subdomain.

```
server {
        server_name [SUBDOMAIN].[YOURDOMAIN];
        root /var/www/html;
        location / {
                #try_files $uri $uri/ =404;
                proxy_pass https://localhost:[PORT]/;
                proxy_cookie_domain localhost [SUBDOMAIN].[YOURDOMAIN]; #
                proxy_set_header X-ProxyHost [SUBDOMAIN].[YOURDOMAIN];
                proxy_set_header X-ProxyPort 443;

        }
        client_max_body_size 100M;

}
```

- [PORT] should be 5601 for dashboards, 9200 for opensearch and 8443 for nifi.
- [SUBDOMAIN] could be either nifi, opensearch or dashboards (actually, they could be anything you want)
- [YOURDOMAIN] should be a domain or subdomain, for example: teseoetl.yourorganization.com

### Run certbot
After configuring your domains and nginx, certbot should be run to create the certificates. Usually it's only:

`certbot`

And then confirming the domains.

### Run the docker composes in each sever:
- Server 1: `docker compose -f docker-compose-nifinode.yml up -d`
- Server 2: `docker compose -f docker-compose-opensearch.yml up -d`

Now check services for errors using `docker ps` and `docker logs`
