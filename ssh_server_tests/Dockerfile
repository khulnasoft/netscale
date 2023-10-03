FROM python:3-buster

RUN wget https://github.com/khulnasoft/netscale/releases/latest/download/netscale-linux-amd64.deb \
  && dpkg -i netscale-linux-amd64.deb

RUN pip install pexpect

COPY tests.py .
COPY ssh /root/.ssh
RUN chmod 600 /root/.ssh/id_rsa

ARG SSH_HOSTNAME
RUN bash -c 'sed -i "s/{{hostname}}/${SSH_HOSTNAME}/g" /root/.ssh/authorized_keys_config'
RUN bash -c 'sed -i "s/{{hostname}}/${SSH_HOSTNAME}/g" /root/.ssh/short_lived_cert_config'
