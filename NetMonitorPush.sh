#!/bin/bash

# 网卡名称
interface_name="eth0"

# 流量阈值上限（单位：GB）
traffic_limit=1000

# 企业微信推送相关信息
CorpID=""
Secret=""
AgentID=""

# 当前日期和时间
current_time=$(date +"%H:%M")
current_day=$(date +"%d")

# 昨天的日期
yesterday=$(date -d "yesterday" +"%Y-%m-%d")

# 检查vnstat是否安装
if ! command -v vnstat &> /dev/null; then
  echo "vnstat 未安装，请先安装vnstat"
  exit 1
fi

# 更新网卡记录
vnstat -i "$interface_name"

# 获取每月用量（进站+出站）
ax=$(vnstat --oneline -i "$interface_name" | awk -F ";" '{print $11}')

# 如果单位是 GB 则进入
if [[ "$ax" == *GB* ]]; then
  # 提取实际流量数
  actual_traffic=$(echo "$ax" | sed 's/ GB//g')

  # 比较流量大小
  if (( $(echo "$actual_traffic >= $traffic_limit" | bc -l) )); then
    echo "流量超出限制，关机中..."
    # 企业微信推送关机消息
    shutdown_message="流量超出限制（${actual_traffic} GB），正在关机..."

    # 获取企业微信的 access_token
    access_token=$(curl -s -G "https://qyapi.weixin.qq.com/cgi-bin/gettoken" \
    --data-urlencode "corpid=$CorpID" \
    --data-urlencode "corpsecret=$Secret" | jq -r '.access_token')

    # 发送推送消息
    curl -s -X POST "https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=$access_token" \
    -H "Content-Type: application/json" \
    -d '{
          "touser": "@all",
          "msgtype": "text",
          "agentid": '$AgentID',
          "text": {
              "content": "'"$shutdown_message"'"
          },
          "safe": 0
        }'

    echo "已发送关机消息：${shutdown_message}"

    # 执行关机命令
    sudo /usr/sbin/shutdown -h now
  else
    echo "流量未超出限制。当前流量为：${actual_traffic} GB"
  fi
else
  echo "当前流量单位不是GB，当前流量为：$ax"
fi

# 每天 8 点发送昨日流量报告
if [[ "$current_time" == "08:00" ]]; then
  # 获取前一天的流量
  yesterday_traffic=$(vnstat -d -i "$interface_name" | grep "$yesterday" | awk '{print $8, $9}')
  
  #获取前一天的平均速率
  yesterday_rate=$(vnstat -d -i "$interface_name" | grep "$yesterday" | awk '{print $11, $12}')

  # 企业微信推送消息
  message="${yesterday} 流量报告\n流量已使用 ${yesterday_traffic}\n平均速率：${yesterday_rate} \n当月总流量：${ax}"

  # 获取企业微信的 access_token
  access_token=$(curl -s -G "https://qyapi.weixin.qq.com/cgi-bin/gettoken" \
  --data-urlencode "corpid=$CorpID" \
  --data-urlencode "corpsecret=$Secret" | jq -r '.access_token')

  # 发送推送消息
  curl -s -X POST "https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=$access_token" \
  -H "Content-Type: application/json" \
  -d '{
        "touser": "@all",
        "msgtype": "text",
        "agentid": '$AgentID',
        "text": {
            "content": "'"$message"'"
        },
        "safe": 0
      }'

  echo "已发送昨日流量报告：${message}"
fi
