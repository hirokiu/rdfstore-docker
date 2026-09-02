# rdfstore-docker

指定したディレクトリ内のRDFを初回起動時にすべて投入し、VirtuosoのSPARQL endpointを起動するシンプルなDocker Compose構成です。

## 対応形式

入力ディレクトリを再帰的に検索し、次のファイルをVirtuoso標準のバルクローダーで投入します。

- Turtle (`.ttl`, `.ttl.gz`)
- N-Triples (`.nt`, `.nt.gz`)
- N-Quads (`.nq`, `.nq.gz`)
- RDF/XML (`.rdf`, `.rdf.gz`, `.xml`, `.xml.gz`)
- OWL (`.owl`, `.owl.gz`)
- TriG (`.trig`)

## 起動

```sh
cp .env.example .env
```

`.env` で管理者パスワード、公開ポート、DBディレクトリ、RDFデータディレクトリ、投入先グラフを指定します。

```dotenv
VIRTUOSO_ADMIN_PASSWORD=change-this-password
VIRTUOSO_HTTP_PORT=8890
VIRTUOSO_DATABASE_DIR=./virtuoso
RDF_DATA_DIR=./data
RDF_DEFAULT_GRAPH=https://example.org/graph
```

`RDF_DATA_DIR` を省略した場合はリポジトリ内の `data/` を使用します。RDFファイルを配置して起動します。

```sh
docker compose up -d
docker compose logs -f store
docker compose ps
```

投入とcheckpointが完了するとコンテナがhealthyになり、次のURLで利用できます。

```text
http://127.0.0.1:8890/sparql
```

SQLポート1111はホストへ公開していません。管理操作はコンテナ内で実行できます。

```sh
docker compose exec store isql 1111 dba
```

## 初回投入の動作

初回DB作成時だけ `initdb.d/10-rdf-loader.sh` が実行されます。すべての入力ファイルを登録し、`rdf_loader_run()` とcheckpointを実行してから通常起動します。

ロード失敗が1件でもある場合は完了マーカーを作らず、コンテナはhealthyになりません。結果は `DB.DBA.load_list` とDBディレクトリ内の `virtuoso.log` で確認できます。

既存DBを再起動してもRDFは再投入されません。新しいデータセットへ完全に入れ替える場合は、稼働中のDBとは別の空のDBディレクトリを使用してください。

## 複数インスタンスの並列起動

このリポジトリを別名のディレクトリへcloneし、それぞれの `.env` でHTTPポートを変更すれば並列起動できます。コンテナ名はポートから自動的に `rdfstore-<ポート>` となります。

正系の例:

```dotenv
VIRTUOSO_HTTP_PORT=8891
VIRTUOSO_DATABASE_DIR=/opt/rdfstore/primary/database
RDF_DATA_DIR=/opt/rdfstore/primary/data
```

副系の例:

```dotenv
VIRTUOSO_HTTP_PORT=8892
VIRTUOSO_DATABASE_DIR=/opt/rdfstore/secondary/database
RDF_DATA_DIR=/opt/rdfstore/secondary/data
```

それぞれのディレクトリで実行します。

```sh
docker compose up -d
```

ホストnginxは、検証済みでhealthyな方の `127.0.0.1:8891` または `127.0.0.1:8892` へproxyします。正副切り替え処理はこのリポジトリの責務には含めません。

同じディレクトリから複数起動する場合は、ポート、DBディレクトリに加えてComposeプロジェクト名も変えてください。

```sh
docker compose -p rdfstore-primary --env-file primary.env up -d
docker compose -p rdfstore-secondary --env-file secondary.env up -d
```

## 大量データ向け設定

`VIRT_PARAMETERS_NUMBEROFBUFFERS` と `VIRT_PARAMETERS_MAXDIRTYBUFFERS` はホストのRAMに合わせて調整してください。DBディレクトリには高速なローカルストレージを使用し、入力データとDB、transaction log、checkpointに必要な空き容量を確保してください。

## バージョン更新

Virtuosoイメージは再現性のため完全なタグに固定しています。新しい版は別ポート・別DBディレクトリでロードとクエリを検証してから、ホスト側のproxyを切り替えてください。
