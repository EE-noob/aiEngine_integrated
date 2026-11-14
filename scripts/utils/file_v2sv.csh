#!/bin/tcsh
# ==========================================================
# 递归把当前目录及子目录下所有 .v 文件改名为 .sv
# ==========================================================

foreach f (`find . -type f -name "*.v"`)
    # 跳过本来就是 .sv 结尾的文件（保险）
    if ("$f:e" == "sv") continue

    set newname = `echo "$f" | sed 's/\.v$/.sv/'`
    echo "Renaming: $f -> $newname"

    # 创建目标目录（防止在子目录中执行时路径不存在）
    set dirpath = `dirname "$newname"`
    if (! -d "$dirpath") mkdir -p "$dirpath"

    mv "$f" "$newname"
end

echo "✅ Done! All .v files have been renamed to .sv."
