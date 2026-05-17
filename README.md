# Anki Sync Server

这个目录提供一个 Docker 版同步器：

```text
MyObsidian/AnkiCards -> Yanki CLI -> headless AnkiConnect API -> collection.anki21 -> AnkiWeb
```

它不运行完整 Anki 桌面端，而是使用 `anki-connect-server` 直接操作 Anki collection 文件。Yanki CLI 通过 AnkiConnect 兼容 API 写入卡片。

## 准备

1. 先在桌面 Anki 里完成一次正常同步，确保本地数据和 AnkiWeb 一致。
2. 关闭桌面 Anki。
3. 找到 Anki 的 `collection.anki21`，复制到：

```text
AnkiSyncServer/data/collection.anki21
```

4. 创建环境变量文件：

```bash
cd /home/zzz10258/git_repo/AnkiSyncServer
cp .env.example .env
```

5. 编辑 `.env`，填入 AnkiWeb 账号密码。

## 启动

```bash
cd /home/zzz10258/git_repo/AnkiSyncServer
docker compose up -d --build
```

查看日志：

```bash
docker compose logs -f
```

手动跑一次同步：

```bash
docker compose run --rm -e YANKI_ONCE=true anki-yanki-sync
```

## 使用方式

你在任意设备编辑 `MyObsidian/AnkiCards`，只要这些文件最终同步到这台服务器，容器就会每 15 分钟运行一次 Yanki sync，并推送到 AnkiWeb。

默认配置：

- 卡片目录：`../MyObsidian/AnkiCards`
- Yanki namespace：`MyObsidian`
- 同步间隔：900 秒
- 媒体同步：本地媒体
- 自动推送 AnkiWeb：开启

Podman 用户可以不用 compose，直接运行：

```bash
cd /home/zzz10258/git_repo/AnkiSyncServer
podman build -t anki-yanki-sync .
podman run -d --name anki-yanki-sync \
  --restart=unless-stopped \
  --env-file .env \
  -e ANKICONNECT_COLLECTION_PATH=/data/collection.anki21 \
  -e ANKICONNECT_BIND=0.0.0.0 \
  -e ANKICONNECT_PORT=8765 \
  -e ANKI_CARDS_DIR=/vault/AnkiCards \
  -e YANKI_NAMESPACE=MyObsidian \
  -p 8765:8765 \
  -v /home/zzz10258/git_repo/MyObsidian:/vault:Z \
  -v /home/zzz10258/git_repo/AnkiSyncServer/data:/data:Z \
  anki-yanki-sync
```

## 注意

- 不要让桌面 Anki 和这个容器同时写同一个 `collection.anki21`。
- 第一次上线前建议备份 Anki。
- 如果你继续在桌面 Obsidian 里使用 Yanki，同步目录和 namespace 必须保持一致：`AnkiCards` / `MyObsidian`。
- `.env` 里有 AnkiWeb 密码，不要提交。
