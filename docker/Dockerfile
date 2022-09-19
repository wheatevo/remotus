FROM alpine:latest

COPY entrypoint.sh /

RUN apk add --update --no-cache openssh && \
    sed -i '/GatewayPorts.*/d' /etc/ssh/sshd_config && \
    echo 'GatewayPorts yes' >> /etc/ssh/sshd_config && \
    sed -i '/AllowTcpForwarding.*/d' /etc/ssh/sshd_config && \
    echo 'AllowTcpForwarding yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    adduser -h /home/testuser -s /bin/sh -D testuser && \
    echo 'testuser:testuser' | chpasswd

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 22
