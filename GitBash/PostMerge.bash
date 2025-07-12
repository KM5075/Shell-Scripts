#!/bin/bash

# 設定
DEV_BRANCH="temp/test"  # マージ対象のブランチ名（ワイルドカードも可）
OUTPUT_ROOT_DIR="./merged-files"

# 現在のブランチが dev-machine であるか確認
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" != "$DEV_BRANCH" ]; then
    echo "現在のブランチは $CURRENT_BRANCH。$DEV_BRANCH にマージしたときのみ動作します。"
    exit 0
fi

# 前回のマージでマージされたブランチを取得
MERGE_COMMIT=$(git log -1 --pretty=%H)
PARENTS=($(git log -1 --pretty=%P))

# 2つの親がある場合（マージコミット）
if [ ${#PARENTS[@]} -ne 2 ]; then
    echo "マージコミットではないためスキップ"
    exit 0
fi

# 2つ目の親がマージされたブランチの tip
FEATURE_COMMIT=${PARENTS[1]}
BASE_COMMIT=$(git merge-base "${PARENTS[0]}" "$FEATURE_COMMIT")

echo "マージ対象コミット: $FEATURE_COMMIT"
echo "マージ開始点: $BASE_COMMIT"

# 差分取得（追加・変更ファイルのみ）
git diff --name-status "$BASE_COMMIT"..."$FEATURE_COMMIT" > /tmp/changed_files.txt
grep -E '^[AM]' /tmp/changed_files.txt | cut -f2 > /tmp/changed_file_paths.txt

# マージ元ブランチ名を取得（厳密ではないが、参考情報としてコミットメッセージから抽出）
MERGED_BRANCH_NAME=$(git log -1 --pretty=%B | grep -oE "from [^ ]+" | awk '{print $2}' | sed 's|refs/heads/||' | sed 's|/|_|g')
if [ -z "$MERGED_BRANCH_NAME" ]; then
    MERGED_BRANCH_NAME="unknown-branch"
fi

# タイムスタンプを生成
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 出力ディレクトリを作成
OUTPUT_DIR="$OUTPUT_ROOT_DIR/${TIMESTAMP}_${MERGED_BRANCH_NAME}"
mkdir -p "$OUTPUT_DIR"

# ファイルをコピー
while read file; do
    mkdir -p "$OUTPUT_DIR/$(dirname "$file")"
    cp "$file" "$OUTPUT_DIR/$file"
done < /tmp/changed_file_paths.txt

echo "変更ファイルを $OUTPUT_DIR にコピーしました。"