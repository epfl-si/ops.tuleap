FROM enalean/tuleap-aio:centos7

COPY ./upgrade11-14.yum /tmp/upgrade11-14.yum
RUN  yum shell -y < /tmp/upgrade11-14.yum

COPY ./Tuleap.php /usr/share/tuleap/src/tuleap-cfg/Command/Docker/Tuleap.php
COPY ./DockerAioRunCommand.php /usr/share/tuleap/src/tuleap-cfg/Command/DockerAioRunCommand.php
# COPY ./setup.el7.sh /usr/share/tuleap/tools/setup.el7.sh
RUN yum install -y tuleap-plugin-agiledashboard
