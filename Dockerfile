FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
        wget unzip libc6-i386 lib32stdc++6 libncurses5:i386 cron tzdata python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /root

COPY entrypoint.sh /entrypoint.sh
COPY validate_config.sh /validate_config.sh
COPY polyfield-log-filter.py /usr/local/bin/polyfield-log-filter.py
RUN chmod +x /entrypoint.sh /validate_config.sh
RUN chmod +x /usr/local/bin/polyfield-log-filter.py || true

ENTRYPOINT ["/entrypoint.sh"]
