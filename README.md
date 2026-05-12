# WUI Panel

Next-Generation Proxy Management Panel

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/c11584/wui-panel/main/install.sh | bash
```

### 自定义参数

```bash
curl -fsSL https://raw.githubusercontent.com/c11584/wui-panel/main/install.sh | bash -s -- \
  --port 8080 \
  --username admin \
  --password yourpassword \
  --install-dir /opt/wui \
  --license-server https://wui-licenses.example.com
```

### 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--port` | 32451 | 面板端口 |
| `--username` | admin | 管理员用户名 |
| `--password` | 随机生成 | 管理员密码 |
| `--install-dir` | /opt/wui | 安装目录 |
| `--license-server` | 空 | License 服务器地址 |

## 管理命令

```bash
systemctl start wui      # 启动
systemctl stop wui       # 停止
systemctl restart wui    # 重启
systemctl status wui     # 状态
journalctl -u wui -f     # 日志
```

## 更新

重新运行安装脚本即可自动获取最新版本：

```bash
curl -fsSL https://raw.githubusercontent.com/c11584/wui-panel/main/install.sh | bash -s -- --port 32451
```

## 卸载

```bash
systemctl stop wui
systemctl disable wui
rm -rf /opt/wui
rm /etc/systemd/system/wui.service
systemctl daemon-reload
```

## 架构支持

- x86_64 (amd64)
- ARM64 (aarch64)

## 相关仓库

- **[c11584/wui](https://github.com/c11584/wui)** — 源代码（私有）
- **[c11584/wui-panel](https://github.com/c11584/wui-panel)** — 安装包发布
