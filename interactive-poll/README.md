# 講義Live投票ツール (Supabase版)

Mentimeter的なライブ投票ツール。3モード対応:
- 📋 **多肢選択** — 選択肢から1つ選んで投票 → 棒グラフ
- ☁️ **ワードクラウド** — 自由記述 → 頻出語を大きく表示
- 🏆 **ランキング** — 学生が順位付け → 集計スコアで表示

学生は **スマホでQRコード or 4桁コード入力** で匿名参加。

## 技術構成

衛生薬学サイト(`eisei_yakugaku`)のフィードバック機能と同じスタック:
- **Supabase REST API** + 公開可能キー(`sb_publishable_*`) — SDK不要、`fetch`直叩き
- **GitHub Actions cron**(`keep-alive.yml`) — 無料プランの7日アイドル停止を防止
- **GitHub Pages** — 静的ホスティング
- **ポーリング(1.5秒間隔)** — 30人規模の教室なら十分軽量

> WebSocket(Supabase Realtime)でなくポーリングを採用しているのは、既存サイトのパターンに揃えるため・SDK追加なしで完結させるため。30人 × 1.5s ポーリングは Supabase 無料枠(50万API call/月)に対して余裕。

---

## セットアップ

### A. 既存のSupabaseプロジェクトを再利用する場合(推奨)

`eisei_yakugaku` で使っている `gmkrsgqgndlrabiicvkh` プロジェクトにテーブルを追加するだけ。

1. [Supabase Dashboard](https://supabase.com/dashboard) → プロジェクトを開く
2. 左メニュー **SQL Editor** → **New query**
3. [`schema.sql`](./schema.sql) の中身を全文貼り付け → **Run**
4. `poll_sessions` と `poll_responses` のテーブルが作成されればOK

`index.html` の `SUPABASE_URL` と `SUPABASE_KEY` は既にこのプロジェクトを向いているので、何も書き換え不要。

### B. 新規Supabaseプロジェクトを作る場合

1. [Supabase Dashboard](https://supabase.com/dashboard) → **New project**
2. プロジェクトが立ち上がったら **SQL Editor** で `schema.sql` を実行
3. **Settings → API** から以下を取得:
   - **Project URL**(例: `https://xxxxx.supabase.co`)
   - **anon public** key(`sb_publishable_...` 形式)
4. `index.html` 冒頭を書き換え:
   ```js
   const SUPABASE_URL = 'https://xxxxx.supabase.co';
   const SUPABASE_KEY = 'sb_publishable_...';
   ```

---

## デプロイ

### GitHub Pages

`lecture_documents` リポジトリにこの `interactive-poll/` フォルダごとコミット&プッシュすれば:

```
https://<ユーザー名>.github.io/lecture_documents/interactive-poll/
```

でアクセス可能。教卓PCではホスト画面、学生のスマホでは同URLから「参加」を選ぶ。

### Keep-aliveワークフロー

Supabase無料プランは **7日間アクセスが無いとプロジェクトが停止** します。`eisei_yakugaku` リポジトリの [keep-alive.yml](https://github.com/...) と同じものを `lecture_documents` にも置くか、既存プロジェクトを再利用していれば既存のkeep-aliveがそのまま効きます。

新規プロジェクトの場合のみ、`.github/workflows/keep-alive.yml` を追加:

```yaml
name: Supabase Keep Alive
on:
  schedule:
    - cron: '0 0 * * *'   # 毎日 UTC 0:00
  workflow_dispatch:
jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - run: |
          curl -s -o /dev/null -w "%{http_code}\n" \
            "${{ secrets.SUPABASE_URL }}/rest/v1/poll_sessions?select=code&limit=1" \
            -H "apikey: ${{ secrets.SUPABASE_KEY }}" \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_KEY }}"
```

`SUPABASE_URL` と `SUPABASE_KEY` を Repository Secrets に登録。

---

## 使い方(授業当日)

### 講師側
1. 教卓PCで `index.html` を開く → 「ホスト画面を開く」
2. 4桁コードとQRコードが表示される
3. モード(多肢選択/ワードクラウド/ランキング)を選ぶ
4. 問題文と選択肢を入力 → 「この問題で出題」
5. 学生の回答が **1.5秒ごと** に棒グラフ/雲で更新
6. 次の問題に進むときは内容を書き換えて「この問題で出題」(回答は自動リセット)

### 学生側
1. QRをスマホで読むか、4桁コード入力
2. 表示された問題に回答 → 「送信」
3. ✓ 表示が出れば完了。間違えたら「やり直す」で再投票可能

---

## 衛生薬学での活用例

| シーン | モード | 問題例 |
|---|---|---|
| 導入(関心引き出し) | ワードクラウド | 「"環境汚染"と聞いて思い浮かぶ言葉は?」 |
| 国試演習 | 多肢選択 | 過去問の選択肢をそのまま出題、即フィードバック |
| Peer Instruction風 | 多肢選択 | 投票→解説→「リセット」して再投票で正答率の変化 |
| 価値観調査 | ランキング | 「公衆衛生政策で優先すべきは?」 |
| 体験データ収集 | ワードクラウド | 「昨日の朝食は?」→ 疫学解析の題材に |

---

## トラブルシューティング

- **「セッションが見つかりません」**: 講師が終了した or コードが間違い or テーブル未作成
- **回答が反映されない**: SQL Editorで`schema.sql`を実行し直す。RLSポリシーが正しいか確認
- **Supabase停止**: 7日以上アイドル放置でプロジェクト停止。keep-aliveワークフローを設定
- **無料枠**: 50万API call/月 = 30人 × 1.5s × 60分授業 × 約40回相当。通常運用なら余裕

## クリーンアップ

不要になった古いセッションは `schema.sql` 末尾の `cleanup_old_poll_sessions()` 関数で削除可能:

```sql
select cleanup_old_poll_sessions();
```

Supabase Dashboard → Database → Functions から手動実行、または pg_cron で自動化。
