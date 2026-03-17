# ddns
前置条件
•一个托管在 Cloudflare 的域名（xyz域名10年好像70元左右）
•服务器已安装 curl、jq、flock（多数 Linux 发行版默认自带）
•域名对应的 DNS A或AAAA 记录已在 Cloudflare 面板手动创建（脚本只更新，不新建）

检查依赖是否已安装：
which curl jq flock

如果缺少 jq，可以这样安装：

Debian / Ubuntu
apt install jq -y

CentOS / RHEL
yum install jq -y

获取 Cloudflare API Token
这是最重要的一步，请按以下步骤操作：

•登录 Cloudflare Dashboard → 点击右上角头像 →配置文件
•左侧菜单选择 API 令牌 → 创建令牌
•选择模板 → 编辑区域DNS
选择你的具体域名
•创建后复制 Token，该 Token 只显示一次

安装与配置

创建目录并下载脚本
mkdir -p ~/ddns
cd ~/ddns
将 ddns.sh 上传或复制到此目录
chmod 700 ddns.sh

创建配置文件
先设置权限，再写入内容，防止写入过程中被其他用户读取：
touch ddns.conf
chmod 600 ddns.conf
nano ddns.conf
配置文件内容模板（按实际情况修改）：

── 第一组：IPv4 A 记录 ──────────────────────────────
apitoken1="你的_Cloudflare_API_Token"
zonename1="888888.xyz" # Cloudflare 上托管的根域名
recordname1="cmhk" # 子域名前缀，空则更新根域名
recordtype1="A" # IPv4 填 A，IPv6 填 AAAA
proxied1="false" # DDNS 建议关闭 CF 代理

── 第二组：IPv6 AAAA 记录（不需要留空即可）─────────
apitoken2=""
zonename2=""
recordname2=""
recordtype2="AAAA"
proxied2="false"

── 日志设置 ─────────────────────────────────────────
logfile="cloudflare-ddns.log"
max_log_size=1048576 # 1MB，超出后自动清理旧记录

💡 域名填写说明：以 cmhk.888888.xyz 为例，zonename 填根域名 888888.xyz，recordname 填子域名前缀 cmhk，两者合起来就是完整域名。

在 Cloudflare 面板预先创建 DNS 记录
脚本只会更新已存在的记录，不会自动新建。请先登录 Cloudflare DNS 管理页面，手动添加一条 A 记录：
字段 填写内容
类型 A
名称 cmhk（你的子域名前缀）
内容 1.2.3.4（随便填，脚本会自动更新）
代理状态 仅 DNS（关闭橙色云朵）

测试运行
手动执行脚本，观察输出：
bash ~/ddns/ddns.sh

成功时日志输出示例：
2026-03-17 12:00:00 [cmhk.888888.xyz] IP 成功更新为: 0.0.0.0

如果 IP 没有变化，脚本会静默退出（不输出任何内容），这是正常行为。

查看完整日志：

实时滚动显示（Ctrl+C 退出）
tail -f ~/ddns/cloudflare-ddns.log

查看最近 50 行
tail -n 50 ~/ddns/cloudflare-ddns.log

设置定时任务
使用 cron 每 10 分钟自动执行一次：
crontab -e

在文件末尾添加（路径改为你的实际路径）：
*/10 * * * * /bin/bash /root/ddns/ddns.sh

验证 cron 任务已添加：
crontab -l

确认 cron 服务正在运行：
systemctl status cron

💡 cron 时间格式说明：*/10 * * * * 表示每 10 分钟执行一次。如需每 5 分钟执行，改为 */5 * * * *。
