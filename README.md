list-edit-mode for xyzzy
=========================
Markdown風のリストを編集するためのマイナーモード。


何ができるの
------------
[Scrapbox] という Wiki のようなサービスがあって、それの [アウトライン編集] が便利だったので xyzzy に移植しました。
以下のようなコマンドが使えるようになります。

- `Enter` -- 次の行もリストにしたりする
- `BS`    -- リストの階層を上げる
- `Tab`   -- リストの階層を下げる
- `C-a`   -- リストの先頭へ移動する

カーソル位置によって上記の動作をしたり、元々そのキーに設定されていた動作をしたりするので、リスト以外のところでは今まで通り使えます。

 [Scrapbox]: https://scrapbox.io/
 [アウトライン編集]: https://scrapbox.io/help-jp/アウトライン編集


使い方など
----------

### 必要なもの
* xyzzy version 0.2.2.239 以降（`nth-value`）

### インストール
NetInstaller用のはあとで書く。というか配布するやり方を忘れたので調べる。

手動でインストールする人は

1. [list-edit.l] を `site-lisp` に放り込んで
2. お好みで `byte-compile` しておく

## 設定
`.xyzzy` などで

    ;; まずは読み込みましょう
    (require "list-edit")
    (use-package :list-edit)
    
    ;; lisp-mode で使う例
    (add-hook '*lisp-mode-hook*
      (lambda ()
        (list-edit-mode-on)
        (setf -list-edit-context- '(:comment :string))))
    
    ;; markdown-mode で使う例
    (add-hook '*markdown-mode-hook*
      (lambda ()
        (list-edit-mode-on)
        (setf -list-edit-context- nil))))

でたぶん使えます。

### 設定用変数

- `-list-edit-context`
  - リスト編集を有効にするコンテキストを指定します。
  - `nil` だとどこでも有効になります
  - `:comment`, `:string`, `:tag` をリストで指定すると、コメント等の中でのみ有効になります。
    - プログラムを書きながらコメントにメモを書く場合などに便利です。

- `-list-edit-indent-level-`
  - リストの階層ごとにいくつインデントするか指定します。
  - デフォルトは `2` です。


その他
------

### バグ報告、要望、質問など
* [Github Issues](https://github.com/bowbow99/xyzzy.lisp-mode-extra/issues)
* [bowbow99 のツイッター](https://twitter.com/bowbow99)
* [bowbow99 のはてダ](http://d.hatena.ne.jp/bowbow99)
* 2ch の xyzzy part.# にカキコ
* 自分のブログに書いておく
* 紙に書いて瓶に詰めて海へ流す

### 作った人（たち）

* [bowbow99](https://github.com/bowbow99)
