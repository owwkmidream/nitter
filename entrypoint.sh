#!/bin/sh

# 复制 nitter.example.conf 到 nitter.conf
# 这一步确保每次启动时都从原始模板开始，避免上次运行的修改残留
#cp nitter.example.conf nitter.conf

echo "Applying configuration from environment variables..."

# 函数：更新配置文件中的字符串值
# 参数1: 环境变量名
# 参数2: 配置文件的键名 (e.g., "hostname")
# 参数3: 配置文件中该键当前的值 (用于替换)
update_config_string() {
    ENV_VAR_NAME=$1
    CONFIG_KEY=$2
    DEFAULT_VALUE=$3 # The value to be replaced in nitter.example.conf

    if [ -n "$(eval echo \$$ENV_VAR_NAME)" ]; then
        # 使用管道符 | 作为sed的分隔符，以避免路径或URL中的斜杠冲突
        # 替换格式：key = "old_value" -> key = "new_value"
        sed -i "s|${CONFIG_KEY} = \"${DEFAULT_VALUE}\"|${CONFIG_KEY} = \"$(eval echo \$$ENV_VAR_NAME)\"|" nitter.conf
        echo "  - Set ${CONFIG_KEY} to $(eval echo \$$ENV_VAR_NAME)"
    fi
}

# 函数：更新配置文件中的布尔值
# 参数1: 环境变量名
# 参数2: 配置文件的键名
# 参数3: 配置文件中该键当前的布尔值 (true/false)
update_config_boolean() {
    ENV_VAR_NAME=$1
    CONFIG_KEY=$2
    DEFAULT_VALUE=$3

    if [ -n "$(eval echo \$$ENV_VAR_NAME)" ]; then
        # 确保环境变量是 "true" 或 "false"
        if [ "$(eval echo \$$ENV_VAR_NAME)" = "true" ]; then
            sed -i "s|${CONFIG_KEY} = ${DEFAULT_VALUE}|${CONFIG_KEY} = true|" nitter.conf
            echo "  - Set ${CONFIG_KEY} to true"
        elif [ "$(eval echo \$$ENV_VAR_NAME)" = "false" ]; then
            sed -i "s|${CONFIG_KEY} = ${DEFAULT_VALUE}|${CONFIG_KEY} = false|" nitter.conf
            echo "  - Set ${CONFIG_KEY} to false"
        else
            echo "  - Warning: ${ENV_VAR_NAME} must be 'true' or 'false'. Ignoring."
        fi
    fi
}

# 函数：更新配置文件中的数字值
# 参数1: 环境变量名
# 参数2: 配置文件的键名
# 参数3: 配置文件中该键当前的数字值
update_config_number() {
    ENV_VAR_NAME=$1
    CONFIG_KEY=$2
    DEFAULT_VALUE=$3

    if [ -n "$(eval echo \$$ENV_VAR_NAME)" ]; then
        # 替换格式：key = number -> key = new_number
        sed -i "s|${CONFIG_KEY} = ${DEFAULT_VALUE}|${CONFIG_KEY} = $(eval echo \$$ENV_VAR_NAME)|" nitter.conf
        echo "  - Set ${CONFIG_KEY} to $(eval echo \$$ENV_VAR_NAME)"
    fi
}

# --- 应用配置 ---

# [Server]
update_config_string "NITTER_HOSTNAME" "hostname" "nitter.net"
update_config_string "NITTER_TITLE" "title" "nitter"
update_config_string "NITTER_ADDRESS" "address" "0.0.0.0"
update_config_number "NITTER_PORT" "port" "8080"
update_config_boolean "NITTER_HTTPS" "https" "false"
update_config_number "NITTER_HTTP_MAX_CONNECTIONS" "httpMaxConnections" "100"

# [Cache]
update_config_number "NITTER_LIST_MINUTES" "listMinutes" "240"
update_config_number "NITTER_RSS_MINUTES" "rssMinutes" "10"
update_config_string "NITTER_REDIS_HOST" "redisHost" "localhost"
update_config_number "NITTER_REDIS_PORT" "redisPort" "6379"
# 对于密码，需要特别注意特殊字符的转义。这里使用简单的sed，如果密码包含`/`或`&`可能出错。
# 更健壮的方式是使用awk或更复杂的脚本，或者确保密码不包含这些字符。
if [ -n "$NITTER_REDIS_PASSWORD" ]; then
    # 替换前，先对密码进行sed安全转义
    ESCAPED_PASSWORD=$(echo "$NITTER_REDIS_PASSWORD" | sed 's/[\/&]/\\&/g')
    sed -i "s|redisPassword = \"\"|redisPassword = \"$ESCAPED_PASSWORD\"|" nitter.conf
    echo "  - Set redisPassword (masked)"
fi
update_config_number "NITTER_REDIS_CONNECTIONS" "redisConnections" "20"
update_config_number "NITTER_REDIS_MAX_CONNECTIONS" "redisMaxConnections" "30"


# [Config]
if [ -n "$NITTER_HMAC_KEY" ]; then
    # HMAC Key也需要转义，因为它可能包含特殊字符
    ESCAPED_HMAC_KEY=$(echo "$NITTER_HMAC_KEY" | sed 's/[\/&]/\\&/g')
    sed -i "s|hmacKey = \"secretkey\"|hmacKey = \"$ESCAPED_HMAC_KEY\"|" nitter.conf
    echo "  - Set hmacKey (masked)"
fi
update_config_boolean "NITTER_BASE64_MEDIA" "base64Media" "false"
update_config_boolean "NITTER_ENABLE_RSS" "enableRSS" "true"
update_config_boolean "NITTER_ENABLE_DEBUG" "enableDebug" "false"
update_config_string "NITTER_PROXY" "proxy" ""
update_config_string "NITTER_PROXY_AUTH" "proxyAuth" ""

# [Preferences]
update_config_string "NITTER_PREF_THEME" "theme" "Nitter"
update_config_string "NITTER_PREF_REPLACE_TWITTER" "replaceTwitter" "nitter.net"
update_config_string "NITTER_PREF_REPLACE_YOUTUBE" "replaceYouTube" "piped.video"
update_config_string "NITTER_PREF_REPLACE_REDDIT" "replaceReddit" "teddit.net"
update_config_boolean "NITTER_PREF_PROXY_VIDEOS" "proxyVideos" "true"
update_config_boolean "NITTER_PREF_HLS_PLAYBACK" "hlsPlayback" "false"
update_config_boolean "NITTER_PREF_INFINITE_SCROLL" "infiniteScroll" "false"

echo "Configuration applied. Starting Nitter..."

# --- 处理 sessions.jsonl ---
# 确保 /src/ 目录及其内容归 'nitter' 用户所有
# 这样 'nitter' 用户就有权限创建和写入文件
chown -R nitter:nitter /src/
# 检查是否存在 NITTER_SESSIONS_JSONL_BASE64 环境变量
if [ -n "$NITTER_SESSIONS_JSONL_BASE64" ]; then
    echo "  - Decoding and writing sessions.jsonl from environment variable..."
    # 解码 Base64 字符串并写入 sessions.jsonl 文件
    echo "$NITTER_SESSIONS_JSONL_BASE64" | base64 -d > sessions.jsonl
    # 设置 sessions.jsonl 文件的权限，只允许所有者读写，确保安全
    chmod 600 sessions.jsonl
    echo "  - sessions.jsonl written successfully."
else
    echo "  - NITTER_SESSIONS_JSONL_BASE64 environment variable not set. sessions.jsonl will not be pre-populated."
    # 如果 Nitter 期望文件存在但没有提供内容，可以考虑创建一个空文件
    # touch sessions.jsonl
    # chmod 600 sessions.jsonl
fi

# 执行Nitter应用程序
# 使用 exec 会将当前shell进程替换为Nitter进程，这有助于信号处理和进程管理
exec ./nitter
