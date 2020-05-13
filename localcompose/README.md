# Tuleap installation

## Release version

### Docker Entry Point
The entry point for the official image is 
`/usr/bin/tuleap-cfg docker:tuleap-aio-run`. The command itself can do various things and might be of use:

```
[root@3e5fb207b3de /]# /usr/bin/tuleap-cfg -h
Description:
  Lists commands

Usage:
  list [options] [--] [<namespace>]

Arguments:
  namespace            The namespace name

Options:
      --raw            To output raw command list
      --format=FORMAT  The output format (txt, xml, json, or md) [default: "txt"]

Help:
  The list command lists all commands:
  
    php /usr/bin/tuleap-cfg list
  
  You can also display the commands for a specific namespace:
  
    php /usr/bin/tuleap-cfg list test
  
  You can also output the information in other formats by using the --format option:
  
    php /usr/bin/tuleap-cfg list --format=xml
  
  It's also possible to get raw list of commands (useful for embedding command runner):
  
    php /usr/bin/tuleap-cfg list --raw

[root@3e5fb207b3de /]# /usr/bin/tuleap-cfg list
Console Tool

Usage:
  command [options] [arguments]

Options:
  -h, --help            Display this help message
  -q, --quiet           Do not output any message
  -V, --version         Display this application version
      --ansi            Force ANSI output
      --no-ansi         Disable ANSI output
  -n, --no-interaction  Do not ask any interactive question
  -v|vv|vvv, --verbose  Increase the verbosity of messages: 1 for normal output, 2 for more verbose output and 3 for debug

Available commands:
  configure              Configure Tuleap
  help                   Displays help for a command
  list                   Lists commands
  site-deploy            Execute all deploy actions needed at site update
  systemctl              Wrapper for service activation / desactivation
 docker
  docker:tuleap-aio-run  Run Tuleap in the context of `tuleap-aio` image
 setup
  setup:mysql            Feed the database with core structure and values
  setup:mysql-init       Initialize database (users, database, permissions)
 site-deploy
  site-deploy:fpm        Deploy PHP FPM configuration files

```

### Admin user
Users need to be confirmed by admin. The password for admin is in 
`data/tuleap/root/.tuleap_passwd`

### Persistency
In principle all data that needs to be persisted is stored in `/data`. The 
development version also have a storage for plugins. Therefore I also mount
a volume for that. I also mount a volume for overriding the default nginx 
configuration (see [section below](#external-url)) as well as the config for 
`php-fpm`

```
      volumes:
        - ./data/tuleap:/data
        - ./data/plugins:/usr/share/tuleap-plugins
        - ./config/nginx:/etc/nginx
        - ./config/php-fpm.d:/etc/opt/remi/php73/php-fpm.d
        # - ./src:/usr/share/tuleap

```

Now, the stuff in `/data` is generated upon the first run. Therefore the first
execution will always be misconfigured unless we build our own image with the
good configuration already builtin or we have a prerequisite ansible script
that write the config into a persistent volume.

The code of the application is in `/usr/share/tuleap/src/www`.

### External Database
This should be configurable with the `/usr/bin/tuleap-cfg setup:mysql` in the
hope that it does not run local database configuration when the database is
external because I have seen that it tries to run some command as `sudo` which 
will not work on openshift.

```
[root@3e5fb207b3de /]# /usr/bin/tuleap-cfg help setup:mysql 
Description:
  Feed the database with core structure and values

Usage:
  setup:mysql [options] [--] <admin_password> <domain_name>

Arguments:
  admin_password           Site Administrator password
  domain_name              Tuleap server public url

Options:
      --host=HOST          MySQL server host [default: "localhost"]
      --port=PORT          MySQL server port [default: 3306]
      --ssl-mode=SSL-MODE  Use an encrypted connection. Possible values: `disabled` (default), `no-verify` or `verify-ca` [default: "disabled"]
      --ssl-ca=SSL-CA      When ssl-mode is set to no-verify or verify-ca you should provide the path to CA file [default: "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"]
      --user=USER          MySQL user for setup [default: "tuleapadm"]
      --dbname=DBNAME      Database name [default: "tuleap"]
      --password=PASSWORD  User's password
  -h, --help               Display this help message
  -q, --quiet              Do not output any message
  -V, --version            Display this application version
      --ansi               Force ANSI output
      --no-ansi            Disable ANSI output
  -n, --no-interaction     Do not ask any interactive question
  -v|vv|vvv, --verbose     Increase the verbosity of messages: 1 for normal output, 2 for more verbose output and 3 for debug

```

So let's try to configure an external mysql and run `setup:mysql` before
starting the app.

Yet another unexpected issue...

```
tuleap % docker-compose up -d db
Creating tuleap_db_1 ... done
Attaching to tuleap_db_1
...

tuleap % dc run --rm --entrypoint  /usr/bin/tuleap-cfg app setup:mysql --host db --user tuleap --password tuleap --dbname tuleap tuleap tuleap.dev.jkldsa.com
Successfully connected to the database !

In ConnectionManager.php line 130:
                                                                                                        
  Invalid SQL modes: STRICT_TRANS_TABLES, ERROR_FOR_DIVISION_BY_ZERO, check MySQL server configuration  
                                                                                                        
```

indeed:

```
tuleap % echo "SELECT @@GLOBAL.SQL_MODE;" | dc exec -T db mysql --user=root --password=ROOT --
@@GLOBAL.SQL_MODE
STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
```
Should be enough to reset the `GLOBAL.SQL_MODE`:

```
tuleap % echo "SET GLOBAL sql_mode = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION';" | dc exec -T db mysql --user=root --password=ROOT -- 
tuleap % echo "SELECT @@GLOBAL.SQL_MODE;" | dc exec -T db mysql --user=root --password=ROOT --                                          
@@GLOBAL.SQL_MODE
NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
tuleap % dc run --rm --entrypoint  /usr/bin/tuleap-cfg app setup:mysql --host db --user tuleap --password tuleap --dbname tuleap giallo12 tuleap.dev.jkldsa.com
Successfully connected to the database !
```
Checked that this actually creates various tables in the tuleap database.

This is nice but this command does not create the directory tree in the 
persistent storage. I have tried to guess if there is a command for this but 
without success. There is a nice `setup` function in 
`tuleap-cfg/Command/Docker/Tuleap.php` which accepts parameters but it is 
called by the startup script `docker:tuleap-aio-run`. Therefore the easiest thing
is to provide to our custom built image a modified version of that script 
`/usr/share/tuleap/src/tuleap-cfg/Command/DockerAioRunCommand.php`
that can override hardcoded parameters with `env` variables.

Build image with new initializer. It takes the good options:

```
app_1      | + _optionMessages --debug --assumeyes --configure --server-name=tuleap.dev.jkldsa.com --mysql-server=db --mysql-user=tuleap --mysql-password=tuleap
```

but it still fails due to the invalid mysql options although I have checked and
the options are set correct. Using a db version (mysql 5.7) closer to the one 
used bu tuleap doesn't help. Finally, the db container needs to be started 
with the good `--sql-mode="NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"` 
command line option. 

Nuking/restarting again and... yet another error and the persistent storage 
still empty. I think this is enough!



### External URL

The publicly available image of tuleap is configured to serve an https end-point
with local certificates (self-signed by default but rewriteable)

Our aim is to have tuleap installed for the school and accessible from a 
standard address like https://tuleap.epfl.ch/ where the ssl certificate is 
provided by the edge router. Therefore we have two requirements:
 1. be able to customise the public address of the application;
 1. few options:
   * unencrypted traffic between the edge router and the app 
   * configure the edge router to accept the (self-signed) certificate from the app
   * edge router delegates ssl to the app which needs to have a valid certificate

While testing, the role of the edge router is taken by traefik.

#### Attempt 1 
Use standard traefik approach and point it directly to the php app that  is 
supposed to listen on port 8080. Nope. 
Note, I found that `php-fpm` listen only on localhost in 
`/etc/opt/remi/php73/php-fpm.d/tuleap.conf` and allow clients from  localhost too 
in `/etc/opt/remi/php73/php-fpm.d/tuleap_common.part `. Will have to **try again**.

#### Attempt 2
Use port 80 of the internal nginx server that is the proxy for the php 
application. In this case with the default config, nginx redirect to https and
triggers a redirection loop.

Therefore, I have tried to set the correct public address 
`$sys_https_host = 'tuleap.dev.jkldsa.com';` in `/etc/tuleap/conf/local.inc` and
to reconfigure nginx for
 1. stop listening to 443;
 1. not redirecting from 80 to 443
 1. serving the app from 80 by including the app config into the corresponding section 

Still an infinite loop. I figure out that redirection was configured twice: 
once in `/etc/nginx/conf.d/tuleap.conf`, and 
once in `/etc/nginx/default.d/redirect_tuleap.conf`
but redirection issue persists... A look into the configuration files of `php-fpm`
does not help. 

Enabled access log for `php-fpm` shows that the redirection must come from
the php code because the request reaches the `php-fpm` backend:

```
tuleap % cat data/tuleap/log/php-fpm.access.log
127.0.0.1 -  07/May/2020:13:29:02 +0000 "GET /index.php" 404
127.0.0.1 -  07/May/2020:13:29:17 +0000 "GET /index.php" 302
127.0.0.1 -  07/May/2020:13:29:17 +0000 "GET /index.php" 302
...
127.0.0.1 -  07/May/2020:13:29:18 +0000 "GET /index.php" 302
```

Digging into the php code, I found that the following line 
```
            $url_verification->assertValidUrl($_SERVER, $request, $project);
```
in `FrontRouter.php` that will execute the follwing code: 
```
            $chunks = $this->getUrlChunks();
            if (isset($chunks)) {
                $location = $this->getRedirectionURL($request, $server);
                $this->header($location);
            }
```

Where `$location` is identical to the current location. Now, `$this->getUrlChunks();`
at a certain point execute the following:
```
        if (! $request->isSecure() && ForgeConfig::get('sys_https_host')) {
            $this->urlChunks['protocol'] = 'https';
            $this->urlChunks['host']     = ForgeConfig::get('sys_https_host');
        }
```

Therefore, for the moment I just set the `sys_https_host` to `FALSE` in main 
tuleap config file (`data/tuleap/etc/tuleap/conf/local.inc`) but we should
understand better what all this means.

## Issues

### Plugins
Plugin [installation][plugin] on the docker image fails due package 
dependencies issues:

```
[root@74ba39fcdefa /]# yum install tuleap-plugin-agiledashboard
Loaded plugins: fastestmirror, ovl
Loading mirror speeds from cached hostfile
...
---> Package libzstd.x86_64 0:1.4.4-1.el7 will be installed
---> Package php73-php-pecl-msgpack.x86_64 0:2.1.0-1.el7.remi will be installed
--> Processing Conflict: php73-php-pecl-redis5-5.2.2-1.el7.remi.x86_64 conflicts php73-php-pecl-redis < 5
--> Processing Conflict: php73-php-pecl-redis5-5.2.2-1.el7.remi.x86_64 conflicts php73-php-pecl-redis4 < 5
--> Finished Dependency Resolution
Error: php73-php-pecl-redis5 conflicts with php73-php-pecl-redis4-4.3.0-1.el7.remi.x86_64
 You could try using --skip-broken to work around the problem
 You could try running: rpm -Va --nofiles --nodigest
```

Therefore, I have tried to just copy the source code into the plugin directory 
but I get an error 500 also by running `composer` in the plugin directory.

 > Agile Dashboard is under development and aims to provide a nice interface 
 > on top of trackers for management of Agile development processes.
 > As of today, Scrum and Kanban are targeted.

Most probably we need a general update to version 11.14 (latest available build).
Lukily this is quite straighforward as a simple `Dockerfile` 
that start from version 11.11 and run the following `yum` command to the job:

```
# yum shell -y <<EOF
remove php73-php-pecl-redis4
update
run
quit
EOF
```

After the upgrade, the installation of plugins with yum is working.

Nevertheless, this does not fix the issue with _agiledashboard_. I suspect 
again a websocket related issue or sill something with redirection and 
servernames as the following message on chrome console might suggest:

```
{"error":"Referer doesn't match host. CSRF tentative ?"}

Request details in Network pane:

General:
    Request URL: https://tuleap.dev.jkldsa.com/api/v1/projects/101/milestones?fields=slim&limit=50&offset=0&order=desc&query=%7B%22status%22:%22open%22%7D
    Request Method: GET
    Status Code: 403 
    Remote Address: 127.0.0.1:443
    Referrer Policy: same-origin

Respone Headers:
    access-control-allow-credentials: true
    access-control-allow-headers: Authorization
    access-control-allow-headers: Content-Type
    access-control-allow-headers: Origin
    access-control-allow-headers: X-Auth-UserId
    access-control-allow-headers: X-Auth-Token
    access-control-allow-headers: X-Client-Uuid
    access-control-allow-headers: X-Auth-AccessKey
    access-control-allow-origin: *
    access-control-expose-headers: X-PAGINATION-SIZE
    access-control-expose-headers: X-PAGINATION-LIMIT-MAX
    access-control-expose-headers: X-PAGINATION-LIMIT
    content-encoding: gzip
    content-length: 76
    content-type: application/json
    date: Mon, 11 May 2020 15:28:01 GMT
    server: nginx/1.16.1
    status: 403
    vary: Accept-Encoding
    x-powered-by: PHP/7.3.17

Request Headers:
    :authority: tuleap.dev.jkldsa.com
    :method: GET
    :path: /api/v1/projects/101/milestones?fields=slim&limit=50&offset=0&order=desc&query=%7B%22status%22:%22open%22%7D
    :scheme: https
    accept: application/json, text/plain, */*
    accept-encoding: gzip, deflate, br
    accept-language: en-US,en;q=0.9,it;q=0.8
    cookie: TULEAP_session_hash=5.7d812bb35245fed9da45e6963227d78c; TULEAP_PHPSESSID=ego1e8qlt6g65a0gt9s6ss2nn9
    referer: https://tuleap.dev.jkldsa.com/plugins/agiledashboard/?action=show-top&group_id=101&pane=topplanning-v2
    sec-fetch-dest: empty
    sec-fetch-mode: cors
    sec-fetch-site: same-origin
    user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.129 Safari/537.36

Query String Parameters:
    fields: slim
    limit: 50
    offset: 0
    order: desc
    query: {"status":"open"}

```

So we are back to the same problem of project creation below!

#### Can not create new project
Application fails to validate the form for creating a new project but 
the error message is not visible: ![new_proj_img]

Looking into the console in chrome, I see that there is an error from
vuejs (a.k.a. black magic) code. The lack of error message might be due 
to a simple bug or, most probably, to some communication issue with websocket
as `vuejs` is used for the view.

Luckily, I found out that in version 11.14 (see above) there is an option for
switching to _legacy UI_ which seams to work. 

#### Restart fails most of the times
For some reason restarting the server fails most of the time with the following
error message: 

```
tuleap % docker-compose up
Starting tuleap_app_1 ... done
Attaching to tuleap_app_1
app_1  | Regenerate configurations for nginx, fpm
app_1  | Regenerate configuration for apache
app_1  | Run forgeupgrade
app_1  | The command "'/usr/lib/forgeupgrade/bin/forgeupgrade' '--config=/etc/tuleap/forgeupgrade/config.ini' 'update'" failed.
app_1  | 
app_1  | Exit Code: 255(Unknown error)
app_1  | 
app_1  | Working directory: /
app_1  | 
app_1  | Output:
app_1  | ================
app_1  | 
app_1  | 
app_1  | Error Output:
app_1  | ================
app_1  | PHP Fatal error:  Uncaught PDOException: SQLSTATE[HY000] [2002] No such file or directory in /usr/share/tuleap/src/forgeupgrade/ForgeUpgrade_Db_Driver.php:102
app_1  | Stack trace:
app_1  | #0 /usr/share/tuleap/src/forgeupgrade/ForgeUpgrade_Db_Driver.php(102): PDO->__construct('mysql:host=loca...', 'tuleapadm', 'HTzZ6jmUIYr9ZM2...', Array)
app_1  | #1 /usr/share/forgeupgrade/src/ForgeUpgrade.php(60): ForgeUpgrade_Db_Driver->getPdo()
app_1  | #2 /usr/share/forgeupgrade/forgeupgrade.php(146): ForgeUpgrade->__construct(Object(ForgeUpgrade_Db_Driver))
app_1  | #3 {main}
app_1  |   thrown in /usr/share/tuleap/src/forgeupgrade/ForgeUpgrade_Db_Driver.php on line 102
app_1  | 
app_1  | Something went wrong, here is a shell to debug: 
tuleap_app_1 exited with code 0

```

After various attempts it eventually succeeds. Therefore this should not be an
issues for Kubernetes with a sufficient number of retries. 
I suspect this is related to some _check for updates_ script which could be 
disabled or to the fact that the app does not wait anough time for the sql 
server to be available.

First thing I tried is to mount the entry point in order to be able to log
something (`- ./config/tuleap-cfg:/usr/bin/tuleap-cfg` in volume section) but 
doing this the boot fails systematically (... or at least I didn't retry enough times).

Next is to see if there is some other file we can attack so I grep for output 
messages on the whole container filesystem and find the following two candidates:
 - `/usr/share/codendi/src/tuleap-cfg/Command/Docker/Tuleap.php`
 - `usr/share/tuleap/src/tuleap-cfg/Command/Docker/Tuleap.php`

Let's try with the first as it is part of the mounted source code. Nice! 
It works by just adding a sleep before the function that crashes:

```
    private function runForgeUpgrade(OutputInterface $output): void
    {

        $output->writeln('<info>Run forgeupgrade</info>');
        sleep(5);
        $output->writeln('<info>... but not before a good sleep!</info>');
        $this->process_factory->getProcessWithoutTimeout(['/usr/lib/forgeupgrade/bin/forgeupgrade', '--config=/etc/tuleap/forgeupgrade/config.ini', 'update'])->mustRun();
    }
```

In principle the correct way of avoiding this issue is by skipping 
forgeupgrade setep as explained [here][skipforge] but in my case
setting the `DO_NOT_LAUNCH_FORGEUPGRADE` as suggested does not have any affect
both with or without `$disable_forge_upgrade_warnings = 1;` in `local.inc`.

Final fix was to write a `Dockerfile` that applies the _sleep_ patch.



## Development Version
The idea is to see if we can start from the [source][devrepo] that should be the
most up-to-date thing.

Here the `docker-compose.yml` is more complex and have several services 
including 3 different versions of mysql!
The suspicious thing is that the [image][devdocker] used here still mention to 
use `fig up` to start the container... Yes, fig as in [fig.sh][fig]

 > Fig simplifies the Docker management workflow. Fig is a python application
 > that helps run groups of docker containers providing the app an environment. 
 > It has been **replaced by Docker Compose and is now deprecated**.

Anyway, let's put pessimism aside and try. The temptetion is to start from a 
situation similar to the one of the release version by 

 1. commenting out all services that do not look essential (_e.g._ phpldapadmin)
 1. adding my traefik labels part in `docker-compose-mac.yml`;
 1. moving persistent data tu `data` directory for easier interaction;
 1. editing server address in the main tuleap config file as for release version;

But this takes time and may introduce more errors. Therefore, let's first start 
with something as standard as possible and keep the standard networking crap 
just to see if the plugins and project creation do work here.

After the usual redirect `80->443`, we get `505` and the usual php white screen 
of death... 

Tried to enter the container and run `make compose` but it fails: I suspect
the container is not actively used by developers. At this point it does not 
make sense to waste more time on theis. Let's concentrate on the release version.


[tuleap]: https://www.tuleap.org/
[devrepo]: https://github.com/Enalean/tuleap
[install]: https://docs.tuleap.org/install.html
[plugin]: https://docs.tuleap.org/installation-guide/install-plugins.html#installing-new-plugins
[dockerhub]: https://hub.docker.com/r/enalean/tuleap-aio
[swarm]: https://medium.com/tuleap/from-a-docker-engine-to-docker-swarm-to-create-tuleap-clusters-bb3c44173976
[devdocker]: https://hub.docker.com/r/enalean/tuleap-aio-dev
[devdocker-repo]: https://github.com/Enalean/docker-tuleap-aio-dev
[fig]: https://tracxn.com/d/companies/fig.sh
[skipforge]: https://docs.tuleap.org/developer-guide/quick-start/run-tuleap.html#skip-forgeupgrade

[new_proj_img]: images/new_proj_phantom_error.png "Image showing invisible form validation message for new project creation"
