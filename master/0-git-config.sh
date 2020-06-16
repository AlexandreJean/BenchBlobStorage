#!/bin/bash

GRAFANA_USER="admin"
GRAFANA_PASSWD="P@sswOrd4242020"

echo "## Config repo for InfluxDB:"
cat <<EOF | tee /etc/yum.repos.d/influxdb.repo
[influxdb]
name = InfluxDB Repository - RHEL \$releasever
baseurl = https://repos.influxdata.com/centos/\$releasever/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdb.key
EOF

echo "### Config repo for Grafana:"
cat <<EOF | tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF


echo "### InfluxDB Install:"
yum -y install influxdb

echo "### Grafana Install:"
yum -y install grafana

echo "#### Starting InfluxDB services:"
systemctl daemon-reload
systemctl start influxdb
systemctl enable influxdb
echo "#### Starting Grafana services:"
systemctl start grafana-server
systemctl enable grafana-server

echo "#### Configuration of influxDB User and DB:"
curl "http://localhost:8086/query" --data-urlencode "q=CREATE USER admindb WITH PASSWORD '$GRAFANA_PASSWD' WITH ALL PRIVILEGES"
curl "http://localhost:8086/query" --data-urlencode "q=CREATE USER $GRAFANA_USER WITH PASSWORD '$GRAFANA_PASSWD'"
curl "http://localhost:8086/query" --data-urlencode "q=CREATE DATABASE monitor"
curl "http://localhost:8086/query" --data-urlencode "q=GRANT ALL ON monitor to $GRAFANA_USER"

echo "### Add the Grafana administrator:"
echo grafana-cli admin reset-admin-password "$GRAFANA_PASSWD"
grafana-cli admin reset-admin-password "$GRAFANA_PASSWD"

echo "### Create the datasource"
grafana_etc_root=/etc/grafana/provisioning
dashboard_dir=/var/lib/grafana/dashboards
cat <<EOF > $grafana_etc_root/datasources/azhpc.yml
apiVersion: 1

datasources:
  - name: azhpc
    type: influxdb
    access: proxy
    database: monitor
    user: $GRAFANA_USER
    password: "$GRAFANA_PASSWD"
    url: http://localhost:8086
    jsonData:
      httpMode: GET
EOF


cat <<EOF > $grafana_etc_root/dashboards/azhpc.yml
apiVersion: 1
providers:
- name: 'azhpc'
  orgId: 1
  folder: ''
  folderUid: ''
  type: file
  disableDeletion: false
  editable: true
  allowUiUpdates: true
  options:
    path: $dashboard_dir
EOF

chown root:grafana $grafana_etc_root/datasources/azhpc.yml
chown root:grafana $grafana_etc_root/dashboards/azhpc.yml

mkdir $dashboard_dir
chown grafana:grafana $dashboard_dir

echo "### Copy Grafana Dashboard :"
cp ./telegraf_dashboard.json $dashboard_dir

systemctl stop grafana-server
systemctl start grafana-server
