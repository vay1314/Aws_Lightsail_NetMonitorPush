#!/bin/bash

# 网卡名称
interface_name="ens5"

# 流量阈值上限（单位：GB）
traffic_limit=950

# 企业微信推送相关信息
CorpID=""
Secret=""
AgentID=""

# 获取当前UTC时间（用于流量统计）
current_utc_time=$(date -u +"%H:%M")
current_utc_day=$(date -u +"%d")
current_utc_month=$(date -u +"%m")
current_utc_year=$(date -u +"%Y")

# 获取北京时间（CST, 用于日志和通知显示）
current_beijing_time=$(TZ='Asia/Shanghai' date +"%Y-%m-%d %H:%M:%S")

# 昨天的UTC日期
yesterday_utc=$(date -u -d "yesterday" +"%Y-%m-%d")

# 改进依赖检查
echo "检查依赖项..."

# 检查vnstat
VNSTAT_PATH=$(which vnstat 2>/dev/null || echo "")
if [ -z "$VNSTAT_PATH" ] && [ -f "/usr/bin/vnstat" ]; then
  VNSTAT_PATH="/usr/bin/vnstat"
fi

if [ -z "$VNSTAT_PATH" ]; then
  echo "vnstat 未安装，请先安装 vnstat"
  exit 1
else
  echo "vnstat 依赖已安装"
fi

# 检查jq
JQ_PATH=$(which jq 2>/dev/null || echo "")
if [ -z "$JQ_PATH" ] && [ -f "/usr/bin/jq" ]; then
  JQ_PATH="/usr/bin/jq"
fi

if [ -z "$JQ_PATH" ]; then
  echo "jq 未安装，请先安装 jq"
  exit 1
else
  echo "jq 依赖已安装"
fi

# 更新网卡记录
echo "更新网卡记录..."
$VNSTAT_PATH -i "$interface_name"

# 获取当前UTC月份的开始和结束日期
utc_month_start="${current_utc_year}-${current_utc_month}-01"
# 计算下个月的第一天，然后减去1天得到本月最后一天
utc_month_end=$(date -u -d "${current_utc_year}-${current_utc_month}-01 +1 month -1 day" +"%Y-%m-%d")

echo "============================================="
echo "本次检查时间 (北京): $current_beijing_time"
echo "UTC时区当前时间: $(date -u +"%Y-%m-%d %H:%M:%S")"
echo "UTC时区统计月份: $utc_month_start 至 $utc_month_end"
echo "============================================="

# 获取当前UTC月份的流量
# 使用--begin和--end参数指定UTC时间范围
echo "获取本月流量信息..."
monthly_traffic=$($VNSTAT_PATH -i "$interface_name" --begin "$utc_month_start" --end "$utc_month_end" --oneline | awk -F ";" '{print $11}')

echo "UTC时区本月流量: $monthly_traffic"

# 修复条件检查语法，使用单括号兼容所有shell
if [ -n "$monthly_traffic" ] && [ "$(echo "$monthly_traffic" | grep -c "GB")" -gt 0 ]; then
  # 提取实际流量数
  actual_traffic=$(echo "$monthly_traffic" | sed 's/ GB//g')

  # 比较流量大小，使用bc进行数值比较
  if [ "$(echo "$actual_traffic >= $traffic_limit" | bc -l)" -eq 1 ]; then
    echo "流量超出限制，关机中..."

    # 企业微信推送关机消息
    shutdown_message="(${utc_month_start}至${utc_month_end})流量超出限制（${actual_traffic} GB），正在关机..."

    # 获取企业微信的 access_token
    access_token=$(curl -s -G "https://qyapi.weixin.qq.com/cgi-bin/gettoken" \
    --data-urlencode "corpid=$CorpID" \
    --data-urlencode "corpsecret=$Secret" | $JQ_PATH -r '.access_token')

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
    echo "流量未超出限制。不执行关机操作"
  fi
else
  echo "当前流量单位不是GB，UTC时区本月流量为：$monthly_traffic"
fi

# 使用单括号条件检查语法，兼容所有shell
if [ "$current_utc_time" = "00:00" ]; then
  # 获取UTC前一天的流量
  yesterday_traffic=$($VNSTAT_PATH -d -i "$interface_name" --begin "$yesterday_utc" --end "$yesterday_utc" | grep "$yesterday_utc" | awk '{print $8, $9}')
  
  # 获取UTC前一天的平均速率
  yesterday_rate=$($VNSTAT_PATH -d -i "$interface_name" --begin "$yesterday_utc" --end "$yesterday_utc" | grep "$yesterday_utc" | awk '{print $11, $12}')

  # 企业微信推送消息
  message="${yesterday_utc} (UTC时区)流量报告\n使用流量：${yesterday_traffic}\n平均速率：${yesterday_rate}\n月总流量(UTC时区)：${monthly_traffic}\n当前时间 (北京)：${current_beijing_time}"

  # 获取企业微信的 access_token
  access_token=$(curl -s -G "https://qyapi.weixin.qq.com/cgi-bin/gettoken" \
  --data-urlencode "corpid=$CorpID" \
  --data-urlencode "corpsecret=$Secret" | $JQ_PATH -r '.access_token')

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
