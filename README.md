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
  --install-dir /opt/wui
```

### 参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--port` | 32451 | 面板端口 |
| `--username` | admin | 管理员用户名 |
| `--password` | 随机生成 | 管理员密码 |
| `--install-dir` | /opt/wui | 安装目录 |

## 管理命令

```bash
wui start       # 启动
wui stop        # 停止
wui restart     # 重启
wui status      # 状态
wui log [-f]    # 日志
wui version     # 版本
wui uninstall   # 卸载
```

## 更新

重新运行安装脚本即可自动获取最新版本：

```bash
curl -fsSL https://raw.githubusercontent.com/c11584/wui-panel/main/install.sh | bash -s -- --port 32451
```

## 卸载

```bash
wui uninstall
```

## 架构支持

- x86_64 (amd64)
- ARM64 (aarch64)
