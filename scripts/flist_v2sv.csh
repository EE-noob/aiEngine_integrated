#!/bin/tcsh
# ==========================================================
# 批量把 .v 文件改为 .sv，并更新 flist / .f 文件里的引用
# 适用于 tcsh / csh 环境
# ==========================================================

echo ">>> Step 1: rename .v -> .sv ..."
foreach f (`find . -type f -name "*.v" ! -name "*.sv"`)
    set newname = `echo $f | sed 's/\.v$/.sv/'`
    echo "Renaming: $f -> $newname"
    mv "$f" "$newname"
end

echo ">>> Step 2: update .f / flist files ..."
# 遍历当前目录及子目录所有以 .f 结尾的文件
foreach ff (`find . -type f -name "*.f" -o -name "*flist*"`)
    echo "Updating: $ff"
    # 先创建备份
    cp "$ff" "$ff.bak"
    # 执行文本替换（仅替换 .v 结尾的情况）
    sed -i 's/\.v\>/\.sv/g' "$ff"
end

echo "✅ Done! All .v renamed to .sv, and .f/.flist files updated."
