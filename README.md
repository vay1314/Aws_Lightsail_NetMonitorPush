## Aws Lightsail VPS网络监控器

功能：监控主机当月总流量、超出限制后自动关机，并且每日推送前一天流量报告。

### 1.安装依赖

```shell
sudo apt install vnstat jq bc curl -y
```

### 2.确定网卡名称

```shell
ip link
```

### 3.配置vnstat

```shell
sudo nano /etc/vnstat.conf
```

修改vnstat.conf中的选项

```shell
# 网卡名称
Interface "eth0"
# 使用GB为单位
UnitMode 1
# 每月起始日期
MonthRotate 1
```

重启vnstat服务

```shell
sudo systemctl restart vnstat
```

### 4.下载NetMonitorPush.sh脚本到服务器

```shell
curl -o NetMonitorPush.sh https://raw.githubusercontent.com/vay1314/Aws_Lightsail_NetMonitorPush/refs/heads/main/NetMonitorPush.sh
```

### 5.配置NetMonitorPush.sh

修改NetMonitorPush.sh中网卡名称、流量上限、企业微信推送参数。

```shell
# 网卡名称
interface_name="eth0"

# 流量阈值上限（单位：GB）
traffic_limit=1000

# 企业微信推送相关信息
CorpID=""
Secret=""
AgentID=""
```

### 6.授予SH文件权限

```shell
chmod +x NetMonitorPush.sh
```

### 7.定时运行SH文件

```shell
*/3 * * * * /bin/bash /root/NetMonitorPush.sh > /root/running.log 2>&1
```
