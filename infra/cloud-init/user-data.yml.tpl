#cloud-config

package_update: true
package_upgrade: true

packages:
  - ca-certificates
  - curl
  - git
  - jq
  - ufw
  - gnupg
  - lsb-release

write_files:
  - path: /etc/docker/daemon.json
    permissions: "0644"
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "10m",
          "max-file": "3"
        }
      }

runcmd:
  - useradd -m -s /bin/bash -u 1000 ${app_user}
  - usermod -aG sudo ${app_user}
  - echo '${app_user} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${app_user}
  - chmod 440 /etc/sudoers.d/${app_user}

  - mkdir -p /home/${app_user}/.ssh
  - cp /root/.ssh/authorized_keys /home/${app_user}/.ssh/authorized_keys
  - chown -R ${app_user}:${app_user} /home/${app_user}/.ssh
  - chmod 700 /home/${app_user}/.ssh
  - chmod 600 /home/${app_user}/.ssh/authorized_keys

  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ${app_user}

  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow ssh
  - ufw --force enable

  - mkdir -p ${app_directory}/workspace
  - chown -R 1000:1000 ${app_directory}
  - chmod 700 ${app_directory}
  - chmod 700 ${app_directory}/workspace

  - mkdir -p /home/${app_user}/openclaw/docker
  - chown -R ${app_user}:${app_user} /home/${app_user}/openclaw

final_message: "OpenClaw Hetzner bootstrap finished after $UPTIME seconds"
